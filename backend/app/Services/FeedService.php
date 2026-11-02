<?php

namespace App\Services;

use App\Enums\ApprovalStatus;
use App\Models\Customer;
use App\Models\FeedComment;
use App\Models\FeedLike;
use App\Models\Media;
use App\Models\Promotion;
use App\Models\Vendor;
use App\Models\Zone;
use App\Support\GeoDistance;
use App\Support\Languages;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;

/**
 * The customer app's Feed tab (decided 2026-10-31), for one zone:
 *
 *  1. PAID PROMOTIONS FIRST — live, not hidden, not expired, targeting this
 *     zone, from a vendor still active. Newest first.
 *  2. THEN ORGANIC POSTS — the approved portfolio photos and videos of every
 *     vendor a customer here may be shown (VendorSearchService's own rule:
 *     active, unsuspended, live subscription covering this zone). Newest
 *     first.
 *
 * Both lists page as one: page 1 starts with the promotions and runs on into
 * the posts. The Feed's chips narrow it: Offers (promotions only), Following
 * (the customer's favourite vendors), Nearby (closest vendors first, when a
 * point is known). Every item carries its like and comment counts and
 * whether this customer liked it.
 *
 * Comments are threaded one level (replies under a top-level comment); the
 * vendor who owns the post may reply as the business; comments can be liked.
 */
class FeedService
{
    public const TYPE_PROMOTION = 'promotion';

    public const TYPE_POST = 'post';

    public const FILTER_FOR_YOU = 'for_you';

    public const FILTER_OFFERS = 'offers';

    public const FILTER_NEARBY = 'nearby';

    public const FILTER_FOLLOWING = 'following';

    public const FILTERS = [self::FILTER_FOR_YOU, self::FILTER_OFFERS, self::FILTER_NEARBY, self::FILTER_FOLLOWING];

    public function __construct(private readonly VendorSearchService $vendors) {}

    /**
     * @return array{items: array<int, array<string, mixed>>, meta: array<string, int>}
     */
    public function page(
        Zone $zone,
        Customer $customer,
        int $page,
        int $perPage,
        string $filter = self::FILTER_FOR_YOU,
        ?float $lat = null,
        ?float $lng = null,
    ): array {
        $vendorIds = $this->vendors->eligibleVendorIds($zone);

        $promotions = $this->promotionsQuery($zone);
        $posts = $this->postsQuery($vendorIds);

        if ($filter === self::FILTER_OFFERS) {
            $posts->whereRaw('1 = 0');
        }

        if ($filter === self::FILTER_FOLLOWING) {
            $favourites = $customer->favorites()->pluck('vendor_id')->all() ?: [0];
            $promotions->whereIn('promotions.vendor_id', $favourites);
            $posts->whereIn('media.mediable_id', $favourites);
        }

        if ($filter === self::FILTER_NEARBY && $lat !== null && $lng !== null) {
            $this->orderByDistance($promotions, 'promotions.vendor_id', $lat, $lng);
            $this->orderByDistance($posts, 'media.mediable_id', $lat, $lng);
        }

        $promotionTotal = (clone $promotions)->count();
        $postTotal = (clone $posts)->count();
        $total = $promotionTotal + $postTotal;
        $offset = ($page - 1) * $perPage;

        $items = [];

        if ($offset < $promotionTotal) {
            $found = $promotions->with('vendor.user')
                ->withCount(['likes', 'comments' => fn ($query) => $query->visible()])
                ->skip($offset)->take($perPage)->get();

            // Counted as seen: a page of the Feed actually shown to someone.
            if ($found->isNotEmpty()) {
                Promotion::whereIn('id', $found->pluck('id'))->increment('views_count');
            }

            $items = $found->all();
        }

        $remaining = $perPage - count($items);

        if ($remaining > 0) {
            $items = array_merge($items, $posts->with(['mediable.user', 'subcategory'])
                ->withCount(['likes', 'comments' => fn ($query) => $query->visible()])
                ->skip(max(0, $offset - $promotionTotal))->take($remaining)->get()->all());
        }

        $liked = $this->likedKeys($items, $customer);
        $services = $this->firstServiceNames(array_map(
            fn (Model $item) => $item instanceof Promotion ? $item->vendor_id : $item->mediable_id,
            $items,
        ));

        return [
            'items' => array_map(fn (Model $item) => $this->present($item, $liked, $services), $items),
            'meta' => [
                'current_page' => $page,
                'per_page' => $perPage,
                'total' => $total,
                'last_page' => max(1, (int) ceil($total / $perPage)),
                'promotions' => $promotionTotal,
            ],
        ];
    }

    /** A post a customer may see and act on, or null. */
    public function find(string $type, int $id): ?Model
    {
        return match ($type) {
            self::TYPE_PROMOTION => Promotion::showing()->whereKey($id)
                ->whereHas('vendor', fn ($query) => $this->visibleVendor($query))
                ->first(),
            self::TYPE_POST => Media::where('mediable_type', (new Vendor)->getMorphClass())
                ->where('moderation_status', 'approved')
                ->whereKey($id)
                ->first(),
            default => null,
        };
    }

    /** The vendor a post belongs to — the one who may reply as the business. */
    public function ownerOf(Model $post): ?Vendor
    {
        return $post instanceof Promotion ? $post->vendor : $post->mediable;
    }

    /** Likes or unlikes a post or a comment; answers the new state and count. */
    public function toggleLike(Model $likeable, Customer $customer): array
    {
        $existing = $likeable->likes()->where('customer_id', $customer->id)->first();

        if ($existing !== null) {
            $existing->delete();
        } else {
            // The unique index settles a double tap.
            rescue(fn () => $likeable->likes()->create(['customer_id' => $customer->id]), report: false);
        }

        return [
            'liked' => $existing === null,
            'likes_count' => $likeable->likes()->count(),
        ];
    }

    /**
     * Top-level comments, newest first, each with its replies oldest first —
     * how a conversation reads.
     *
     * @return array{items: array<int, array<string, mixed>>, meta: array<string, int>}
     */
    public function commentsPage(Model $post, ?Customer $viewer, ?Vendor $viewerVendor, int $page, int $perPage): array
    {
        $paginator = $post->comments()->visible()
            ->whereNull('parent_id')
            ->with([
                'customer.user', 'vendor',
                'replies' => fn ($query) => $query->visible()->with(['customer.user', 'vendor'])->withCount('likes')->oldest(),
            ])
            ->withCount('likes')
            ->latest()
            ->orderByDesc('id')
            ->paginate($perPage, ['*'], 'page', $page);

        $all = $paginator->getCollection()
            ->flatMap(fn (FeedComment $comment) => [$comment, ...$comment->replies]);
        $liked = $viewer === null ? [] : $this->likedCommentIds($all, $viewer);

        return [
            'items' => $paginator->getCollection()
                ->map(fn (FeedComment $comment) => $this->presentComment($comment, $viewer, $viewerVendor, $liked) + [
                    'replies' => $comment->replies
                        ->map(fn (FeedComment $reply) => $this->presentComment($reply, $viewer, $viewerVendor, $liked))
                        ->values()
                        ->all(),
                ])
                ->values()
                ->all(),
            'meta' => [
                'current_page' => $paginator->currentPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
                'last_page' => $paginator->lastPage(),
            ],
        ];
    }

    /**
     * @param  array<int, true>  $liked  comment ids this viewer liked
     * @return array<string, mixed>
     */
    public function presentComment(FeedComment $comment, ?Customer $viewer, ?Vendor $viewerVendor = null, array $liked = []): array
    {
        return [
            'id' => $comment->id,
            'parent_id' => $comment->parent_id,
            'body' => $comment->body,
            'author_name' => $comment->authorName(),
            'author_avatar_url' => $comment->authorAvatarUrl(),
            'is_business' => $comment->isBusinessReply(),
            'is_mine' => ($viewer !== null && $comment->customer_id === $viewer->id)
                || ($viewerVendor !== null && $comment->vendor_id === $viewerVendor->id),
            'likes_count' => (int) ($comment->likes_count ?? 0),
            'liked' => isset($liked[$comment->id]),
            'created_at' => $comment->created_at?->toIso8601String(),
        ];
    }

    private function promotionsQuery(Zone $zone): Builder
    {
        return Promotion::showing()
            ->whereHas('zones', fn ($query) => $query->whereKey($zone->id))
            ->whereHas('vendor', fn ($query) => $this->visibleVendor($query))
            ->latest('promotions.starts_at')
            ->orderByDesc('promotions.id');
    }

    /** @param  array<int, int>  $vendorIds */
    private function postsQuery(array $vendorIds): Builder
    {
        return Media::where('media.mediable_type', (new Vendor)->getMorphClass())
            ->whereIn('media.mediable_id', $vendorIds === [] ? [0] : $vendorIds)
            ->where('media.moderation_status', 'approved')
            ->latest('media.created_at')
            ->orderByDesc('media.id');
    }

    /** Nearest vendor first; vendors without a saved location last. */
    private function orderByDistance(Builder $query, string $vendorColumn, float $lat, float $lng): void
    {
        $table = $query->getModel()->getTable();
        [$expression, $bindings] = GeoDistance::sqlExpression('feed_vendor.latitude', 'feed_vendor.longitude', $lat, $lng);

        $query->join('vendors as feed_vendor', 'feed_vendor.id', '=', $vendorColumn)
            ->select("{$table}.*")
            ->reorder()
            ->orderByRaw('(feed_vendor.latitude IS NULL OR feed_vendor.longitude IS NULL)')
            ->orderByRaw($expression, $bindings)
            ->orderByDesc("{$table}.id");
    }

    private function visibleVendor(Builder $query): Builder
    {
        return $query->whereIn('status', ['active', 'grace'])
            ->where('is_suspended', false)
            ->whereHas('user');
    }

    /**
     * "type:id" keys this customer has liked among the given items — one
     * query for the page rather than one per post.
     *
     * @param  array<int, Model>  $items
     * @return array<string, true>
     */
    private function likedKeys(array $items, Customer $customer): array
    {
        if ($items === []) {
            return [];
        }

        $byType = [];

        foreach ($items as $item) {
            $byType[$item->getMorphClass()][] = $item->getKey();
        }

        $query = FeedLike::where('customer_id', $customer->id)->where(function ($query) use ($byType) {
            foreach ($byType as $type => $ids) {
                $query->orWhere(fn ($q) => $q->where('likeable_type', $type)->whereIn('likeable_id', $ids));
            }
        });

        return $query->get(['likeable_type', 'likeable_id'])
            ->mapWithKeys(fn (FeedLike $like) => [$like->likeable_type.':'.$like->likeable_id => true])
            ->all();
    }

    /**
     * @param  Collection<int, FeedComment>|\Illuminate\Support\Collection<int, FeedComment>  $comments
     * @return array<int, true>
     */
    private function likedCommentIds($comments, Customer $viewer): array
    {
        if ($comments->isEmpty()) {
            return [];
        }

        return FeedLike::where('customer_id', $viewer->id)
            ->where('likeable_type', (new FeedComment)->getMorphClass())
            ->whereIn('likeable_id', $comments->pluck('id'))
            ->pluck('likeable_id')
            ->mapWithKeys(fn ($id) => [(int) $id => true])
            ->all();
    }

    /**
     * Each vendor's first service on their live subscription ("Cab
     * services") — the line under the name on a post. One query a page.
     *
     * @param  array<int, int|null>  $vendorIds
     * @return array<int, string>
     */
    private function firstServiceNames(array $vendorIds): array
    {
        $vendorIds = array_values(array_unique(array_filter($vendorIds)));

        if ($vendorIds === []) {
            return [];
        }

        return DB::table('subscription_items')
            ->join('subscriptions', 'subscriptions.id', '=', 'subscription_items.subscription_id')
            ->join('subcategories', 'subcategories.id', '=', 'subscription_items.item_id')
            ->where('subscription_items.item_type', 'subcategory')
            ->whereIn('subscriptions.vendor_id', $vendorIds)
            ->whereIn('subscriptions.status', ['active', 'grace'])
            ->whereNull('subscriptions.deleted_at')
            ->orderBy('subscription_items.id')
            ->get(['subscriptions.vendor_id', 'subcategories.name'])
            ->groupBy('vendor_id')
            ->map(fn ($rows) => Languages::pick($rows->first()->name))
            ->all();
    }

    /**
     * @param  array<string, true>  $liked
     * @param  array<int, string>  $services
     * @return array<string, mixed>
     */
    private function present(Model $item, array $liked, array $services): array
    {
        $isPromotion = $item instanceof Promotion;
        /** @var Vendor|null $vendor */
        $vendor = $isPromotion ? $item->vendor : $item->mediable;

        $serviceName = ! $isPromotion && $item->subcategory
            ? Languages::pick($item->subcategory->getRawOriginal('name'))
            : ($services[$vendor?->id] ?? null);

        return [
            'type' => $isPromotion ? self::TYPE_PROMOTION : self::TYPE_POST,
            'id' => $item->getKey(),
            'sponsored' => $isPromotion,
            'vendor' => [
                'id' => $vendor?->id,
                'business_name' => $vendor?->business_name,
                'shop_photo_url' => $vendor?->fileUrl($vendor->shop_photo_path),
                'phone' => $vendor?->phone,
                // Approved by an admin, which needs every required KYC
                // document verified — the tick next to the name.
                'verified' => $vendor?->user?->approval_status === ApprovalStatus::Approved,
            ],
            'caption' => $isPromotion ? $item->caption : null,
            // "Cab services" — the post's own service, or the vendor's first.
            'service_name' => $serviceName,
            'media_type' => $isPromotion ? $item->media_type : $item->type,
            'media_url' => $item->fileUrl(),
            'likes_count' => (int) $item->likes_count,
            'comments_count' => (int) $item->comments_count,
            'liked' => isset($liked[$item->getMorphClass().':'.$item->getKey()]),
            'created_at' => ($isPromotion ? $item->starts_at : $item->created_at)?->toIso8601String(),
        ];
    }
}

<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Feed\FeedRequest;
use App\Http\Responses\ApiResponse;
use App\Models\Customer;
use App\Models\FeedComment;
use App\Models\Media;
use App\Models\Promotion;
use App\Models\Vendor;
use App\Services\FeedService;
use App\Services\ZoneMatcher;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * The Feed (decided 2026-10-31) — paid promotions for the customer's zone
 * first, then the portfolio posts of vendors serving it — plus likes,
 * threaded comments, comment likes and reports (customers), and the vendor's
 * own view of comments on their posts with replies as the business.
 *
 * A post is addressed as {type}/{id}: `promotion` (a Promotion) or `post`
 * (a vendor's portfolio Media).
 */
class FeedController extends Controller
{
    public function __construct(
        private readonly FeedService $feed,
        private readonly ZoneMatcher $zones,
    ) {}

    public function index(FeedRequest $request): JsonResponse
    {
        $zone = $this->zones->resolve($request->zoneId(), $request->latitude(), $request->longitude(), $request->pincode());

        // No zone, no vendors to show — not an error.
        if ($zone === null) {
            return response()->json([
                'success' => true,
                'data' => ['zone' => null, 'items' => []],
                'meta' => ['current_page' => 1, 'per_page' => 0, 'total' => 0, 'last_page' => 1, 'promotions' => 0],
                'error' => null,
            ]);
        }

        $result = $this->feed->page(
            $zone,
            $this->customer($request),
            (int) $request->input('page', 1),
            (int) $request->input('per_page', 10),
            (string) $request->input('filter', FeedService::FILTER_FOR_YOU),
            $request->latitude(),
            $request->longitude(),
        );

        return response()->json([
            'success' => true,
            'data' => ['zone' => ['id' => $zone->id, 'name' => $zone->name], 'items' => $result['items']],
            'meta' => $result['meta'],
            'error' => null,
        ]);
    }

    public function like(Request $request, string $type, int $id): JsonResponse
    {
        $post = $this->feed->find($type, $id);

        if ($post === null) {
            return $this->notFound();
        }

        return ApiResponse::success($this->feed->toggleLike($post, $this->customer($request)));
    }

    /** Top-level comments with their replies. */
    public function comments(Request $request, string $type, int $id): JsonResponse
    {
        $post = $this->feed->find($type, $id);

        if ($post === null) {
            return $this->notFound();
        }

        return $this->commentsResponse($request, $post, $this->customer($request), null);
    }

    /** A new comment, or a reply (parent_id) to a top-level one. */
    public function storeComment(Request $request, string $type, int $id): JsonResponse
    {
        $data = $request->validate([
            'body' => ['required', 'string', 'max:500'],
            'parent_id' => ['nullable', 'integer'],
        ]);

        $post = $this->feed->find($type, $id);

        if ($post === null) {
            return $this->notFound();
        }

        $customer = $this->customer($request);
        $parentId = $this->threadParent($post, $data['parent_id'] ?? null);

        if ($parentId === false) {
            return ApiResponse::error('NOT_FOUND', 'That comment is no longer available.', 404);
        }

        $comment = $post->comments()->create([
            'customer_id' => $customer->id,
            'parent_id' => $parentId,
            'body' => trim($data['body']),
        ]);

        return ApiResponse::success($this->feed->presentComment($comment->load('customer.user'), $customer), 201);
    }

    public function likeComment(Request $request, FeedComment $comment): JsonResponse
    {
        if ($comment->is_hidden) {
            return ApiResponse::error('NOT_FOUND', 'That comment is no longer available.', 404);
        }

        return ApiResponse::success($this->feed->toggleLike($comment, $this->customer($request)));
    }

    /** A customer removes their own comment (its replies go with it). */
    public function destroyComment(Request $request, FeedComment $comment): JsonResponse
    {
        if ($comment->customer_id !== $this->customer($request)->id) {
            return ApiResponse::error('FORBIDDEN', 'You can only delete your own comment.', 403);
        }

        $comment->delete();

        return ApiResponse::success(['deleted' => true]);
    }

    /** Flags a comment for the admin. Once per customer; repeating is a no-op. */
    public function reportComment(Request $request, FeedComment $comment): JsonResponse
    {
        $data = $request->validate(['reason' => ['nullable', 'string', 'max:500']]);
        $customer = $this->customer($request);

        $report = $comment->reports()->firstOrCreate(
            ['customer_id' => $customer->id],
            ['reason' => $data['reason'] ?? null],
        );

        if ($report->wasRecentlyCreated) {
            $comment->increment('reports_count');
        }

        return ApiResponse::success(['reported' => true], 201);
    }

    // ── Vendor: comments on their own posts ────────────────────────────────

    /**
     * GET /vendors/me/feed-comments — customers' comments on this vendor's
     * promotions and portfolio posts, newest first, each with its post and
     * any replies, so the vendor can answer as the business.
     */
    public function vendorComments(Request $request): JsonResponse
    {
        $vendor = $request->user()->vendor;

        $paginator = FeedComment::visible()
            ->whereNull('parent_id')
            ->where(fn ($query) => $query
                ->where(fn ($q) => $q->where('commentable_type', (new Promotion)->getMorphClass())
                    ->whereIn('commentable_id', $vendor->promotions()->select('id')))
                ->orWhere(fn ($q) => $q->where('commentable_type', (new Media)->getMorphClass())
                    ->whereIn('commentable_id', $vendor->media()->select('id'))))
            ->with([
                'customer.user', 'vendor', 'commentable',
                'replies' => fn ($query) => $query->visible()->with(['customer.user', 'vendor'])->withCount('likes')->oldest(),
            ])
            ->withCount('likes')
            ->latest()
            ->paginate(min(50, max(1, (int) $request->input('per_page', 20))));

        return response()->json([
            'success' => true,
            'data' => $paginator->getCollection()->map(fn (FeedComment $comment) => $this->feed->presentComment($comment, null, $vendor) + [
                'post' => $this->postSummary($comment->commentable),
                'replies' => $comment->replies
                    ->map(fn (FeedComment $reply) => $this->feed->presentComment($reply, null, $vendor))
                    ->values(),
            ])->values(),
            'meta' => [
                'current_page' => $paginator->currentPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
                'last_page' => $paginator->lastPage(),
            ],
            'error' => null,
        ]);
    }

    /** POST /vendors/me/feed-comments/{comment}/reply — answer as the business. */
    public function vendorReply(Request $request, FeedComment $comment): JsonResponse
    {
        $data = $request->validate(['body' => ['required', 'string', 'max:500']]);
        $vendor = $request->user()->vendor;
        $post = $comment->commentable;

        if ($post === null || $comment->is_hidden || $this->feed->ownerOf($post)?->id !== $vendor?->id) {
            return ApiResponse::error('NOT_FOUND', 'That comment is not on one of your posts.', 404);
        }

        $reply = $post->comments()->create([
            'vendor_id' => $vendor->id,
            // Replies stay one level deep: answering a reply joins its thread.
            'parent_id' => $comment->parent_id ?? $comment->id,
            'body' => trim($data['body']),
        ]);

        return ApiResponse::success($this->feed->presentComment($reply->load('vendor'), null, $vendor), 201);
    }

    private function commentsResponse(Request $request, Model $post, ?Customer $customer, ?Vendor $vendor): JsonResponse
    {
        $result = $this->feed->commentsPage(
            $post,
            $customer,
            $vendor,
            max(1, (int) $request->input('page', 1)),
            min(50, max(1, (int) $request->input('per_page', 20))),
        );

        return response()->json([
            'success' => true,
            'data' => $result['items'],
            'meta' => $result['meta'],
            'error' => null,
        ]);
    }

    /**
     * The thread a new comment joins: null for a top-level comment, the
     * top-level id for a reply (replying to a reply joins its thread), or
     * false when the parent is not a visible comment on this post.
     */
    private function threadParent(Model $post, ?int $parentId): int|false|null
    {
        if ($parentId === null) {
            return null;
        }

        $parent = $post->comments()->visible()->whereKey($parentId)->first();

        return $parent === null ? false : ($parent->parent_id ?? $parent->id);
    }

    /** @return array<string, mixed>|null */
    private function postSummary(?Model $post): ?array
    {
        if ($post === null) {
            return null;
        }

        $isPromotion = $post instanceof Promotion;

        return [
            'type' => $isPromotion ? FeedService::TYPE_PROMOTION : FeedService::TYPE_POST,
            'id' => $post->getKey(),
            'caption' => $isPromotion ? $post->caption : null,
            'media_type' => $isPromotion ? $post->media_type : $post->type,
            'media_url' => $post->fileUrl(),
        ];
    }

    /** The caller's customer row, created on first use like elsewhere. */
    private function customer(Request $request): Customer
    {
        $user = $request->user();

        return $user->customer ?? Customer::create(['user_id' => $user->id]);
    }

    private function notFound(): JsonResponse
    {
        return ApiResponse::error('NOT_FOUND', 'This post is no longer available.', 404);
    }
}

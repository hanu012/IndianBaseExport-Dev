<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Vendor\StorePromotionRequest;
use App\Http\Requests\Vendor\UpdatePromotionPostRequest;
use App\Http\Responses\ApiResponse;
use App\Models\FeedComment;
use App\Models\Payment;
use App\Models\Promotion;
use App\Models\PromotionExtension;
use App\Models\PromotionPackage;
use App\Models\Zone;
use App\Services\FeedService;
use App\Services\Payments\PaymentGatewayException;
use App\Services\PromotionService;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

/**
 * The vendor's paid promotions (decided 2026-10-31): what can be bought,
 * buying one, the Live / Ended lists with their numbers, one promotion's
 * details, and what can be done to it — edit the post, pause / resume, end
 * early, extend, or withdraw an unpaid one.
 */
class VendorPromotionController extends Controller
{
    public const TAB_LIVE = 'live';

    public const TAB_ENDED = 'ended';

    public function __construct(
        private readonly PromotionService $promotions,
        private readonly FeedService $feed,
    ) {}

    /** GET /vendors/me/promotions/options — active packages and the vendor's own zones. */
    public function options(Request $request): JsonResponse
    {
        $vendor = $request->user()->vendor;

        return ApiResponse::success([
            'packages' => PromotionPackage::active()->orderBy('sort_order')->orderBy('price_paise')->get()
                ->map(fn (PromotionPackage $package) => [
                    'id' => $package->id,
                    'name' => $package->name,
                    'description' => $package->description,
                    'duration_days' => $package->duration_days,
                    'price_paise' => $package->price_paise,
                    'allows_video' => $package->allows_video,
                    'is_popular' => $package->is_popular,
                ])->values(),
            'zones' => $this->promotions->zonesFor($vendor)
                ->map(fn (Zone $zone) => ['id' => $zone->id, 'name' => $zone->name])->values(),
        ]);
    }

    /**
     * GET /vendors/me/promotions?tab=live|ended — newest first, with
     * views/likes/comments/calls. "live" also holds paused, hidden and
     * waiting-for-payment ones; "ended" holds ended and cancelled. Without
     * `tab`, all of them. `meta.counts` carries both tab counts.
     */
    public function index(Request $request): JsonResponse
    {
        $vendor = $request->user()->vendor;
        $tab = $request->string('tab')->toString();

        $paginator = $this->tabQuery($vendor->promotions(), $tab)
            ->with(['package', 'zones', 'payment'])
            ->withCount(['likes', 'comments' => fn ($query) => $query->visible(), 'leads'])
            ->latest()
            ->paginate(min(50, max(1, (int) $request->input('per_page', 15))));

        $response = ApiResponse::paginated($paginator->through(fn (Promotion $promotion) => $this->present($promotion)));
        $payload = $response->getData(true);
        $payload['meta']['counts'] = [
            self::TAB_LIVE => $this->tabQuery($vendor->promotions(), self::TAB_LIVE)->count(),
            self::TAB_ENDED => $this->tabQuery($vendor->promotions(), self::TAB_ENDED)->count(),
        ];

        return $response->setData($payload);
    }

    /**
     * GET /vendors/me/promotions/{promotion} — the details screen: the
     * promotion, what was paid in all, and the newest comments (each with
     * `needs_reply` while the business has not answered it).
     */
    public function show(Request $request, Promotion $promotion): JsonResponse
    {
        if (($denied = $this->denyUnlessOwn($request, $promotion)) !== null) {
            return $denied;
        }

        $vendor = $request->user()->vendor;

        $comments = $promotion->comments()->visible()
            ->whereNull('parent_id')
            ->with([
                'customer.user', 'vendor',
                'replies' => fn ($query) => $query->visible()->with(['customer.user', 'vendor'])->withCount('likes')->oldest(),
            ])
            ->withCount('likes')
            ->latest()
            ->limit(3)
            ->get();

        $unanswered = $promotion->comments()->visible()
            ->whereNull('parent_id')
            ->whereNull('vendor_id')
            ->whereDoesntHave('replies', fn ($query) => $query->whereNotNull('vendor_id'))
            ->count();

        return ApiResponse::success($this->present($this->withStats($promotion)) + [
            'amount_paid_paise' => (int) Payment::where('promotion_id', $promotion->id)->where('status', 'captured')->sum('amount_paise'),
            'pending_extension' => $this->pendingExtension($promotion),
            'unanswered_comments' => $unanswered,
            'recent_comments' => $comments->map(fn (FeedComment $comment) => $this->feed->presentComment($comment, null, $vendor, []) + [
                'needs_reply' => $comment->vendor_id === null
                    && ! $comment->replies->contains(fn (FeedComment $reply) => $reply->vendor_id !== null),
                'replies' => $comment->replies
                    ->map(fn (FeedComment $reply) => $this->feed->presentComment($reply, null, $vendor, []))
                    ->values(),
            ])->values(),
        ]);
    }

    /**
     * POST /vendors/me/promotions — needs an Idempotency-Key (a UUID): the
     * same key again answers the promotion already bought, never a second
     * charge.
     */
    public function store(StorePromotionRequest $request): JsonResponse
    {
        $vendor = $request->user()->vendor;
        $key = (string) $request->header('Idempotency-Key');

        if (! Str::isUuid($key)) {
            return ApiResponse::error('IDEMPOTENCY_KEY_REQUIRED', 'An Idempotency-Key header (UUID) is required.', 422);
        }

        $existing = Promotion::where('idempotency_key', $key)->where('vendor_id', $vendor->id)->first();

        if ($existing !== null) {
            return ApiResponse::success($this->present($this->withStats($existing)));
        }

        try {
            $promotion = $this->promotions->purchase(
                $vendor,
                $request->package,
                $request->string('caption')->toString(),
                array_map('intval', $request->input('zone_ids', [])),
                $request->file('file'),
                $request->hasFile('file') ? $request->string('media_type')->toString() : null,
                $key,
            );
        } catch (PaymentGatewayException) {
            return ApiResponse::error('PAYMENT_GATEWAY_UNAVAILABLE', 'Online payment is unavailable right now. Please try again later.', 503);
        } catch (QueryException $e) {
            // Two taps racing on the same key: the other one won.
            if (str_contains($e->getMessage(), 'idempotency_key')) {
                $existing = Promotion::where('idempotency_key', $key)->first();

                if ($existing !== null) {
                    return ApiResponse::success($this->present($this->withStats($existing)));
                }
            }

            throw $e;
        }

        return ApiResponse::success($this->present($this->withStats($promotion)), 201);
    }

    /** POST /vendors/me/promotions/{promotion}/post — "Edit post" (multipart). */
    public function updatePost(UpdatePromotionPostRequest $request, Promotion $promotion): JsonResponse
    {
        if (($denied = $this->denyUnlessOwn($request, $promotion)) !== null) {
            return $denied;
        }

        if (! in_array($promotion->status, [Promotion::STATUS_LIVE, Promotion::STATUS_PENDING_PAYMENT], true)) {
            return ApiResponse::error('NOT_EDITABLE', 'An ended promotion can no longer be edited.', 422);
        }

        $promotion = $this->promotions->updatePost(
            $promotion,
            $request->string('caption')->toString(),
            $request->file('file'),
            $request->hasFile('file') ? $request->string('media_type')->toString() : null,
            $request->boolean('remove_media'),
        );

        return ApiResponse::success($this->present($this->withStats($promotion)));
    }

    /** POST /vendors/me/promotions/{promotion}/pause — the clock stops. */
    public function pause(Request $request, Promotion $promotion): JsonResponse
    {
        if (($denied = $this->denyUnlessOwn($request, $promotion)) !== null) {
            return $denied;
        }

        if ($promotion->status !== Promotion::STATUS_LIVE) {
            return ApiResponse::error('NOT_LIVE', 'Only a live promotion can be paused.', 422);
        }

        $this->promotions->pause($promotion);

        return ApiResponse::success($this->present($this->withStats($promotion->fresh())));
    }

    /** POST /vendors/me/promotions/{promotion}/resume — paused days added back. */
    public function resume(Request $request, Promotion $promotion): JsonResponse
    {
        if (($denied = $this->denyUnlessOwn($request, $promotion)) !== null) {
            return $denied;
        }

        if (! $promotion->isPaused()) {
            return ApiResponse::error('NOT_PAUSED', 'This promotion is not paused.', 422);
        }

        $this->promotions->resume($promotion);

        return ApiResponse::success($this->present($this->withStats($promotion->fresh())));
    }

    /** POST /vendors/me/promotions/{promotion}/end — stop now, no refund. */
    public function end(Request $request, Promotion $promotion): JsonResponse
    {
        if (($denied = $this->denyUnlessOwn($request, $promotion)) !== null) {
            return $denied;
        }

        if ($promotion->status !== Promotion::STATUS_LIVE) {
            return ApiResponse::error('NOT_LIVE', 'Only a live promotion can be ended.', 422);
        }

        $this->promotions->end($promotion);

        return ApiResponse::success($this->present($this->withStats($promotion->fresh())));
    }

    /**
     * POST /vendors/me/promotions/{promotion}/extend — buy the same package
     * again; Idempotency-Key (UUID) like every purchase. The answer is the
     * promotion with `pending_extension` set while a payment link waits.
     */
    public function extend(Request $request, Promotion $promotion): JsonResponse
    {
        if (($denied = $this->denyUnlessOwn($request, $promotion)) !== null) {
            return $denied;
        }

        $key = (string) $request->header('Idempotency-Key');

        if (! Str::isUuid($key)) {
            return ApiResponse::error('IDEMPOTENCY_KEY_REQUIRED', 'An Idempotency-Key header (UUID) is required.', 422);
        }

        if (! PromotionExtension::where('idempotency_key', $key)->where('promotion_id', $promotion->id)->exists()) {
            if (! in_array($promotion->status, [Promotion::STATUS_LIVE, Promotion::STATUS_ENDED], true)) {
                return ApiResponse::error('NOT_EXTENDABLE', 'Only a paid promotion can be extended.', 422);
            }

            if ($this->pendingExtension($promotion) !== null) {
                return ApiResponse::error('EXTENSION_PENDING', 'An extension is already waiting for payment.', 422);
            }

            if (! $promotion->package?->is_active) {
                return ApiResponse::error('PACKAGE_UNAVAILABLE', 'This package is no longer sold. Start a new promotion instead.', 422);
            }

            try {
                $this->promotions->extend($promotion, $key);
            } catch (PaymentGatewayException) {
                return ApiResponse::error('PAYMENT_GATEWAY_UNAVAILABLE', 'Online payment is unavailable right now. Please try again later.', 503);
            } catch (QueryException $e) {
                if (! str_contains($e->getMessage(), 'idempotency_key')) {
                    throw $e;
                }
            }
        }

        $promotion = $promotion->fresh();

        return ApiResponse::success($this->present($this->withStats($promotion)) + [
            'pending_extension' => $this->pendingExtension($promotion),
        ]);
    }

    /** DELETE /vendors/me/promotions/{promotion} — withdraw an unpaid one. */
    public function destroy(Request $request, Promotion $promotion): JsonResponse
    {
        if (($denied = $this->denyUnlessOwn($request, $promotion)) !== null) {
            return $denied;
        }

        if ($promotion->status !== Promotion::STATUS_PENDING_PAYMENT) {
            return ApiResponse::error('NOT_CANCELLABLE', 'Only a promotion waiting for payment can be cancelled.', 422);
        }

        $this->promotions->cancelPending($promotion);

        return ApiResponse::success($this->present($this->withStats($promotion->fresh())));
    }

    private function denyUnlessOwn(Request $request, Promotion $promotion): ?JsonResponse
    {
        return $promotion->vendor_id === $request->user()->vendor?->id
            ? null
            : ApiResponse::error('NOT_FOUND', 'Promotion not found.', 404);
    }

    private function tabQuery($query, string $tab)
    {
        return match ($tab) {
            self::TAB_LIVE => $query->whereIn('status', [Promotion::STATUS_LIVE, Promotion::STATUS_PENDING_PAYMENT]),
            self::TAB_ENDED => $query->whereIn('status', [Promotion::STATUS_ENDED, Promotion::STATUS_CANCELLED]),
            default => $query,
        };
    }

    /** @return array<string, mixed>|null */
    private function pendingExtension(Promotion $promotion): ?array
    {
        $extension = $promotion->extensions()
            ->where('status', PromotionExtension::STATUS_PENDING_PAYMENT)
            ->with('payment')
            ->latest('id')
            ->first();

        return $extension === null ? null : [
            'id' => $extension->id,
            'days' => $extension->days,
            'price_paise' => $extension->price_paise,
            'link_expires_at' => $extension->payment?->payment_link_expires_at?->toIso8601String(),
        ];
    }

    private function withStats(Promotion $promotion): Promotion
    {
        return $promotion->load(['package', 'zones', 'payment'])
            ->loadCount(['likes', 'comments' => fn ($query) => $query->visible(), 'leads']);
    }

    /** @return array<string, mixed> */
    private function present(Promotion $promotion): array
    {
        $payment = $promotion->payment;
        $showing = $promotion->isShowing();

        return [
            'id' => $promotion->id,
            'package_id' => $promotion->promotion_package_id,
            'package_name' => $promotion->package?->name,
            'allows_video' => (bool) $promotion->package?->allows_video,
            'caption' => $promotion->caption,
            'media_type' => $promotion->media_type,
            'media_url' => $promotion->hasMedia() ? $promotion->fileUrl() : null,
            'price_paise' => $promotion->price_paise,
            'duration_days' => $promotion->duration_days,
            // live | pending_payment | ended | cancelled | hidden
            'status' => $promotion->is_hidden && $promotion->status === Promotion::STATUS_LIVE ? 'hidden' : $promotion->status,
            'is_showing' => $showing,
            'is_paused' => $promotion->isPaused(),
            'paused_at' => $promotion->paused_at?->toIso8601String(),
            'hidden_reason' => $promotion->is_hidden ? $promotion->hidden_reason : null,
            'starts_at' => $promotion->starts_at?->toIso8601String(),
            'ends_at' => $promotion->ends_at?->toIso8601String(),
            'zones' => $promotion->zones->map(fn (Zone $zone) => ['id' => $zone->id, 'name' => $zone->name])->values(),
            'stats' => [
                'views' => (int) $promotion->views_count,
                'likes' => (int) ($promotion->likes_count ?? 0),
                'comments' => (int) ($promotion->comments_count ?? 0),
                'calls' => (int) ($promotion->leads_count ?? 0),
            ],
            'payment' => $payment === null ? null : [
                'status' => $payment->status,
                'link_expires_at' => $payment->payment_link_expires_at?->toIso8601String(),
            ],
            'created_at' => $promotion->created_at?->toIso8601String(),
        ];
    }
}

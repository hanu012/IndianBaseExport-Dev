<?php

namespace App\Services;

use App\Models\Payment;
use App\Models\Promotion;
use App\Models\PromotionExtension;
use App\Models\PromotionPackage;
use App\Models\SubscriptionItem;
use App\Models\User;
use App\Models\Vendor;
use App\Models\Zone;
use App\Notifications\PromotionStatusNotification;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;

/**
 * Paid promotions (decided 2026-10-31): a vendor buys a PromotionPackage and
 * posts a caption — with a photo or video, or text only — into any of their
 * own zones; it runs for the package's days from the moment it is paid.
 *
 * Payment is the subscription flow's (PaymentService::payOnline): with
 * Razorpay links off it is captured at once and the promotion is live
 * straight away; on, it waits as pending_payment until the webhook calls
 * completeOnlinePayment(). No admin review before going live (decided) —
 * hide() is the takedown.
 *
 * While live the vendor can edit the post, pause it (the clock stops — the
 * paused time is added back to ends_at on resume), end it early (no refund)
 * or extend it (the same package bought again, its days added on payment).
 */
class PromotionService
{
    public function __construct(
        private readonly PaymentService $payments,
        private readonly PushNotificationService $notifications,
    ) {}

    /**
     * Zones a vendor may target: the active leaf zones of their current
     * subscription — never somewhere they do not serve.
     *
     * @return Collection<int, Zone>
     */
    public function zonesFor(Vendor $vendor): Collection
    {
        $subscription = $vendor->currentActiveSubscription();

        if ($subscription === null) {
            return collect();
        }

        return Zone::whereIn('id', SubscriptionItem::where('subscription_id', $subscription->id)
            ->where('item_type', 'zone')
            ->pluck('item_id'))
            ->where('is_active', true)
            ->orderBy('name')
            ->get();
    }

    /**
     * Records the purchase. Server-side values only: the price and days come
     * from the package, never the request. The file is optional — a
     * text-only promotion shows its caption large in the Feed.
     *
     * @param  array<int, int>  $zoneIds  already validated against zonesFor()
     */
    public function purchase(
        Vendor $vendor,
        PromotionPackage $package,
        string $caption,
        array $zoneIds,
        ?UploadedFile $file,
        ?string $mediaType,
        string $idempotencyKey,
    ): Promotion {
        $disk = Promotion::currentUploadDisk();
        $path = $file?->store('vendor-promotions/'.$vendor->id, $disk);

        try {
            return DB::transaction(function () use ($vendor, $package, $caption, $zoneIds, $mediaType, $path, $disk, $idempotencyKey) {
                $promotion = Promotion::create([
                    'vendor_id' => $vendor->id,
                    'promotion_package_id' => $package->id,
                    'caption' => trim($caption),
                    'media_type' => $path === null ? null : $mediaType,
                    'media_path' => $path,
                    'disk' => $disk,
                    'price_paise' => $package->price_paise,
                    'duration_days' => $package->duration_days,
                    'status' => Promotion::STATUS_PENDING_PAYMENT,
                    'idempotency_key' => $idempotencyKey,
                ]);

                $promotion->zones()->sync($zoneIds);

                $payment = $this->payments->payOnline($promotion, $package->price_paise);

                if (! $payment->isPending()) {
                    $this->goLive($promotion);
                }

                return $promotion->fresh(['package', 'zones', 'payment']);
            });
        } catch (\Throwable $e) {
            // Nothing points at the file any more.
            if ($path !== null) {
                Storage::disk($disk)->delete($path);
            }

            throw $e;
        }
    }

    /**
     * "Edit post": a new caption, and optionally a new photo/video or none.
     * Package, areas and dates are not editable — they are what was paid for.
     */
    public function updatePost(Promotion $promotion, string $caption, ?UploadedFile $file, ?string $mediaType, bool $removeMedia): Promotion
    {
        $oldDisk = $promotion->disk;
        $oldPath = $promotion->media_path;
        $changes = ['caption' => trim($caption)];

        if ($file !== null) {
            $disk = Promotion::currentUploadDisk();
            $changes += [
                'media_path' => $file->store('vendor-promotions/'.$promotion->vendor_id, $disk),
                'media_type' => $mediaType,
                'disk' => $disk,
            ];
        } elseif ($removeMedia) {
            $changes += ['media_path' => null, 'media_type' => null];
        }

        $promotion->update($changes);

        if (($file !== null || $removeMedia) && $oldPath !== null) {
            rescue(fn () => Storage::disk($oldDisk ?? Promotion::currentUploadDisk())->delete($oldPath), report: false);
        }

        return $promotion->fresh();
    }

    /** Off the Feed until resumed; the clock stops. */
    public function pause(Promotion $promotion): void
    {
        if ($promotion->status === Promotion::STATUS_LIVE && $promotion->paused_at === null) {
            $promotion->forceFill(['paused_at' => now()])->save();
        }
    }

    /** Back on the Feed; the paused time is added to the end date. */
    public function resume(Promotion $promotion): void
    {
        if ($promotion->status !== Promotion::STATUS_LIVE || $promotion->paused_at === null) {
            return;
        }

        $pausedSeconds = (int) $promotion->paused_at->diffInSeconds(now(), true);

        $promotion->forceFill([
            'ends_at' => $promotion->ends_at->copy()->addSeconds($pausedSeconds),
            'paused_at' => null,
            // A new end date earns a fresh "ends tomorrow" reminder.
            'ending_reminder_sent_at' => null,
        ])->save();
    }

    /** Stops it now — no refund (decided). */
    public function end(Promotion $promotion): void
    {
        if ($promotion->status !== Promotion::STATUS_LIVE) {
            return;
        }

        $promotion->forceFill([
            'status' => Promotion::STATUS_ENDED,
            'ends_at' => now(),
            'paused_at' => null,
        ])->save();
    }

    /**
     * "Extend promotion": the same package bought again; its days are added
     * to the end date once paid (at once with payment links off).
     */
    public function extend(Promotion $promotion, string $idempotencyKey): PromotionExtension
    {
        $package = $promotion->package;

        return DB::transaction(function () use ($promotion, $package, $idempotencyKey) {
            $extension = $promotion->extensions()->create([
                'days' => $package->duration_days,
                'price_paise' => $package->price_paise,
                'status' => PromotionExtension::STATUS_PENDING_PAYMENT,
                'idempotency_key' => $idempotencyKey,
            ]);

            $payment = $this->payments->payOnline($extension, $extension->price_paise);

            if (! $payment->isPending()) {
                $this->applyExtension($extension);
            }

            return $extension->fresh(['payment']);
        });
    }

    /** Razorpay says paid. Idempotent: the webhook may arrive twice. */
    public function completeOnlinePayment(Payment $payment, ?string $gatewayPaymentId): void
    {
        DB::transaction(function () use ($payment, $gatewayPaymentId) {
            $payment = Payment::lockForUpdate()->find($payment->id);

            if ($payment === null || $payment->status === 'captured') {
                return;
            }

            $wasPending = $payment->status === 'pending';

            $payment->forceFill([
                'status' => 'captured',
                'gateway_payment_id' => $gatewayPaymentId,
                'admin_verified_at' => now(),
            ])->save();

            if ($payment->promotion_extension_id !== null) {
                $extension = $payment->promotionExtension;

                if ($wasPending && $extension?->status === PromotionExtension::STATUS_PENDING_PAYMENT) {
                    $this->applyExtension($extension);
                } else {
                    Log::critical('Promotion extension paid after it was cancelled — refund needed', ['payment_id' => $payment->id]);
                }

                return;
            }

            $promotion = $payment->promotion;

            if (! $wasPending || $promotion?->status !== Promotion::STATUS_PENDING_PAYMENT) {
                // Paid after it was withdrawn: the money arrived, the sale did
                // not — same handling as a late subscription payment.
                Log::critical('Promotion paid after it was cancelled — refund needed', [
                    'payment_id' => $payment->id,
                    'promotion_id' => $payment->promotion_id,
                ]);

                return;
            }

            $this->goLive($promotion);
        });
    }

    /** The link expired or was cancelled unpaid. */
    public function failOnlinePayment(Payment $payment): void
    {
        DB::transaction(function () use ($payment) {
            $payment = Payment::lockForUpdate()->find($payment->id);

            if ($payment === null || $payment->status !== 'pending') {
                return;
            }

            $payment->update(['status' => 'failed']);

            if ($payment->promotion_extension_id !== null) {
                $payment->promotionExtension?->update(['status' => PromotionExtension::STATUS_CANCELLED]);

                return;
            }

            $promotion = $payment->promotion;

            if ($promotion?->status === Promotion::STATUS_PENDING_PAYMENT) {
                $promotion->update(['status' => Promotion::STATUS_CANCELLED]);
            }
        });
    }

    /** The vendor withdraws an unpaid promotion: the link is cancelled first. */
    public function cancelPending(Promotion $promotion): void
    {
        $payment = $promotion->payment;

        if ($payment !== null && $payment->isPending()) {
            $this->payments->cancelOnline($payment);
            $this->failOnlinePayment($payment);

            return;
        }

        $promotion->update(['status' => Promotion::STATUS_CANCELLED]);
    }

    public function hide(Promotion $promotion, User $admin, string $reason): void
    {
        $promotion->forceFill([
            'is_hidden' => true,
            'hidden_reason' => $reason,
            'hidden_by' => $admin->id,
            'hidden_at' => now(),
        ])->save();

        $this->notifications->notifyPromotion($promotion, PromotionStatusNotification::HIDDEN, $reason);
    }

    public function unhide(Promotion $promotion): void
    {
        $promotion->forceFill([
            'is_hidden' => false,
            'hidden_reason' => null,
            'hidden_by' => null,
            'hidden_at' => null,
        ])->save();
    }

    /** The days count from the moment it is paid, not from the order. */
    private function goLive(Promotion $promotion): void
    {
        $promotion->update([
            'status' => Promotion::STATUS_LIVE,
            'starts_at' => now(),
            'ends_at' => now()->addDays($promotion->duration_days),
        ]);

        DB::afterCommit(fn () => rescue(
            fn () => $this->notifications->notifyPromotion($promotion, PromotionStatusNotification::LIVE),
            report: false,
        ));
    }

    /**
     * Adds a paid extension's days. A promotion that ended meanwhile restarts
     * from now, so the vendor never loses the days they paid for.
     */
    private function applyExtension(PromotionExtension $extension): void
    {
        $promotion = $extension->promotion;
        $from = $promotion->status === Promotion::STATUS_LIVE && $promotion->ends_at?->isFuture()
            ? $promotion->ends_at
            : now();

        $promotion->forceFill([
            'status' => Promotion::STATUS_LIVE,
            'starts_at' => $promotion->starts_at ?? now(),
            'ends_at' => $from->copy()->addDays($extension->days),
            'ending_reminder_sent_at' => null,
        ])->save();

        $extension->update(['status' => PromotionExtension::STATUS_PAID]);
    }
}

<?php

namespace App\Console\Commands;

use App\Models\Promotion;
use App\Notifications\PromotionStatusNotification;
use App\Services\PushNotificationService;
use Illuminate\Console\Command;

/**
 * Daily: ends paid promotions whose days are up, and tells each vendor the
 * day before theirs ends (once — ending_reminder_sent_at).
 *
 * The Feed already stops showing a promotion the moment ends_at passes
 * (Promotion::scopeShowing), so this is bookkeeping for the vendor's list
 * and the admin, not what takes it off customers' screens.
 */
class ProcessPromotionExpiry extends Command
{
    protected $signature = 'promotions:process-expiry';

    protected $description = 'End paid promotions past their end date and remind vendors a day before.';

    public function handle(PushNotificationService $notifications): int
    {
        $ended = 0;
        $reminded = 0;

        // A paused promotion's clock is stopped: it never ends while paused
        // (resume adds the paused time to ends_at).
        Promotion::where('status', Promotion::STATUS_LIVE)
            ->whereNull('paused_at')
            ->where('ends_at', '<=', now())
            ->chunkById(100, function ($promotions) use (&$ended) {
                foreach ($promotions as $promotion) {
                    $promotion->update(['status' => Promotion::STATUS_ENDED]);
                    $ended++;
                }
            });

        Promotion::where('status', Promotion::STATUS_LIVE)
            ->where('is_hidden', false)
            ->whereNull('paused_at')
            ->whereNull('ending_reminder_sent_at')
            ->whereBetween('ends_at', [now(), now()->addDay()])
            ->chunkById(100, function ($promotions) use ($notifications, &$reminded) {
                foreach ($promotions as $promotion) {
                    $promotion->forceFill(['ending_reminder_sent_at' => now()])->save();
                    rescue(fn () => $notifications->notifyPromotion($promotion, PromotionStatusNotification::ENDING), report: false);
                    $reminded++;
                }
            });

        $this->info("Promotions ended: {$ended}; reminders sent: {$reminded}.");

        return self::SUCCESS;
    }
}

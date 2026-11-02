<?php

namespace App\Notifications;

use App\Models\Promotion;
use App\Notifications\Channels\FcmChannel;
use Illuminate\Notifications\Notification;

/**
 * Tells the VENDOR how their paid promotion is doing: it went live, it ends
 * tomorrow, or an admin took it down (with the reason). One class for the
 * three, told apart by `event`, since they share every other field.
 */
class PromotionStatusNotification extends Notification
{
    public const LIVE = 'live';

    public const ENDING = 'ending';

    public const HIDDEN = 'hidden';

    public function __construct(
        private readonly Promotion $promotion,
        private readonly string $event,
        private readonly ?string $reason = null,
    ) {}

    /**
     * @return array<int, string>
     */
    public function via(object $notifiable): array
    {
        return [FcmChannel::class];
    }

    /**
     * @return array<string, mixed>
     */
    public function toFcm(object $notifiable): array
    {
        [$title, $body] = match ($this->event) {
            self::LIVE => ['Your promotion is live', 'Customers in your chosen areas can now see it in their Feed.'],
            self::ENDING => ['Your promotion ends soon', 'It ends tomorrow. Buy another package to keep showing in the Feed.'],
            default => ['Your promotion was removed', $this->reason ?: 'An admin removed it from the Feed.'],
        };

        return [
            'title' => $title,
            'body' => $body,
            'type' => 'promotion_'.$this->event,
            'target_app' => 'vendor',
            'data' => ['promotion_id' => $this->promotion->id],
        ];
    }
}

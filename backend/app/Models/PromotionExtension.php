<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;

/**
 * "Extend promotion": the same package bought again for a running
 * promotion. Paid like any purchase; once paid its [days] are added to the
 * promotion's ends_at (PromotionService::applyExtension).
 */
class PromotionExtension extends Model
{
    public const STATUS_PENDING_PAYMENT = 'pending_payment';

    public const STATUS_PAID = 'paid';

    public const STATUS_CANCELLED = 'cancelled';

    protected $fillable = ['promotion_id', 'days', 'price_paise', 'status', 'idempotency_key'];

    protected function casts(): array
    {
        return ['days' => 'integer', 'price_paise' => 'integer'];
    }

    public function promotion(): BelongsTo
    {
        return $this->belongsTo(Promotion::class);
    }

    public function payment(): HasOne
    {
        return $this->hasOne(Payment::class)->latestOfMany();
    }
}

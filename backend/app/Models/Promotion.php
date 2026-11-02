<?php

namespace App\Models;

use App\Models\Concerns\RecordsAuditLog;
use App\Models\Concerns\TracksFileDisk;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\Relations\MorphMany;

/**
 * A vendor's paid post in the customer app's Feed tab (decided 2026-10-31).
 *
 * Lifecycle: pending_payment → live (on payment; the days count from then)
 * → ended (promotions:process-expiry). A sale withdrawn before payment is
 * cancelled. No admin review before going live (decided); an admin can hide
 * a live one (is_hidden), which takes it out of every feed at once.
 */
class Promotion extends Model
{
    use RecordsAuditLog;
    use TracksFileDisk;

    public const STATUS_PENDING_PAYMENT = 'pending_payment';

    public const STATUS_LIVE = 'live';

    public const STATUS_ENDED = 'ended';

    public const STATUS_CANCELLED = 'cancelled';

    protected $fillable = [
        'vendor_id',
        'promotion_package_id',
        'caption',
        'media_type',
        'media_path',
        'disk',
        'price_paise',
        'duration_days',
        'status',
        'starts_at',
        'ends_at',
        'idempotency_key',
    ];

    protected function casts(): array
    {
        return [
            'price_paise' => 'integer',
            'duration_days' => 'integer',
            'starts_at' => 'datetime',
            'ends_at' => 'datetime',
            'paused_at' => 'datetime',
            'ending_reminder_sent_at' => 'datetime',
            'is_hidden' => 'boolean',
            'hidden_at' => 'datetime',
            'views_count' => 'integer',
        ];
    }

    public function fileDiskPathColumn(): string
    {
        return 'media_path';
    }

    public function vendor(): BelongsTo
    {
        return $this->belongsTo(Vendor::class);
    }

    public function package(): BelongsTo
    {
        return $this->belongsTo(PromotionPackage::class, 'promotion_package_id');
    }

    public function zones(): BelongsToMany
    {
        return $this->belongsToMany(Zone::class, 'promotion_zone');
    }

    public function likes(): MorphMany
    {
        return $this->morphMany(FeedLike::class, 'likeable');
    }

    public function comments(): MorphMany
    {
        return $this->morphMany(FeedComment::class, 'commentable');
    }

    public function leads(): HasMany
    {
        return $this->hasMany(Lead::class);
    }

    public function payment(): HasOne
    {
        // The purchase itself — extension payments carry promotion_id too.
        return $this->hasOne(Payment::class)->ofMany(['id' => 'max'], fn ($query) => $query->whereNull('promotion_extension_id'));
    }

    public function hiddenBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'hidden_by');
    }

    public function extensions(): HasMany
    {
        return $this->hasMany(PromotionExtension::class);
    }

    /** Running now, not paused, not taken down: what a customer may be shown. */
    public function scopeShowing(Builder $query): Builder
    {
        return $query->where('promotions.status', self::STATUS_LIVE)
            ->where('promotions.is_hidden', false)
            ->whereNull('promotions.paused_at')
            ->where('promotions.starts_at', '<=', now())
            ->where('promotions.ends_at', '>', now());
    }

    public function isShowing(): bool
    {
        return $this->status === self::STATUS_LIVE
            && ! $this->is_hidden
            && $this->paused_at === null
            && $this->starts_at?->lte(now())
            && $this->ends_at?->gt(now());
    }

    public function isPaused(): bool
    {
        return $this->status === self::STATUS_LIVE && $this->paused_at !== null;
    }

    public function hasMedia(): bool
    {
        return filled($this->media_path);
    }
}

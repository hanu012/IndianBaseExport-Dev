<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\MorphMany;
use Illuminate\Database\Eloquent\Relations\MorphTo;

/**
 * A customer's comment on a feed post (Promotion or portfolio Media). Public
 * at once; customers can report one and an admin hides it from Promotions →
 * Feed comments (is_hidden), which removes it from the app and its counts.
 */
class FeedComment extends Model
{
    /**
     * Written by a customer (customer_id) or by the vendor who owns the post,
     * replying as the business (vendor_id). parent_id makes it a reply —
     * one level only, always under a top-level comment.
     */
    protected $fillable = ['commentable_type', 'commentable_id', 'parent_id', 'customer_id', 'vendor_id', 'body'];

    protected function casts(): array
    {
        return [
            'is_hidden' => 'boolean',
            'hidden_at' => 'datetime',
            'reports_count' => 'integer',
        ];
    }

    public function commentable(): MorphTo
    {
        return $this->morphTo();
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }

    public function vendor(): BelongsTo
    {
        return $this->belongsTo(Vendor::class);
    }

    public function parent(): BelongsTo
    {
        return $this->belongsTo(self::class, 'parent_id');
    }

    public function replies(): HasMany
    {
        return $this->hasMany(self::class, 'parent_id');
    }

    public function likes(): MorphMany
    {
        return $this->morphMany(FeedLike::class, 'likeable');
    }

    public function reports(): HasMany
    {
        return $this->hasMany(FeedCommentReport::class);
    }

    public function isBusinessReply(): bool
    {
        return $this->vendor_id !== null;
    }

    public function authorName(): string
    {
        return $this->vendor?->business_name ?? $this->customer?->user?->name ?? 'Customer';
    }

    public function authorAvatarUrl(): ?string
    {
        return $this->vendor
            ? $this->vendor->fileUrl($this->vendor->shop_photo_path)
            : $this->customer?->user?->avatarUrl();
    }

    public function hiddenBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'hidden_by');
    }

    public function scopeVisible(Builder $query): Builder
    {
        return $query->where('is_hidden', false);
    }
}

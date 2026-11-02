<?php

namespace App\Models;

use App\Models\Concerns\RecordsAuditLog;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * A promotion a vendor can buy (decided 2026-10-31): how long it runs, what
 * it costs, how many zones it may target and whether a video is allowed.
 *
 * Never deleted — switched off instead (is_active), like Plans: promotions
 * already bought point at it (ON DELETE RESTRICT), and PromotionPackagePolicy
 * has no delete method.
 */
class PromotionPackage extends Model
{
    use RecordsAuditLog;

    protected $fillable = [
        'name',
        'description',
        'duration_days',
        'price_paise',
        'max_zones',
        'allows_video',
        'is_popular',
        'is_active',
        'sort_order',
    ];

    protected function casts(): array
    {
        return [
            'duration_days' => 'integer',
            'price_paise' => 'integer',
            'max_zones' => 'integer',
            'allows_video' => 'boolean',
            'is_popular' => 'boolean',
            'is_active' => 'boolean',
            'sort_order' => 'integer',
        ];
    }

    public function promotions(): HasMany
    {
        return $this->hasMany(Promotion::class);
    }

    public function scopeActive(Builder $query): Builder
    {
        return $query->where('is_active', true);
    }

    /** Rupees for display and form input; paise is what is stored. */
    public function priceInRupees(): string
    {
        return number_format($this->price_paise / 100, 2, '.', '');
    }
}

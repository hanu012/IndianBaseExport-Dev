<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\MorphTo;

/** One customer's like on a feed post (Promotion or portfolio Media). */
class FeedLike extends Model
{
    protected $fillable = ['likeable_type', 'likeable_id', 'customer_id'];

    public function likeable(): MorphTo
    {
        return $this->morphTo();
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }
}

<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** A customer flagging a feed comment — unique per customer and comment. */
class FeedCommentReport extends Model
{
    protected $fillable = ['feed_comment_id', 'customer_id', 'reason'];

    public function comment(): BelongsTo
    {
        return $this->belongsTo(FeedComment::class, 'feed_comment_id');
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }
}

<?php

namespace App\Policies;

use App\Models\User;

/**
 * Customer comments in the Feed: listed under promotions.viewAny, hidden or
 * shown again under promotions.moderate. Customers write them in the app.
 */
class FeedCommentPolicy extends AdminModulePolicy
{
    protected function module(): string
    {
        return 'promotions';
    }

    public function create(User $user): bool
    {
        return false;
    }

    public function update(User $user, $record = null): bool
    {
        return false;
    }

    public function moderate(User $user, $record = null): bool
    {
        return $user->hasPermission('promotions.moderate');
    }
}

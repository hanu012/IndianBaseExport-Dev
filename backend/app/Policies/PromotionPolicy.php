<?php

namespace App\Policies;

use App\Models\User;

/**
 * Vendors' paid promotions in the admin: listed and viewed under
 * promotions.viewAny; hidden/unhidden under promotions.moderate. Vendors
 * create them from the app, so there is no admin create or edit.
 */
class PromotionPolicy extends AdminModulePolicy
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

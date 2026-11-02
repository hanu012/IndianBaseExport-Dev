<?php

namespace App\Policies;

/**
 * Promotion packages: view, create, edit. No delete — a package is switched
 * off instead, since bought promotions point at it (ON DELETE RESTRICT).
 */
class PromotionPackagePolicy extends AdminModulePolicy
{
    protected function module(): string
    {
        return 'promotions';
    }
}

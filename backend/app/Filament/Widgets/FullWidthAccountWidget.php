<?php

namespace App\Filament\Widgets;

use Filament\Widgets\AccountWidget;

/**
 * Filament's "Welcome / Administrator" card at the top of the dashboard,
 * across the full width instead of half (picked up by discoverWidgets in
 * AdminPanelProvider, which no longer lists the stock AccountWidget).
 */
class FullWidthAccountWidget extends AccountWidget
{
    protected int|string|array $columnSpan = 'full';
}

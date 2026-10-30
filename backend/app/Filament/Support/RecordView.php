<?php

namespace App\Filament\Support;

use Closure;
use Filament\Infolists\Components\Section;
use Filament\Support\Enums\MaxWidth;
use Filament\Tables\Actions\ViewAction;
use Illuminate\Database\Eloquent\Model;

/**
 * The admin's one way of showing a record, after the ehhs admin's provider
 * screens (decided 2026-10-29):
 *
 *  1. The list keeps only what is needed to find a row, and each row has
 *     one action — View. (Work queues — media moderation, reviews, payment
 *     reconciliation, reports — keep their one-click buttons as well.)
 *  2. View opens a wide pop-up of collapsible sections, each value in its
 *     own boxed tile ({@see section()}, styled by
 *     resources/views/filament/hooks/record-view-styles.blade.php).
 *  3. The pop-up's footer has Edit and Close; the Edit page holds the
 *     record's own actions (approve, reject, change status…).
 */
final class RecordView
{
    /** The class record-view-styles.blade.php scopes the tiles to. */
    public const TILES = 'sm-tiles';

    /** A collapsible section whose values sit in boxed tiles, four across. */
    public static function section(string $heading): Section
    {
        return Section::make($heading)
            ->collapsible()
            ->columns(['default' => 1, 'sm' => 2, 'lg' => 4])
            ->extraAttributes(['class' => self::TILES]);
    }

    /**
     * The row's single action: an outlined "View" opening the pop-up, with
     * Edit beside Close when [$editUrl] gives a URL for the record (null or
     * no URL — e.g. not allowed to edit — leaves Close alone).
     *
     * @param  Closure(Model): ?string|null  $editUrl
     * @param  Closure(Model): string|null  $heading
     * @param  Closure(Model): ?string|null  $description
     */
    public static function action(
        ?Closure $editUrl = null,
        ?Closure $heading = null,
        ?Closure $description = null,
    ): ViewAction {
        $action = ViewAction::make()
            ->label('View')
            ->icon('heroicon-o-eye')
            ->button()
            ->outlined()
            ->size('sm')
            ->color('gray')
            ->modalWidth(MaxWidth::FiveExtraLarge)
            ->modalCancelActionLabel('Close')
            ->extraModalFooterActions(function (ViewAction $view) use ($editUrl): array {
                $url = $editUrl === null ? null : $editUrl($view->getRecord());

                if ($url === null) {
                    return [];
                }

                return [
                    $view->makeModalAction('edit')
                        ->label('Edit')
                        ->icon('heroicon-o-pencil-square')
                        ->color('primary')
                        ->url($url),
                ];
            });

        if ($heading !== null) {
            $action->modalHeading($heading);
        }

        if ($description !== null) {
            $action->modalDescription($description);
        }

        return $action;
    }
}

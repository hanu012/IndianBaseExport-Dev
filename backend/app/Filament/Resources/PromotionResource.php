<?php

namespace App\Filament\Resources;

use App\Filament\Resources\PromotionResource\Pages;
use App\Filament\Support\RecordView;
use App\Models\Promotion;
use App\Services\PromotionService;
use Filament\Forms\Components\Textarea;
use Filament\Infolists\Components\ImageEntry;
use Filament\Infolists\Components\TextEntry;
use Filament\Infolists\Infolist;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Tables\Actions\Action;
use Filament\Tables\Columns\ImageColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Number;

/**
 * Vendors' paid promotions (decided 2026-10-31). They go live on payment
 * with no review first, so this is where an unacceptable one comes down:
 * Hide (with a reason the vendor is told) and Show again. A moderation
 * queue, so the row keeps those one-click buttons beside View (CLAUDE.md,
 * admin list layout exception). Vendors create them in the app — no create
 * or edit here.
 */
class PromotionResource extends Resource
{
    protected static ?string $model = Promotion::class;

    protected static ?string $navigationIcon = 'heroicon-o-sparkles';

    protected static ?string $navigationGroup = 'Promotions';

    protected static ?string $navigationLabel = 'Vendor promotions';

    protected static ?int $navigationSort = 2;

    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery()
            ->with(['vendor', 'package', 'zones'])
            ->withCount(['likes', 'comments' => fn ($query) => $query->visible(), 'leads']);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->defaultSort('created_at', 'desc')
            ->recordUrl(null)
            ->recordAction('view')
            ->columns([
                ImageColumn::make('media')
                    ->label('')
                    ->state(fn (Promotion $record): ?string => $record->media_type === 'image' ? $record->fileUrl() : null)
                    ->square()
                    ->size(48),

                TextColumn::make('vendor.business_name')
                    ->label('Vendor')
                    ->searchable()
                    ->weight('bold')
                    ->description(fn (Promotion $record): string => str($record->caption)->limit(60)),

                TextColumn::make('package.name')
                    ->label('Package')
                    ->description(fn (Promotion $record): string => Number::currency($record->price_paise / 100, 'INR')),

                TextColumn::make('state')
                    ->label('Status')
                    ->badge()
                    ->state(fn (Promotion $record): string => static::stateLabel($record))
                    ->color(fn (Promotion $record): string => match (static::stateLabel($record)) {
                        'Live' => 'success',
                        'Waiting for payment' => 'warning',
                        'Hidden' => 'danger',
                        default => 'gray',
                    }),

                TextColumn::make('ends_at')->label('Ends')->dateTime('d M Y, H:i')->sortable()->placeholder('—'),

                TextColumn::make('numbers')
                    ->label('Views · Likes · Comments · Calls')
                    ->state(fn (Promotion $record): string => "{$record->views_count} · {$record->likes_count} · {$record->comments_count} · {$record->leads_count}"),
            ])
            ->actions([
                RecordView::action(
                    heading: fn (Promotion $record): string => $record->vendor?->business_name ?? 'Promotion',
                    description: fn (Promotion $record): string => static::stateLabel($record),
                ),

                Action::make('hide')
                    ->label('Hide')
                    ->icon('heroicon-o-eye-slash')
                    ->color('danger')
                    ->visible(fn (Promotion $record): bool => ! $record->is_hidden && Auth::user()?->can('moderate', $record))
                    ->form([
                        Textarea::make('reason')
                            ->label('Reason (sent to the vendor)')
                            ->required()
                            ->maxLength(500),
                    ])
                    ->action(function (Promotion $record, array $data) {
                        app(PromotionService::class)->hide($record, Auth::user(), $data['reason']);
                        Notification::make()->title('Promotion hidden from the Feed')->success()->send();
                    }),

                Action::make('unhide')
                    ->label('Show again')
                    ->icon('heroicon-o-eye')
                    ->color('gray')
                    ->requiresConfirmation()
                    ->visible(fn (Promotion $record): bool => $record->is_hidden && Auth::user()?->can('moderate', $record))
                    ->action(function (Promotion $record) {
                        app(PromotionService::class)->unhide($record);
                        Notification::make()->title('Promotion shown again')->success()->send();
                    }),
            ])
            ->bulkActions([])
            ->emptyStateHeading('No promotions yet')
            ->emptyStateDescription('Vendors buy promotions from the vendor app (Profile → Promote your business).');
    }

    public static function infolist(Infolist $infolist): Infolist
    {
        return $infolist->schema([
            RecordView::section('Post')->schema([
                ImageEntry::make('media')
                    ->label('Photo')
                    ->state(fn (Promotion $record): ?string => $record->fileUrl())
                    ->visible(fn (Promotion $record): bool => $record->media_type === 'image')
                    ->height(220)
                    ->columnSpanFull(),
                TextEntry::make('video')
                    ->label('Video')
                    ->state(fn (Promotion $record): ?string => $record->fileUrl())
                    ->url(fn (Promotion $record): ?string => $record->fileUrl(), shouldOpenInNewTab: true)
                    ->visible(fn (Promotion $record): bool => $record->media_type === 'video')
                    ->columnSpanFull(),
                TextEntry::make('caption')->columnSpanFull(),
                TextEntry::make('zones.name')->label('Areas')->badge()->columnSpanFull(),
            ]),
            RecordView::section('Purchase')->schema([
                TextEntry::make('vendor.business_name')->label('Vendor'),
                TextEntry::make('package.name')->label('Package'),
                TextEntry::make('price_paise')->label('Paid')
                    ->formatStateUsing(fn (int $state): string => Number::currency($state / 100, 'INR')),
                TextEntry::make('state')->label('Status')->badge()
                    ->state(fn (Promotion $record): string => static::stateLabel($record)),
                TextEntry::make('starts_at')->label('Started')->dateTime('d M Y, H:i')->placeholder('—'),
                TextEntry::make('ends_at')->label('Ends')->dateTime('d M Y, H:i')->placeholder('—'),
                TextEntry::make('hidden_reason')->label('Hidden because')->placeholder('—')
                    ->visible(fn (Promotion $record): bool => $record->is_hidden)->columnSpanFull(),
            ]),
            RecordView::section('Numbers')->schema([
                TextEntry::make('views_count')->label('Views'),
                TextEntry::make('likes_count')->label('Likes'),
                TextEntry::make('comments_count')->label('Comments'),
                TextEntry::make('leads_count')->label('Calls & WhatsApp'),
            ]),
        ]);
    }

    public static function stateLabel(Promotion $record): string
    {
        if ($record->is_hidden) {
            return 'Hidden';
        }

        return match ($record->status) {
            Promotion::STATUS_LIVE => $record->ends_at?->isPast() ? 'Ended' : 'Live',
            Promotion::STATUS_PENDING_PAYMENT => 'Waiting for payment',
            Promotion::STATUS_CANCELLED => 'Cancelled',
            default => 'Ended',
        };
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListPromotions::route('/'),
        ];
    }
}

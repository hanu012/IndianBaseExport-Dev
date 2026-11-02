<?php

namespace App\Filament\Resources;

use App\Filament\Resources\FeedCommentResource\Pages;
use App\Models\FeedComment;
use App\Models\Promotion;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Tables\Actions\Action;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Str;

/**
 * Customer comments on Feed posts (decided 2026-10-31). Public at once;
 * customers can report one. A moderation queue: Hide and Show again are
 * one-click row buttons (CLAUDE.md, admin list layout exception).
 */
class FeedCommentResource extends Resource
{
    protected static ?string $model = FeedComment::class;

    protected static ?string $navigationIcon = 'heroicon-o-chat-bubble-left-right';

    protected static ?string $navigationGroup = 'Promotions';

    protected static ?string $navigationLabel = 'Feed comments';

    protected static ?string $modelLabel = 'feed comment';

    protected static ?int $navigationSort = 3;

    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery()->with(['customer.user', 'vendor', 'commentable', 'parent.customer.user', 'parent.vendor']);
    }

    public static function getNavigationBadge(): ?string
    {
        $reported = FeedComment::where('is_hidden', false)->where('reports_count', '>', 0)->count();

        return $reported > 0 ? (string) $reported : null;
    }

    public static function getNavigationBadgeColor(): ?string
    {
        return 'danger';
    }

    public static function table(Table $table): Table
    {
        return $table
            ->defaultSort('created_at', 'desc')
            ->columns([
                TextColumn::make('body')
                    ->label('Comment')
                    ->wrap()
                    ->searchable()
                    ->description(fn (FeedComment $record): string => 'by '.$record->authorName()
                        .($record->parent ? ' · reply to '.$record->parent->authorName().': "'.Str::limit($record->parent->body, 40).'"' : '')),

                // The vendor answering on their own post, as the business —
                // shown with the same "Business" tag the customer app uses.
                TextColumn::make('author_type')
                    ->label('By')
                    ->badge()
                    ->state(fn (FeedComment $record): string => $record->isBusinessReply() ? 'Business' : 'Customer')
                    ->color(fn (string $state): string => $state === 'Business' ? 'primary' : 'gray'),

                TextColumn::make('on')
                    ->label('On')
                    ->state(fn (FeedComment $record): string => static::postLabel($record)),

                TextColumn::make('reports_count')
                    ->label('Reports')
                    ->badge()
                    ->sortable()
                    ->color(fn (int $state): string => $state > 0 ? 'danger' : 'gray'),

                TextColumn::make('is_hidden')
                    ->label('Status')
                    ->badge()
                    ->formatStateUsing(fn (bool $state): string => $state ? 'Hidden' : 'Visible')
                    ->color(fn (bool $state): string => $state ? 'danger' : 'success'),

                TextColumn::make('created_at')->label('Posted')->dateTime('d M Y, H:i')->sortable(),
            ])
            ->actions([
                Action::make('hide')
                    ->label('Hide')
                    ->icon('heroicon-o-eye-slash')
                    ->color('danger')
                    ->requiresConfirmation()
                    ->visible(fn (FeedComment $record): bool => ! $record->is_hidden && Auth::user()?->can('moderate', $record))
                    ->action(function (FeedComment $record) {
                        $record->forceFill(['is_hidden' => true, 'hidden_by' => Auth::id(), 'hidden_at' => now()])->save();
                        Notification::make()->title('Comment hidden')->success()->send();
                    }),

                Action::make('unhide')
                    ->label('Show again')
                    ->icon('heroicon-o-eye')
                    ->color('gray')
                    ->visible(fn (FeedComment $record): bool => $record->is_hidden && Auth::user()?->can('moderate', $record))
                    ->action(function (FeedComment $record) {
                        $record->forceFill(['is_hidden' => false, 'hidden_by' => null, 'hidden_at' => null])->save();
                        Notification::make()->title('Comment shown again')->success()->send();
                    }),
            ])
            ->bulkActions([])
            ->emptyStateHeading('No comments yet');
    }

    /** "Promotion · Cool Air Services" or "Post · Cool Air Services". */
    public static function postLabel(FeedComment $record): string
    {
        $post = $record->commentable;
        $vendor = $post instanceof Promotion ? $post->vendor : $post?->mediable;

        return ($post instanceof Promotion ? 'Promotion' : 'Post').' · '.($vendor?->business_name ?? '—');
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListFeedComments::route('/'),
        ];
    }
}

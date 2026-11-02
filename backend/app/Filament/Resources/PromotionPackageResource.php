<?php

namespace App\Filament\Resources;

use App\Filament\Resources\PromotionPackageResource\Pages;
use App\Filament\Support\RecordStatus;
use App\Filament\Support\RecordView;
use App\Models\PromotionPackage;
use Filament\Forms\Components\Section;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Forms\Form;
use Filament\Infolists\Components\IconEntry;
use Filament\Infolists\Components\TextEntry;
use Filament\Infolists\Infolist;
use Filament\Resources\Resource;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Number;

/**
 * Paid promotion packages (decided 2026-10-31) — what vendors can buy to
 * appear at the top of customers' Feed in their zones.
 *
 * NO DELETE, same as Plans: bought promotions point at the package with ON
 * DELETE RESTRICT. Switch it off with "Change status" on the edit page —
 * running promotions continue, new ones cannot pick it.
 */
class PromotionPackageResource extends Resource
{
    protected static ?string $model = PromotionPackage::class;

    protected static ?string $navigationIcon = 'heroicon-o-megaphone';

    protected static ?string $navigationGroup = 'Promotions';

    protected static ?string $navigationLabel = 'Packages';

    protected static ?string $modelLabel = 'promotion package';

    protected static ?int $navigationSort = 1;

    protected static ?string $recordTitleAttribute = 'name';

    public static function form(Form $form): Form
    {
        return $form->schema([
            Section::make('Package')
                ->columns(2)
                ->schema([
                    TextInput::make('name')
                        ->required()
                        ->maxLength(255)
                        ->helperText('Shown to vendors, e.g. "7-Day Premium Reach".'),

                    // Rupees in the field, paise in the column — converted in
                    // the Create/Edit pages with Plan::rupeesToPaise(). Stays
                    // dehydrated so the hook receives it (CLAUDE.md).
                    TextInput::make('price_rupees')
                        ->label('Price')
                        ->prefix('₹')
                        ->required()
                        ->numeric()
                        ->minValue(0)
                        ->step('0.01')
                        ->helperText('Charged to the vendor for the whole package.')
                        ->afterStateHydrated(function (TextInput $component, ?PromotionPackage $record) {
                            $component->state($record?->priceInRupees() ?? '0.00');
                        }),

                    TextInput::make('duration_days')
                        ->label('Duration (days)')
                        ->required()
                        ->numeric()
                        ->minValue(1)
                        ->helperText('Counted from the moment the vendor pays.'),

                    Textarea::make('description')
                        ->rows(2)
                        ->columnSpanFull(),

                    Toggle::make('allows_video')
                        ->label('Video allowed')
                        ->default(true)
                        ->helperText('Off: the vendor can post a photo only.'),

                    Toggle::make('is_popular')
                        ->label('Most popular')
                        ->default(false)
                        ->helperText('Shows a "Most popular" tag on this package in the vendor app.'),

                    // Starting status only; afterwards "Change status". Hidden
                    // on edit, not disabled — CLAUDE.md.
                    Toggle::make('is_active')
                        ->label('Active')
                        ->default(true)
                        ->hiddenOn('edit')
                        ->helperText('Inactive packages are hidden from vendors. Running promotions continue.'),
                ]),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->reorderable('sort_order')
            ->defaultSort('sort_order')
            ->recordUrl(null)
            ->recordAction('view')
            ->columns([
                TextColumn::make('name')
                    ->searchable()
                    ->weight('bold')
                    ->description(fn (PromotionPackage $record): ?string => $record->description),

                TextColumn::make('price_paise')
                    ->label('Price')
                    ->sortable()
                    ->formatStateUsing(fn (int $state): string => Number::currency($state / 100, 'INR'))
                    ->description(fn (PromotionPackage $record): string => $record->duration_days.' days'),

                IconColumn::make('allows_video')->label('Video')->boolean(),

                TextColumn::make('promotions_count')
                    ->label('Sold')
                    ->counts('promotions')
                    ->badge()
                    ->color('gray'),

                RecordStatus::column(),
            ])
            ->actions([
                RecordView::action(
                    editUrl: fn (PromotionPackage $record): ?string => Auth::user()?->can('update', $record)
                        ? static::getUrl('edit', ['record' => $record])
                        : null,
                    heading: fn (PromotionPackage $record): string => $record->name,
                ),
                // No delete — see the class docblock.
            ])
            ->bulkActions([])
            ->emptyStateHeading('No promotion packages yet')
            ->emptyStateDescription('A package sets how long a vendor\'s post shows at the top of the Feed and what it costs.');
    }

    public static function infolist(Infolist $infolist): Infolist
    {
        return $infolist->schema([
            RecordView::section('Package')->schema([
                TextEntry::make('name'),
                TextEntry::make('price_paise')->label('Price')
                    ->formatStateUsing(fn (int $state): string => Number::currency($state / 100, 'INR')),
                TextEntry::make('duration_days')->label('Duration')->suffix(' days'),
                IconEntry::make('allows_video')->label('Video allowed')->boolean(),
                IconEntry::make('is_popular')->label('Most popular')->boolean(),
                RecordStatus::entry(),
                TextEntry::make('description')->placeholder('—')->columnSpanFull(),
            ]),
        ]);
    }

    /** What switching it off or on does — shown in "Change status". */
    public static function statusEffects(PromotionPackage $record): string
    {
        $live = $record->promotions()->where('status', 'live')->count();

        return $record->is_active
            ? "Vendors can no longer buy it. {$live} running promotion(s) continue to their end."
            : 'Vendors can buy it again.';
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListPromotionPackages::route('/'),
            'create' => Pages\CreatePromotionPackage::route('/create'),
            'edit' => Pages\EditPromotionPackage::route('/{record}/edit'),
        ];
    }
}

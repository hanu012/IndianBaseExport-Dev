<?php

namespace App\Filament\Resources\PromotionResource\Pages;

use App\Filament\Resources\PromotionResource;
use App\Models\Promotion;
use Filament\Resources\Components\Tab;
use Filament\Resources\Pages\ListRecords;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\HtmlString;

class ListPromotions extends ListRecords
{
    protected static string $resource = PromotionResource::class;

    public function getTabs(): array
    {
        $tab = fn (string $label, ?\Closure $scope) => Tab::make($label)
            ->badge(Promotion::query()->when($scope, $scope)->count())
            ->modifyQueryUsing(fn (Builder $query) => $scope ? $scope($query) : $query);

        return [
            'all' => $tab('All', null),
            'live' => $tab('Live', fn (Builder $q) => $q->showing()),
            'pending' => $tab('Waiting for payment', fn (Builder $q) => $q->where('status', Promotion::STATUS_PENDING_PAYMENT)),
            'hidden' => $tab('Hidden', fn (Builder $q) => $q->where('is_hidden', true)),
            'ended' => $tab('Ended', fn (Builder $q) => $q->where('is_hidden', false)
                ->where(fn (Builder $q) => $q->where('status', Promotion::STATUS_ENDED)
                    ->orWhere(fn (Builder $q) => $q->where('status', Promotion::STATUS_LIVE)->where('ends_at', '<=', now())))),
        ];
    }

    public function getSubheading(): ?HtmlString
    {
        return new HtmlString(
            'Vendors\' paid posts, shown <strong>first in the customer Feed</strong> for the areas they '
            .'chose. They go live on payment <strong>without review</strong> — <em>Hide</em> takes one down '
            .'at once and tells the vendor why.'
        );
    }
}

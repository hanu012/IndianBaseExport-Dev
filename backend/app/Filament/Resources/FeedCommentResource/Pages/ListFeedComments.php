<?php

namespace App\Filament\Resources\FeedCommentResource\Pages;

use App\Filament\Resources\FeedCommentResource;
use App\Models\FeedComment;
use Filament\Resources\Components\Tab;
use Filament\Resources\Pages\ListRecords;
use Illuminate\Database\Eloquent\Builder;

class ListFeedComments extends ListRecords
{
    protected static string $resource = FeedCommentResource::class;

    public function getTabs(): array
    {
        $tab = fn (string $label, ?\Closure $scope) => Tab::make($label)
            ->badge(FeedComment::query()->when($scope, $scope)->count())
            ->modifyQueryUsing(fn (Builder $query) => $scope ? $scope($query) : $query);

        return [
            'reported' => $tab('Reported', fn (Builder $q) => $q->where('is_hidden', false)->where('reports_count', '>', 0)),
            'all' => $tab('All', null),
            'hidden' => $tab('Hidden', fn (Builder $q) => $q->where('is_hidden', true)),
        ];
    }

    public function getSubheading(): ?string
    {
        return 'What customers write on Feed posts. Comments are public at once; reported ones are listed first. '
            .'Hiding one removes it from the app and from the post\'s comment count.';
    }
}

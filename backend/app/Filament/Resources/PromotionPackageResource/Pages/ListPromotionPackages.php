<?php

namespace App\Filament\Resources\PromotionPackageResource\Pages;

use App\Filament\Resources\PromotionPackageResource;
use App\Filament\Support\RecordStatus;
use App\Models\PromotionPackage;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;
use Illuminate\Support\HtmlString;

class ListPromotionPackages extends ListRecords
{
    protected static string $resource = PromotionPackageResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\CreateAction::make(),
        ];
    }

    /** All / Active / Inactive, each with its count. */
    public function getTabs(): array
    {
        return RecordStatus::tabs(PromotionPackage::class, 'packages');
    }

    public function getSubheading(): ?HtmlString
    {
        return new HtmlString(
            'What vendors can buy to show a post at the <strong>top of customers\' Feed</strong> in '
            .'their own areas. Paid like a subscription; the days count from payment. Packages are '
            .'<strong>switched off, not deleted</strong> — running promotions keep going. Editing a '
            .'price never changes what a vendor already paid.'
        );
    }
}

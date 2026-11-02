<?php

namespace App\Filament\Resources\PromotionPackageResource\Pages;

use App\Filament\Resources\PromotionPackageResource;
use App\Filament\Support\RecordStatus;
use App\Models\Plan;
use App\Models\PromotionPackage;
use Filament\Actions\Action;
use Filament\Resources\Pages\EditRecord;

class EditPromotionPackage extends EditRecord
{
    protected static string $resource = PromotionPackageResource::class;

    protected function getHeaderActions(): array
    {
        // No delete — see PromotionPackageResource's docblock.
        return [
            RecordStatus::configure(
                Action::make('changeStatus'),
                fn (PromotionPackage $record): string => PromotionPackageResource::statusEffects($record),
            ),
        ];
    }

    public function getSubheading(): ?string
    {
        return RecordStatus::summary(
            $this->getRecord(),
            'vendors can buy it.',
            'hidden from vendors. Running promotions continue to their end.',
        );
    }

    protected function mutateFormDataBeforeSave(array $data): array
    {
        $data['price_paise'] = Plan::rupeesToPaise($data['price_rupees'] ?? 0);
        unset($data['price_rupees']);

        return $data;
    }

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }
}

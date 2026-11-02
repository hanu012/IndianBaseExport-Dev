<?php

namespace App\Filament\Resources\PromotionPackageResource\Pages;

use App\Filament\Resources\PromotionPackageResource;
use App\Models\Plan;
use Filament\Resources\Pages\CreateRecord;

class CreatePromotionPackage extends CreateRecord
{
    protected static string $resource = PromotionPackageResource::class;

    /** Rupees in, paise stored — the same string-safe conversion as plans. */
    protected function mutateFormDataBeforeCreate(array $data): array
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

<?php

namespace App\Http\Requests\Concerns;

/**
 * The three ways a customer request says where it is: a zone picked from
 * the list (the app's zone mode), a GPS point, or a pincode. Shared by
 * every request that ends in ZoneMatcher::resolve(), so they all accept
 * the same fields.
 */
trait HasCustomerLocation
{
    /**
     * @return array<string, mixed>
     */
    protected function locationRules(): array
    {
        return [
            // Not exists:zones — a stale or inactive id simply matches no
            // zone (ZoneMatcher::matchZoneId), the same "no match" outcome
            // as a point outside every zone.
            'zone_id' => ['nullable', 'integer', 'min:1'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
            'pincode' => ['nullable', 'string', 'max:10'],
        ];
    }

    public function hasPoint(): bool
    {
        return $this->filled('latitude') && $this->filled('longitude');
    }

    public function hasLocation(): bool
    {
        return $this->filled('zone_id') || $this->hasPoint() || $this->filled('pincode');
    }

    public function zoneId(): ?int
    {
        return $this->filled('zone_id') ? (int) $this->input('zone_id') : null;
    }

    public function latitude(): ?float
    {
        return $this->hasPoint() ? (float) $this->input('latitude') : null;
    }

    public function longitude(): ?float
    {
        return $this->hasPoint() ? (float) $this->input('longitude') : null;
    }

    public function pincode(): ?string
    {
        return $this->filled('pincode') ? $this->string('pincode')->toString() : null;
    }
}

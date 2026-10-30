<?php

namespace App\Http\Resources;

use App\Models\Vendor;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * A vendor's public detail page (SPEC section 4 item 6, task 5.4) —
 * services offered, approved media, reviews, distance, everything the
 * Call/WhatsApp buttons need.
 *
 * `services`/`media`/`reviews`/`distanceKm` aren't columns on Vendor, so
 * they're passed in explicitly rather than derived inside toArray() —
 * the controller already did the (subscription-scoped, moderation-
 * filtered, hidden-filtered) querying, this class only shapes the
 * response.
 */
class VendorDetailResource extends JsonResource
{
    /**
     * @param  array<int, array<string, mixed>>  $services
     * @param  array<int, array<string, mixed>>  $media
     * @param  array<int, array<string, mixed>>  $reviews
     * @param  array<int, string>  $serviceAreas
     */
    public function __construct(
        Vendor $resource,
        private readonly array $services,
        private readonly array $media,
        private readonly array $reviews,
        private readonly ?float $distanceKm,
        private readonly array $serviceAreas = [],
    ) {
        parent::__construct($resource);
    }

    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'business_name' => $this->business_name,
            'owner_name' => $this->owner_name,
            'address' => $this->address,
            'city' => $this->city,
            // Zone names the vendor's subscription covers — the one piece of
            // location every customer-visible vendor has, address or not.
            'service_areas' => $this->serviceAreas,
            'latitude' => $this->latitude,
            'longitude' => $this->longitude,
            'phone' => $this->phone,
            'shop_photo_url' => $this->fileUrl($this->shop_photo_path),
            'rating_avg' => $this->rating_avg,
            'rating_count' => $this->rating_count,
            'distance_km' => $this->distanceKm,
            'services' => $this->services,
            'media' => $this->media,
            'reviews' => $this->reviews,
            'is_favorite' => $request->user()?->customer?->hasFavorited($this->id) ?? false,
            // Whether "Write a review" is offered — same rule POST /reviews
            // enforces (a contact in the last 30 days not yet reviewed).
            'can_review' => $request->user()?->customer?->reviewableLeadFor($this->id) !== null,
        ];
    }
}

<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Customer\UpdateCustomerLocationRequest;
use App\Http\Responses\ApiResponse;
use App\Models\Zone;
use App\Services\ZoneMatcher;
use Illuminate\Http\JsonResponse;

/**
 * A customer's own record (SPEC section 4.2, task 4.6) — currently just
 * the location-detection endpoint the home screen header uses.
 */
class CustomerController extends Controller
{
    public function __construct(private readonly ZoneMatcher $zoneMatcher)
    {
    }

    /**
     * Resolves and persists the customer's location in one call — GPS
     * point or pincode fallback, whichever the app submits. A pincode
     * that matches no zone is still saved (SPEC: "captured for expansion
     * planning"), so this never rejects on a failed match, only on a
     * malformed/empty payload (UpdateCustomerLocationRequest).
     */
    public function updateLocation(UpdateCustomerLocationRequest $request): JsonResponse
    {
        $customer = $request->user()->customer;

        if ($customer === null) {
            return ApiResponse::error('NOT_FOUND', 'No customer profile exists for this account.', 404);
        }

        // A picked zone wins, then a point, then a pincode — see
        // ZoneMatcher::resolve().
        $zone = $this->zoneMatcher->resolve(
            $request->zoneId(),
            $request->latitude(),
            $request->longitude(),
            $request->pincode(),
        );

        $changes = [];

        if ($request->hasPoint()) {
            $changes['latitude'] = $request->latitude();
            $changes['longitude'] = $request->longitude();
        }

        if ($request->filled('pincode')) {
            $changes['pincode'] = $request->pincode();
        }

        // The zone picked from the list (zone mode), kept only when it is
        // one a customer can actually be in; a GPS or pincode report
        // leaves the last pick alone.
        if ($request->filled('zone_id')) {
            $changes['zone_id'] = $zone?->id;
        }

        $customer->fill($changes)->save();

        return ApiResponse::success([
            'customer' => [
                'latitude' => $customer->latitude,
                'longitude' => $customer->longitude,
                'pincode' => $customer->pincode,
                'zone_id' => $customer->zone_id,
            ],
            'zone' => $zone === null ? null : $this->zoneResource($zone),
        ]);
    }

    /**
     * @return array<string, mixed>
     */
    private function zoneResource(Zone $zone): array
    {
        return ['id' => $zone->id, 'name' => $zone->name];
    }
}

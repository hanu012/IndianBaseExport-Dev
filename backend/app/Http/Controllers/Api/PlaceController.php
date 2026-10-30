<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Customer\PlaceAutocompleteRequest;
use App\Http\Requests\Customer\PlaceDetailsRequest;
use App\Http\Responses\ApiResponse;
use App\Services\PlaceLookupService;
use Illuminate\Http\JsonResponse;

/**
 * Location search for the customer app's address screens, proxied so the
 * Places key stays on the server (as the ehhs apps do it). Signed-in
 * customers only and throttled — see the 'places' limiter.
 */
class PlaceController extends Controller
{
    public function __construct(private readonly PlaceLookupService $places)
    {
    }

    /**
     * GET places/autocomplete?q=&session= → [{id, main, secondary, label}].
     * An empty list when no key is set, so the app falls back to the
     * phone's own geocoder.
     */
    public function autocomplete(PlaceAutocompleteRequest $request): JsonResponse
    {
        $predictions = $this->places->autocomplete(
            $request->validated('q'),
            $request->validated('session'),
        );

        if ($predictions === null) {
            return ApiResponse::error('PLACES_UNAVAILABLE', 'Place search is unavailable right now.', 503);
        }

        return ApiResponse::success($predictions);
    }

    /**
     * GET places/details?place_id=&session= → {label, lat, lng, viewport}.
     */
    public function details(PlaceDetailsRequest $request): JsonResponse
    {
        $place = $this->places->details(
            $request->validated('place_id'),
            $request->validated('session'),
        );

        if ($place === null) {
            return ApiResponse::error('PLACE_NOT_FOUND', 'Could not look that place up.', 503);
        }

        return ApiResponse::success($place);
    }
}

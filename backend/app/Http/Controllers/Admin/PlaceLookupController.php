<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Services\PlaceLookupService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Server-side proxy for Google Places, used by the zone map's search box.
 * The Google calls live in PlaceLookupService, shared with the customer
 * app's location search (Api\PlaceController).
 *
 * Admin-only (see the route's middleware). Without that this would be an
 * open, unmetered geocoding service running on someone else's bill.
 *
 * Answers in the zone map's own shape ({predictions|place, error}), not
 * the API envelope — the map's JavaScript reads it directly.
 */
class PlaceLookupController extends Controller
{
    public function __construct(private readonly PlaceLookupService $places)
    {
    }

    /**
     * Predictions for what the admin has typed so far.
     */
    public function autocomplete(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'q' => ['required', 'string', 'min:2', 'max:200'],
            'session' => ['nullable', 'string', 'max:64'],
        ]);

        $predictions = $this->places->autocomplete($validated['q'], $validated['session'] ?? null);

        if ($predictions === null) {
            return $this->unavailable('Place search is unavailable right now.');
        }

        return response()->json(['predictions' => $predictions, 'error' => null]);
    }

    /**
     * The coordinates and viewport behind one prediction.
     */
    public function details(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'place_id' => ['required', 'string', 'max:255'],
            'session' => ['nullable', 'string', 'max:64'],
        ]);

        if (! $this->places->isConfigured()) {
            return $this->unavailable('Place lookup is not configured.');
        }

        $place = $this->places->details($validated['place_id'], $validated['session'] ?? null);

        if ($place === null) {
            return $this->unavailable('Could not look that place up.');
        }

        return response()->json(['place' => $place, 'error' => null]);
    }

    private function unavailable(string $message): JsonResponse
    {
        return response()->json(['predictions' => [], 'place' => null, 'error' => $message], 200);
    }
}

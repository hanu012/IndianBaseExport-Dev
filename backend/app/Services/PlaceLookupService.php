<?php

namespace App\Services;

use App\Support\MapKeys;
use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Google Places lookups, server-side, for the admin zone map and the
 * customer app's location search.
 *
 * The key never leaves the server. A Places key is billable and one that
 * ships inside a page or an app is one anybody can lift and spend — so the
 * clients ask us, and we ask Google.
 *
 * Two steps, because that is how Google bills it: autocomplete returns
 * predictions with no coordinates, and only the prediction the user
 * actually picks costs a Details lookup. Resolving every prediction up
 * front would multiply the bill by the length of the list.
 *
 * PLACES API (NEW). The legacy maps/api/place/* endpoints cannot be
 * enabled on Google Cloud projects created since March 2025, so a fresh
 * key gets nothing from them. The key needs "Places API (New)" enabled.
 */
class PlaceLookupService
{
    private const AUTOCOMPLETE_URL = 'https://places.googleapis.com/v1/places:autocomplete';

    private const DETAILS_URL = 'https://places.googleapis.com/v1/places/';

    /** Billed by field: geometry and the name are all the clients use. */
    private const DETAILS_FIELDS = 'id,displayName,formattedAddress,location,viewport';

    private const TIMEOUT_SECONDS = 8;

    /** Settings → Maps, else .env — see MapKeys. */
    public function isConfigured(): bool
    {
        return MapKeys::placesKey() !== null;
    }

    /**
     * Predictions for what the user has typed so far: id, main, secondary,
     * label. Empty without a key; null when Google refused or failed.
     *
     * @return list<array{id: string, main: string, secondary: string, label: string}>|null
     */
    public function autocomplete(string $query, ?string $session = null): ?array
    {
        $key = MapKeys::placesKey();

        if ($key === null) {
            return [];
        }

        $payload = ['input' => $query];

        // Groups a typing session into one billable autocomplete rather
        // than one per keystroke. Supplied by the client.
        if (filled($session)) {
            $payload['sessionToken'] = $session;
        }

        if (filled(config('map.geocode_country'))) {
            $payload['includedRegionCodes'] = [strtolower((string) config('map.geocode_country'))];
        }

        $response = Http::timeout(self::TIMEOUT_SECONDS)
            ->withHeaders(['X-Goog-Api-Key' => $key])
            ->post(self::AUTOCOMPLETE_URL, $payload);

        if ($response->failed()) {
            $this->logFailure('Places autocomplete failed', $response);

            return null;
        }

        return collect($response->json('suggestions') ?? [])
            // Query predictions ("pizza near me") carry no place to go to.
            ->pluck('placePrediction')
            ->filter()
            ->map(fn (array $prediction) => [
                'id' => $prediction['placeId'] ?? null,
                'main' => $prediction['structuredFormat']['mainText']['text']
                    ?? $prediction['text']['text']
                    ?? '',
                'secondary' => $prediction['structuredFormat']['secondaryText']['text'] ?? '',
                'label' => $prediction['text']['text'] ?? '',
            ])
            ->filter(fn (array $prediction) => filled($prediction['id']))
            ->values()
            ->all();
    }

    /**
     * The coordinates behind one prediction, plus the viewport Google
     * suggests for it — so selecting a suburb frames the suburb rather
     * than dropping a fixed zoom on its centre point. Null when there is
     * no key, Google failed, or the place has no coordinates.
     *
     * @return array{label: string, lat: float, lng: float, viewport: array{south: float, west: float, north: float, east: float}|null}|null
     */
    public function details(string $placeId, ?string $session = null): ?array
    {
        $key = MapKeys::placesKey();

        if ($key === null) {
            return null;
        }

        $query = [];

        if (filled($session)) {
            $query['sessionToken'] = $session;
        }

        // rawurlencode: the id is a path segment here, not a query value.
        $response = Http::timeout(self::TIMEOUT_SECONDS)
            ->withHeaders([
                'X-Goog-Api-Key' => $key,
                'X-Goog-FieldMask' => self::DETAILS_FIELDS,
            ])
            ->get(self::DETAILS_URL.rawurlencode($placeId), $query);

        if ($response->failed()) {
            $this->logFailure('Place details failed', $response);

            return null;
        }

        $body = $response->json();
        $location = $body['location'] ?? null;

        if (! isset($location['latitude'], $location['longitude'])) {
            return null;
        }

        return [
            'label' => $body['formattedAddress']
                ?? $body['displayName']['text']
                ?? '',
            'lat' => (float) $location['latitude'],
            'lng' => (float) $location['longitude'],
            'viewport' => $this->viewport($body['viewport'] ?? null),
        ];
    }

    /**
     * Logged rather than shown: Google's message can name the key and the
     * reason it was refused ("Places API (New) has not been used in
     * project …"), which is for whoever reads the logs, not the client.
     */
    private function logFailure(string $message, Response $response): void
    {
        Log::warning($message, [
            'status' => $response->status(),
            'reason' => $response->json('error.status'),
            'message' => $response->json('error.message'),
        ]);
    }

    /**
     * Google's {low, high} corners as south/west/north/east.
     *
     * @return array{south: float, west: float, north: float, east: float}|null
     */
    private function viewport(?array $viewport): ?array
    {
        if (! isset(
            $viewport['low']['latitude'],
            $viewport['low']['longitude'],
            $viewport['high']['latitude'],
            $viewport['high']['longitude'],
        )) {
            return null;
        }

        return [
            'south' => (float) $viewport['low']['latitude'],
            'west' => (float) $viewport['low']['longitude'],
            'north' => (float) $viewport['high']['latitude'],
            'east' => (float) $viewport['high']['longitude'],
        ];
    }
}

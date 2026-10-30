<?php

namespace Tests\Feature\Api;

use App\Enums\UserRole;
use App\Models\Customer;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * The customer app's location search (Api\PlaceController) against Google
 * Places API (New), faked — no network, no key spent.
 */
class PlaceSearchEndpointTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        config()->set('map.google_api_key', 'server-places-key');
        config()->set('map.geocode_country', 'in');
    }

    private function customer(): User
    {
        $user = User::factory()->role(UserRole::Customer)->create(['must_change_password' => false]);
        Customer::create(['user_id' => $user->id]);

        return $user;
    }

    public function test_autocomplete_returns_predictions_in_the_envelope(): void
    {
        Http::fake([
            'places.googleapis.com/v1/places:autocomplete' => Http::response([
                'suggestions' => [
                    ['placePrediction' => [
                        'placeId' => 'ChIJpal',
                        'text' => ['text' => 'Palanpur, Gujarat, India'],
                        'structuredFormat' => [
                            'mainText' => ['text' => 'Palanpur'],
                            'secondaryText' => ['text' => 'Gujarat, India'],
                        ],
                    ]],
                    ['queryPrediction' => ['text' => ['text' => 'palanpur near me']]],
                ],
            ]),
        ]);

        $this->actingAs($this->customer(), 'sanctum')
            ->getJson('/api/places/autocomplete?q=palanpur&session=tok-1')
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', 'ChIJpal')
            ->assertJsonPath('data.0.main', 'Palanpur')
            ->assertJsonPath('data.0.secondary', 'Gujarat, India');

        // The key goes in a header, never to the app; the session groups billing.
        Http::assertSent(fn (Request $request) => $request->header('X-Goog-Api-Key')[0] === 'server-places-key'
            && $request['sessionToken'] === 'tok-1'
            && $request['includedRegionCodes'] === ['in']);
    }

    public function test_details_returns_the_point(): void
    {
        Http::fake([
            'places.googleapis.com/v1/places/*' => Http::response([
                'formattedAddress' => 'Palanpur, Gujarat 385001, India',
                'location' => ['latitude' => 24.1725, 'longitude' => 72.4381],
            ]),
        ]);

        $this->actingAs($this->customer(), 'sanctum')
            ->getJson('/api/places/details?place_id=ChIJpal')
            ->assertOk()
            ->assertJsonPath('data.label', 'Palanpur, Gujarat 385001, India')
            ->assertJsonPath('data.lat', 24.1725)
            ->assertJsonPath('data.lng', 72.4381);
    }

    public function test_a_google_error_is_an_envelope_error_without_its_message(): void
    {
        Http::fake([
            'places.googleapis.com/*' => Http::response([
                'error' => ['status' => 'PERMISSION_DENIED', 'message' => 'Places API (New) has not been used in project 123'],
            ], 403),
        ]);

        $this->actingAs($this->customer(), 'sanctum')
            ->getJson('/api/places/autocomplete?q=palanpur')
            ->assertStatus(503)
            ->assertJsonPath('success', false)
            ->assertJsonPath('error.code', 'PLACES_UNAVAILABLE')
            ->assertJsonMissing(['message' => 'Places API (New) has not been used in project 123']);
    }

    public function test_without_a_key_autocomplete_is_empty_so_the_app_falls_back(): void
    {
        config()->set('map.google_api_key', null);
        Http::fake();

        $this->actingAs($this->customer(), 'sanctum')
            ->getJson('/api/places/autocomplete?q=palanpur')
            ->assertOk()
            ->assertJsonPath('data', []);

        Http::assertNothingSent();
    }

    public function test_only_signed_in_customers_can_search(): void
    {
        $this->getJson('/api/places/autocomplete?q=palanpur')->assertUnauthorized();

        $vendor = User::factory()->role(UserRole::Vendor)->create(['must_change_password' => false]);

        $this->actingAs($vendor, 'sanctum')
            ->getJson('/api/places/autocomplete?q=palanpur')
            ->assertForbidden();
    }

    public function test_a_one_letter_query_is_refused(): void
    {
        $this->actingAs($this->customer(), 'sanctum')
            ->getJson('/api/places/autocomplete?q=p')
            ->assertUnprocessable();
    }
}

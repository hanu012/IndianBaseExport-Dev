<?php

namespace Tests\Feature\Api;

use App\Enums\UserRole;
use App\Models\Category;
use App\Models\Customer;
use App\Models\Lead;
use App\Models\Setting;
use App\Models\Subcategory;
use App\Models\User;
use App\Models\Vendor;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Tests\TestCase;

/**
 * POST /api/vendors/me/calls — incoming calls the vendor app saw ring,
 * paired with the customer's call lead (CallOutcomeMatcher).
 */
class VendorCallOutcomeTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->travelTo(Carbon::parse('2026-10-29 10:00:00'));
    }

    /**
     * @return array{0: User, 1: Vendor}
     */
    private function vendorWithUser(): array
    {
        $user = User::factory()->role(UserRole::Vendor)->create(['must_change_password' => false]);
        $vendor = Vendor::create([
            'user_id' => $user->id,
            'business_name' => 'Cool Air Services',
            'owner_name' => 'Asha Patel',
            'phone' => (string) fake()->unique()->numberBetween(9000000000, 9999999999),
            'status' => 'active',
        ]);

        return [$user, $vendor];
    }

    private function callLeadAt(Vendor $vendor, string $time, string $channel = 'call'): Lead
    {
        $customerUser = User::factory()->role(UserRole::Customer)->create(['must_change_password' => false]);
        $customer = Customer::create(['user_id' => $customerUser->id]);
        $subcategory = Subcategory::factory()->for(Category::factory()->create())->create();

        $lead = Lead::create([
            'customer_id' => $customer->id,
            'vendor_id' => $vendor->id,
            'subcategory_id' => $subcategory->id,
            'channel' => $channel,
        ]);
        $lead->forceFill(['created_at' => Carbon::parse($time), 'updated_at' => Carbon::parse($time)])->save();

        return $lead->fresh();
    }

    /**
     * @param  array<int, array<string, mixed>>  $calls
     */
    private function report(User $user, array $calls, string $deviceTime = '2026-10-29 10:00:00')
    {
        return $this->actingAs($user, 'sanctum')->postJson('/api/vendors/me/calls', [
            'device_time' => Carbon::parse($deviceTime)->toIso8601String(),
            'calls' => $calls,
        ]);
    }

    public function test_an_answered_call_marks_the_lead_with_its_talk_time(): void
    {
        [$user, $vendor] = $this->vendorWithUser();
        $lead = $this->callLeadAt($vendor, '2026-10-29 09:50:00');

        $this->report($user, [
            ['rang_at' => '2026-10-29T09:50:20+00:00', 'answered' => true, 'talk_seconds' => 125],
        ])->assertOk()->assertJsonPath('data.matched', 1);

        $lead->refresh();
        $this->assertSame(Lead::OUTCOME_ANSWERED, $lead->call_outcome);
        $this->assertSame(125, $lead->call_talk_seconds);
    }

    public function test_a_ring_nobody_answered_marks_the_lead_not_answered(): void
    {
        [$user, $vendor] = $this->vendorWithUser();
        $lead = $this->callLeadAt($vendor, '2026-10-29 09:50:00');

        $this->report($user, [
            ['rang_at' => '2026-10-29T09:50:20+00:00', 'answered' => false, 'talk_seconds' => null],
        ])->assertOk();

        $lead->refresh();
        $this->assertSame(Lead::OUTCOME_NOT_ANSWERED, $lead->call_outcome);
        $this->assertNull($lead->call_talk_seconds);
    }

    public function test_a_call_with_no_lead_just_before_it_is_dropped(): void
    {
        [$user, $vendor] = $this->vendorWithUser();
        // Tapped ten minutes before the ring — not this call.
        $lead = $this->callLeadAt($vendor, '2026-10-29 09:40:00');

        $this->report($user, [
            ['rang_at' => '2026-10-29T09:50:00+00:00', 'answered' => true, 'talk_seconds' => 60],
        ])->assertOk()->assertJsonPath('data.matched', 0);

        $this->assertNull($lead->fresh()->call_outcome);
    }

    public function test_whatsapp_leads_and_other_vendors_leads_are_never_paired(): void
    {
        [$user, $vendor] = $this->vendorWithUser();
        [, $otherVendor] = $this->vendorWithUser();
        $whatsapp = $this->callLeadAt($vendor, '2026-10-29 09:50:00', 'whatsapp');
        $someoneElse = $this->callLeadAt($otherVendor, '2026-10-29 09:50:00');

        $this->report($user, [
            ['rang_at' => '2026-10-29T09:50:20+00:00', 'answered' => true, 'talk_seconds' => 60],
        ])->assertOk()->assertJsonPath('data.matched', 0);

        $this->assertNull($whatsapp->fresh()->call_outcome);
        $this->assertNull($someoneElse->fresh()->call_outcome);
    }

    public function test_two_calls_each_take_the_lead_tapped_just_before_them(): void
    {
        [$user, $vendor] = $this->vendorWithUser();
        $first = $this->callLeadAt($vendor, '2026-10-29 09:50:00');
        $second = $this->callLeadAt($vendor, '2026-10-29 09:51:00');

        $this->report($user, [
            ['rang_at' => '2026-10-29T09:51:15+00:00', 'answered' => true, 'talk_seconds' => 40],
            ['rang_at' => '2026-10-29T09:50:10+00:00', 'answered' => false],
        ])->assertOk()->assertJsonPath('data.matched', 2);

        $this->assertSame(Lead::OUTCOME_NOT_ANSWERED, $first->fresh()->call_outcome);
        $this->assertSame(Lead::OUTCOME_ANSWERED, $second->fresh()->call_outcome);
    }

    public function test_a_phone_clock_that_is_wrong_is_corrected(): void
    {
        [$user, $vendor] = $this->vendorWithUser();
        $lead = $this->callLeadAt($vendor, '2026-10-29 09:50:00');

        // The phone runs 10 minutes fast: its 10:00:20 ring was 09:50:20.
        $this->report($user, [
            ['rang_at' => '2026-10-29T10:00:20+00:00', 'answered' => true, 'talk_seconds' => 30],
        ], deviceTime: '2026-10-29 10:10:00')->assertOk()->assertJsonPath('data.matched', 1);

        $this->assertSame(Lead::OUTCOME_ANSWERED, $lead->fresh()->call_outcome);
    }

    public function test_an_already_confirmed_lead_is_not_overwritten(): void
    {
        [$user, $vendor] = $this->vendorWithUser();
        $lead = $this->callLeadAt($vendor, '2026-10-29 09:50:00');
        $lead->recordCallOutcome(true, 90);

        $this->report($user, [
            ['rang_at' => '2026-10-29T09:50:30+00:00', 'answered' => false],
        ])->assertOk()->assertJsonPath('data.matched', 0);

        $this->assertSame(90, $lead->fresh()->call_talk_seconds);
    }

    public function test_with_the_admin_switch_off_calls_are_ignored(): void
    {
        Setting::query()->where('key', 'call_answer_detection_enabled')->update(['value' => 'false']);
        [$user, $vendor] = $this->vendorWithUser();
        $lead = $this->callLeadAt($vendor, '2026-10-29 09:50:00');

        $this->report($user, [
            ['rang_at' => '2026-10-29T09:50:20+00:00', 'answered' => true, 'talk_seconds' => 60],
        ])->assertOk()->assertJsonPath('data.enabled', false);

        $this->assertNull($lead->fresh()->call_outcome);
    }

    public function test_the_outcome_shows_on_the_vendors_leads(): void
    {
        [$user, $vendor] = $this->vendorWithUser();
        $lead = $this->callLeadAt($vendor, '2026-10-29 09:50:00');
        $lead->recordCallOutcome(true, 75);

        $this->actingAs($user, 'sanctum')
            ->getJson('/api/vendors/me/leads')
            ->assertOk()
            ->assertJsonPath('data.0.call_outcome', 'answered')
            ->assertJsonPath('data.0.call_talk_seconds', 75);
    }

    public function test_a_customer_cannot_report_calls(): void
    {
        $customer = User::factory()->role(UserRole::Customer)->create(['must_change_password' => false]);

        $this->actingAs($customer, 'sanctum')
            ->postJson('/api/vendors/me/calls', [
                'device_time' => now()->toIso8601String(),
                'calls' => [['rang_at' => now()->toIso8601String(), 'answered' => true]],
            ])
            ->assertForbidden();
    }
}

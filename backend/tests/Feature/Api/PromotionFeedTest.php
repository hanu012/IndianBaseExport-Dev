<?php

namespace Tests\Feature\Api;

use App\Enums\UserRole;
use App\Models\Category;
use App\Models\Customer;
use App\Models\Media;
use App\Models\Payment;
use App\Models\Plan;
use App\Models\PlanQuota;
use App\Models\Promotion;
use App\Models\PromotionPackage;
use App\Models\Subcategory;
use App\Models\Subscription;
use App\Models\SubscriptionItem;
use App\Models\User;
use App\Models\Vendor;
use App\Models\Zone;
use App\Services\PromotionService;
use Database\Factories\ZoneFactory;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * Paid promotions and the customer Feed (decided 2026-10-31): buying a
 * promotion, the Feed's order (paid promotions for the zone first, then
 * portfolio posts of vendors serving it), likes, comments, reports, calls
 * from an ad and the daily expiry.
 */
class PromotionFeedTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        Storage::fake('public');
        config()->set('filesystems.default', 'public');
        config()->set('filament.default_filesystem_disk', 'public');
    }

    // ── Helpers ─────────────────────────────────────────────────────────

    private function zoneAt(float $lat, float $lng): Zone
    {
        return Zone::factory()->active()->withBoundary(ZoneFactory::square($lat, $lng))->create();
    }

    /** An active vendor whose live subscription covers $zones and one service. */
    private function vendorIn(array $zones): Vendor
    {
        $user = User::factory()->role(UserRole::Vendor)->create(['must_change_password' => false]);
        $vendor = Vendor::create([
            'user_id' => $user->id,
            'business_name' => 'Cool Air '.fake()->unique()->numberBetween(1, 999999),
            'owner_name' => 'Asha Patel',
            'phone' => (string) fake()->unique()->numberBetween(9000000000, 9999999999),
            'status' => 'active',
        ]);
        $user->forceFill(['approval_status' => 'approved'])->save();

        $plan = Plan::factory()->create();
        PlanQuota::where('plan_id', $plan->id)->update(['priority_rank' => 1]);
        $subscription = Subscription::create([
            'vendor_id' => $vendor->id,
            'plan_id' => $plan->id,
            'source' => 'self',
            'status' => 'active',
            'start_date' => now(),
            'end_date' => now()->addDays(300),
            'price_paise' => $plan->price_paise,
            'duration_days' => $plan->duration_days,
            'idempotency_key' => (string) Str::uuid(),
        ]);

        $subcategory = Subcategory::factory()->for(Category::factory()->create())->create();
        SubscriptionItem::create(['subscription_id' => $subscription->id, 'item_type' => 'subcategory', 'item_id' => $subcategory->id]);

        foreach ($zones as $zone) {
            SubscriptionItem::create(['subscription_id' => $subscription->id, 'item_type' => 'zone', 'item_id' => $zone->id]);
        }

        return $vendor;
    }

    private function package(array $overrides = []): PromotionPackage
    {
        return PromotionPackage::create(array_merge([
            'name' => '7-Day Premium Reach',
            'duration_days' => 7,
            'price_paise' => 99_900,
            'max_zones' => 2,
            'allows_video' => false,
        ], $overrides));
    }

    private function customer(): array
    {
        $user = User::factory()->role(UserRole::Customer)->create(['must_change_password' => false]);
        $user->forceFill(['approval_status' => 'approved'])->save();

        return [$user, Customer::create(['user_id' => $user->id])];
    }

    private function buy(Vendor $vendor, PromotionPackage $package, array $zoneIds, array $overrides = [], ?string $key = null)
    {
        return $this->actingAs($vendor->user, 'sanctum')->post('/api/vendors/me/promotions', array_merge([
            'promotion_package_id' => $package->id,
            'media_type' => 'image',
            'file' => UploadedFile::fake()->image('offer.jpg', 800, 600),
            'caption' => '20% off AC service this weekend!',
            'zone_ids' => $zoneIds,
        ], $overrides), ['Accept' => 'application/json', 'Idempotency-Key' => $key ?? (string) Str::uuid()]);
    }

    private function livePromotion(Vendor $vendor, Zone $zone, array $overrides = []): Promotion
    {
        $promotion = Promotion::create(array_merge([
            'vendor_id' => $vendor->id,
            'promotion_package_id' => $this->package()->id,
            'caption' => 'Sponsored offer',
            'media_type' => 'image',
            'media_path' => 'vendor-promotions/x.jpg',
            'price_paise' => 99_900,
            'duration_days' => 7,
            'status' => Promotion::STATUS_LIVE,
            'starts_at' => now()->subDay(),
            'ends_at' => now()->addDays(6),
            'idempotency_key' => (string) Str::uuid(),
        ], $overrides));
        $promotion->zones()->sync([$zone->id]);

        return $promotion;
    }

    private function portfolioPost(Vendor $vendor, array $overrides = []): Media
    {
        return $vendor->media()->create(array_merge([
            'disk' => 'public',
            'path' => 'vendor-portfolio/p.jpg',
            'type' => 'image',
            'moderation_status' => 'approved',
        ], $overrides));
    }

    private function feed(User $customer, Zone $zone)
    {
        return $this->actingAs($customer, 'sanctum')->getJson('/api/feed?zone_id='.$zone->id);
    }

    // ── Buying ──────────────────────────────────────────────────────────

    public function test_a_vendor_buys_a_promotion_and_it_goes_live_with_payment_links_off(): void
    {
        $zone = $this->zoneAt(-33.0, -70.0);
        $vendor = $this->vendorIn([$zone]);
        $package = $this->package();

        $this->buy($vendor, $package, [$zone->id])
            ->assertCreated()
            ->assertJsonPath('data.status', 'live')
            ->assertJsonPath('data.is_showing', true)
            ->assertJsonPath('data.price_paise', 99_900)
            ->assertJsonPath('data.zones.0.id', $zone->id);

        $promotion = Promotion::firstOrFail();
        $this->assertTrue($promotion->ends_at->between(now()->addDays(7)->subMinute(), now()->addDays(7)->addMinute()));

        $payment = Payment::where('promotion_id', $promotion->id)->firstOrFail();
        $this->assertNull($payment->subscription_id);
        $this->assertSame('captured', $payment->status);
        $this->assertSame(99_900, $payment->amount_paise);
        Storage::disk('public')->assertExists($promotion->media_path);
    }

    public function test_the_same_idempotency_key_never_buys_twice(): void
    {
        $zone = $this->zoneAt(-33.0, -70.0);
        $vendor = $this->vendorIn([$zone]);
        $package = $this->package();
        $key = (string) Str::uuid();

        $first = $this->buy($vendor, $package, [$zone->id], key: $key)->assertCreated()->json('data.id');
        $second = $this->buy($vendor, $package, [$zone->id], key: $key)->assertOk()->json('data.id');

        $this->assertSame($first, $second);
        $this->assertSame(1, Promotion::count());
        $this->assertSame(1, Payment::count());
    }

    public function test_a_vendor_can_only_promote_in_their_own_zones_and_within_the_package(): void
    {
        $mine = $this->zoneAt(-33.0, -70.0);
        $other = $this->zoneAt(-34.0, -71.0);
        $vendor = $this->vendorIn([$mine]);

        $this->buy($vendor, $this->package(), [$other->id])->assertStatus(422);
        $this->buy($vendor, $this->package(), [$mine->id], [
            'media_type' => 'video',
            'file' => UploadedFile::fake()->create('clip.mp4', 500, 'video/mp4'),
        ])->assertStatus(422);
        $this->buy($vendor, $this->package(['is_active' => false]), [$mine->id])->assertStatus(422);

        $this->assertSame(0, Promotion::count());
    }

    public function test_a_razorpay_payment_holds_the_promotion_until_the_webhook_pays_it(): void
    {
        $zone = $this->zoneAt(-33.0, -70.0);
        $vendor = $this->vendorIn([$zone]);
        $promotion = $this->livePromotion($vendor, $zone, ['status' => Promotion::STATUS_PENDING_PAYMENT, 'starts_at' => null, 'ends_at' => null]);
        $payment = Payment::create([
            'promotion_id' => $promotion->id,
            'amount_paise' => 99_900,
            'mode' => 'online',
            'gateway' => 'razorpay',
            'gateway_order_id' => 'plink_1',
            'status' => 'pending',
        ]);

        [$customer] = $this->customer();
        $this->feed($customer, $zone)->assertJsonCount(0, 'data.items');

        app(PromotionService::class)->completeOnlinePayment($payment, 'pay_1');
        // A repeated webhook changes nothing.
        app(PromotionService::class)->completeOnlinePayment($payment, 'pay_1');

        $promotion->refresh();
        $this->assertSame(Promotion::STATUS_LIVE, $promotion->status);
        $this->assertSame('captured', $payment->fresh()->status);
        $this->feed($customer, $zone)->assertJsonPath('data.items.0.type', 'promotion');
    }

    public function test_an_unpaid_promotion_can_be_withdrawn_but_a_live_one_cannot(): void
    {
        $zone = $this->zoneAt(-33.0, -70.0);
        $vendor = $this->vendorIn([$zone]);
        $pending = $this->livePromotion($vendor, $zone, ['status' => Promotion::STATUS_PENDING_PAYMENT]);
        $live = $this->livePromotion($vendor, $zone);

        $this->actingAs($vendor->user, 'sanctum')->deleteJson("/api/vendors/me/promotions/{$pending->id}")
            ->assertOk()->assertJsonPath('data.status', 'cancelled');
        $this->actingAs($vendor->user, 'sanctum')->deleteJson("/api/vendors/me/promotions/{$live->id}")
            ->assertStatus(422);
    }

    // ── Feed ────────────────────────────────────────────────────────────

    public function test_the_feed_shows_paid_promotions_first_then_posts_of_vendors_serving_the_zone(): void
    {
        $zone = $this->zoneAt(-33.0, -70.0);
        $elsewhere = $this->zoneAt(-34.0, -71.0);
        $here = $this->vendorIn([$zone]);
        $there = $this->vendorIn([$elsewhere]);

        $post = $this->portfolioPost($here);
        $promotion = $this->livePromotion($here, $zone);

        // Left out: another zone's post and promotion, an unapproved post,
        // an expired promotion and a hidden one.
        $this->portfolioPost($there);
        $this->livePromotion($there, $elsewhere);
        $this->portfolioPost($here, ['moderation_status' => 'pending']);
        $this->livePromotion($here, $zone, ['ends_at' => now()->subMinute()]);
        $hidden = $this->livePromotion($here, $zone);
        $hidden->forceFill(['is_hidden' => true])->save();

        [$customer] = $this->customer();

        $this->feed($customer, $zone)
            ->assertOk()
            ->assertJsonCount(2, 'data.items')
            ->assertJsonPath('data.items.0.type', 'promotion')
            ->assertJsonPath('data.items.0.id', $promotion->id)
            ->assertJsonPath('data.items.0.sponsored', true)
            ->assertJsonPath('data.items.1.type', 'post')
            ->assertJsonPath('data.items.1.id', $post->id)
            ->assertJsonPath('meta.promotions', 1);

        // Being shown counts as a view.
        $this->assertSame(1, $promotion->fresh()->views_count);
    }

    public function test_a_vendor_without_a_live_subscription_has_no_posts_in_the_feed(): void
    {
        $zone = $this->zoneAt(-33.0, -70.0);
        $vendor = $this->vendorIn([$zone]);
        $this->portfolioPost($vendor);
        Subscription::where('vendor_id', $vendor->id)->update(['end_date' => now()->subDays(30), 'status' => 'expired']);

        [$customer] = $this->customer();

        $this->feed($customer, $zone)->assertJsonCount(0, 'data.items');
    }

    public function test_the_feed_pages_from_promotions_into_posts(): void
    {
        $zone = $this->zoneAt(-33.0, -70.0);
        $vendor = $this->vendorIn([$zone]);
        $this->livePromotion($vendor, $zone);
        $this->livePromotion($vendor, $zone);
        $this->portfolioPost($vendor);
        $this->portfolioPost($vendor);

        [$customer] = $this->customer();

        $page1 = $this->actingAs($customer, 'sanctum')->getJson("/api/feed?zone_id={$zone->id}&per_page=3")
            ->assertJsonPath('meta.total', 4)->assertJsonPath('meta.last_page', 2)->json('data.items.*.type');
        $page2 = $this->actingAs($customer, 'sanctum')->getJson("/api/feed?zone_id={$zone->id}&per_page=3&page=2")
            ->json('data.items.*.type');

        $this->assertSame(['promotion', 'promotion', 'post'], $page1);
        $this->assertSame(['post'], $page2);
    }

    // ── Likes, comments, reports ───────────────────────────────────────

    public function test_likes_toggle_and_show_on_the_feed(): void
    {
        $zone = $this->zoneAt(-33.0, -70.0);
        $vendor = $this->vendorIn([$zone]);
        $post = $this->portfolioPost($vendor);
        [$customer] = $this->customer();

        $this->actingAs($customer, 'sanctum')->postJson("/api/feed/post/{$post->id}/like")
            ->assertOk()->assertJsonPath('data.liked', true)->assertJsonPath('data.likes_count', 1);

        $this->feed($customer, $zone)
            ->assertJsonPath('data.items.0.liked', true)
            ->assertJsonPath('data.items.0.likes_count', 1);

        $this->actingAs($customer, 'sanctum')->postJson("/api/feed/post/{$post->id}/like")
            ->assertJsonPath('data.liked', false)->assertJsonPath('data.likes_count', 0);
    }

    public function test_comments_are_listed_reported_once_and_hidden_ones_drop_out(): void
    {
        $zone = $this->zoneAt(-33.0, -70.0);
        $vendor = $this->vendorIn([$zone]);
        $promotion = $this->livePromotion($vendor, $zone);
        [$author] = $this->customer();
        [$reader] = $this->customer();

        $commentId = $this->actingAs($author, 'sanctum')
            ->postJson("/api/feed/promotion/{$promotion->id}/comments", ['body' => 'Great offer!'])
            ->assertCreated()->assertJsonPath('data.is_mine', true)->json('data.id');

        $this->actingAs($reader, 'sanctum')->getJson("/api/feed/promotion/{$promotion->id}/comments")
            ->assertJsonCount(1, 'data')->assertJsonPath('data.0.is_mine', false);

        $this->actingAs($reader, 'sanctum')->postJson("/api/feed/comments/{$commentId}/report", ['reason' => 'Spam'])->assertCreated();
        $this->actingAs($reader, 'sanctum')->postJson("/api/feed/comments/{$commentId}/report")->assertCreated();
        $this->assertSame(1, \App\Models\FeedComment::find($commentId)->reports_count);

        // Only the author can delete it.
        $this->actingAs($reader, 'sanctum')->deleteJson("/api/feed/comments/{$commentId}")->assertForbidden();

        \App\Models\FeedComment::whereKey($commentId)->update(['is_hidden' => true]);

        $this->actingAs($reader, 'sanctum')->getJson("/api/feed/promotion/{$promotion->id}/comments")->assertJsonCount(0, 'data');
        $this->feed($reader, $zone)->assertJsonPath('data.items.0.comments_count', 0);
    }

    public function test_replies_thread_under_a_comment_and_the_vendor_answers_as_the_business(): void
    {
        $zone = $this->zoneAt(-33.0, -70.0);
        $vendor = $this->vendorIn([$zone]);
        $promotion = $this->livePromotion($vendor, $zone);
        [$customer] = $this->customer();

        $commentId = $this->actingAs($customer, 'sanctum')
            ->postJson("/api/feed/promotion/{$promotion->id}/comments", ['body' => 'price?'])
            ->json('data.id');

        // The vendor sees it on their own posts and replies as the business.
        $this->actingAs($vendor->user, 'sanctum')->getJson('/api/vendors/me/feed-comments')
            ->assertJsonPath('data.0.id', $commentId)
            ->assertJsonPath('data.0.post.type', 'promotion');

        $replyId = $this->actingAs($vendor->user, 'sanctum')
            ->postJson("/api/vendors/me/feed-comments/{$commentId}/reply", ['body' => '@Arun Starts at 499'])
            ->assertCreated()
            ->assertJsonPath('data.is_business', true)
            ->assertJsonPath('data.parent_id', $commentId)
            ->json('data.id');

        // A customer reply to that reply joins the same thread.
        $this->actingAs($customer, 'sanctum')
            ->postJson("/api/feed/promotion/{$promotion->id}/comments", ['body' => 'Thanks!', 'parent_id' => $replyId])
            ->assertCreated()
            ->assertJsonPath('data.parent_id', $commentId);

        // Liking a comment.
        $this->actingAs($customer, 'sanctum')->postJson("/api/feed/comments/{$replyId}/like")
            ->assertJsonPath('data.liked', true)->assertJsonPath('data.likes_count', 1);

        $this->actingAs($customer, 'sanctum')->getJson("/api/feed/promotion/{$promotion->id}/comments")
            ->assertJsonCount(1, 'data')
            ->assertJsonCount(2, 'data.0.replies')
            ->assertJsonPath('data.0.replies.0.author_name', $vendor->business_name)
            ->assertJsonPath('data.0.replies.0.is_business', true)
            ->assertJsonPath('data.0.replies.0.liked', true)
            ->assertJsonPath('data.0.replies.0.likes_count', 1);
    }

    public function test_a_vendor_cannot_reply_on_someone_elses_post(): void
    {
        $zone = $this->zoneAt(-33.0, -70.0);
        $promotion = $this->livePromotion($this->vendorIn([$zone]), $zone);
        $other = $this->vendorIn([$zone]);
        [$customer] = $this->customer();

        $commentId = $this->actingAs($customer, 'sanctum')
            ->postJson("/api/feed/promotion/{$promotion->id}/comments", ['body' => 'Hi'])->json('data.id');

        $this->actingAs($other->user, 'sanctum')
            ->postJson("/api/vendors/me/feed-comments/{$commentId}/reply", ['body' => 'Try us instead'])
            ->assertNotFound();
    }

    public function test_the_offers_and_following_chips_narrow_the_feed(): void
    {
        $zone = $this->zoneAt(-33.0, -70.0);
        $liked = $this->vendorIn([$zone]);
        $other = $this->vendorIn([$zone]);
        $this->livePromotion($other, $zone);
        $this->portfolioPost($liked);
        $this->portfolioPost($other);
        [$customer, $customerRow] = $this->customer();
        $customerRow->favorites()->create(['vendor_id' => $liked->id]);

        $this->actingAs($customer, 'sanctum')->getJson("/api/feed?zone_id={$zone->id}&filter=offers")
            ->assertJsonCount(1, 'data.items')->assertJsonPath('data.items.0.type', 'promotion');

        $this->actingAs($customer, 'sanctum')->getJson("/api/feed?zone_id={$zone->id}&filter=following")
            ->assertJsonCount(1, 'data.items')
            ->assertJsonPath('data.items.0.type', 'post')
            ->assertJsonPath('data.items.0.vendor.id', $liked->id);

        $this->actingAs($customer, 'sanctum')->getJson("/api/feed?zone_id={$zone->id}")
            ->assertJsonCount(3, 'data.items')
            ->assertJsonPath('data.items.0.vendor.verified', true);

        // Nearby: the nearer vendor's post first (promotions still lead).
        $liked->update(['latitude' => -33.0, 'longitude' => -70.0]);
        $other->update(['latitude' => -33.5, 'longitude' => -70.5]);

        $this->actingAs($customer, 'sanctum')
            ->getJson('/api/feed?'.http_build_query(['latitude' => -33.0, 'longitude' => -70.0, 'filter' => 'nearby']))
            ->assertOk()
            ->assertJsonCount(3, 'data.items')
            ->assertJsonPath('data.items.0.type', 'promotion')
            ->assertJsonPath('data.items.1.vendor.id', $liked->id);
    }

    public function test_an_expired_promotion_cannot_be_liked_or_commented_on(): void
    {
        $zone = $this->zoneAt(-33.0, -70.0);
        $promotion = $this->livePromotion($this->vendorIn([$zone]), $zone, ['ends_at' => now()->subMinute()]);
        [$customer] = $this->customer();

        $this->actingAs($customer, 'sanctum')->postJson("/api/feed/promotion/{$promotion->id}/like")->assertNotFound();
        $this->actingAs($customer, 'sanctum')->postJson("/api/feed/promotion/{$promotion->id}/comments", ['body' => 'Hi'])->assertNotFound();
    }

    // ── Calls from an ad, and expiry ────────────────────────────────────

    public function test_a_call_from_a_promotion_counts_for_it_even_without_a_service(): void
    {
        $zone = $this->zoneAt(-33.0, -70.0);
        $vendor = $this->vendorIn([$zone]);
        $promotion = $this->livePromotion($vendor, $zone);
        [$customer] = $this->customer();

        $this->actingAs($customer, 'sanctum')->postJson('/api/leads', [
            'vendor_id' => $vendor->id,
            'promotion_id' => $promotion->id,
            'channel' => 'call',
        ])->assertCreated();

        $this->actingAs($vendor->user, 'sanctum')->getJson('/api/vendors/me/promotions')
            ->assertJsonPath('data.0.stats.calls', 1);
    }

    public function test_the_daily_job_ends_promotions_past_their_end(): void
    {
        $zone = $this->zoneAt(-33.0, -70.0);
        $vendor = $this->vendorIn([$zone]);
        $done = $this->livePromotion($vendor, $zone, ['ends_at' => now()->subHour()]);
        $running = $this->livePromotion($vendor, $zone);

        $this->artisan('promotions:process-expiry')->assertSuccessful();

        $this->assertSame(Promotion::STATUS_ENDED, $done->fresh()->status);
        $this->assertSame(Promotion::STATUS_LIVE, $running->fresh()->status);
    }

    // ── Text-only posts, the details screen, pause / end / extend ───────

    public function test_a_promotion_can_be_text_only_with_a_300_character_caption(): void
    {
        $zone = $this->zoneAt(-33.0, -70.0);
        $vendor = $this->vendorIn([$zone]);
        $package = $this->package();

        $this->buy($vendor, $package, [$zone->id], ['file' => null, 'media_type' => null, 'caption' => str_repeat('a', 301)])
            ->assertStatus(422);
        $this->assertSame(0, Promotion::count());

        $this->buy($vendor, $package, [$zone->id], ['file' => null, 'media_type' => null, 'caption' => str_repeat('a', 300)])
            ->assertCreated()
            ->assertJsonPath('data.media_url', null)
            ->assertJsonPath('data.status', Promotion::STATUS_LIVE);

        [$customer] = $this->customer();
        $this->feed($customer, $zone)->assertJsonPath('data.items.0.media_url', null);
    }

    public function test_pausing_stops_the_clock_and_resuming_adds_the_paused_time_back(): void
    {
        $zone = $this->zoneAt(-33.0, -70.0);
        $vendor = $this->vendorIn([$zone]);
        $promotion = $this->livePromotion($vendor, $zone);
        $endsAt = $promotion->ends_at->copy();
        [$customer] = $this->customer();

        $this->actingAs($vendor->user, 'sanctum')->postJson("/api/vendors/me/promotions/{$promotion->id}/pause")
            ->assertOk()->assertJsonPath('data.is_paused', true);
        $this->feed($customer, $zone)->assertJsonCount(0, 'data.items');

        // Paused past its old end: the daily job leaves it alone.
        $this->travel(10)->days();
        $this->artisan('promotions:process-expiry')->assertSuccessful();
        $this->assertSame(Promotion::STATUS_LIVE, $promotion->fresh()->status);

        $this->actingAs($vendor->user, 'sanctum')->postJson("/api/vendors/me/promotions/{$promotion->id}/resume")
            ->assertOk()->assertJsonPath('data.is_paused', false);

        $this->assertEqualsWithDelta($endsAt->addDays(10)->timestamp, $promotion->fresh()->ends_at->timestamp, 5);
        $this->feed($customer, $zone)->assertJsonPath('data.items.0.type', 'promotion');
    }

    public function test_ending_early_stops_it_at_once(): void
    {
        $zone = $this->zoneAt(-33.0, -70.0);
        $vendor = $this->vendorIn([$zone]);
        $promotion = $this->livePromotion($vendor, $zone);

        $this->actingAs($vendor->user, 'sanctum')->postJson("/api/vendors/me/promotions/{$promotion->id}/end")
            ->assertOk()->assertJsonPath('data.status', Promotion::STATUS_ENDED);

        $this->actingAs($vendor->user, 'sanctum')->getJson('/api/vendors/me/promotions?tab=ended')
            ->assertJsonPath('data.0.id', $promotion->id)
            ->assertJsonPath('meta.counts.live', 0)
            ->assertJsonPath('meta.counts.ended', 1);
    }

    public function test_extending_buys_the_package_again_and_adds_its_days_once(): void
    {
        $zone = $this->zoneAt(-33.0, -70.0);
        $vendor = $this->vendorIn([$zone]);
        $promotion = $this->livePromotion($vendor, $zone);
        Payment::create(['promotion_id' => $promotion->id, 'amount_paise' => 99_900, 'mode' => 'online', 'status' => 'captured']);
        $endsAt = $promotion->ends_at->copy();
        $key = (string) Str::uuid();

        foreach ([1, 2] as $attempt) {
            $this->actingAs($vendor->user, 'sanctum')
                ->postJson("/api/vendors/me/promotions/{$promotion->id}/extend", [], ['Idempotency-Key' => $key])
                ->assertOk()->assertJsonPath('data.pending_extension', null);
        }

        $this->assertEqualsWithDelta($endsAt->addDays(7)->timestamp, $promotion->fresh()->ends_at->timestamp, 5);
        $this->assertSame(1, $promotion->extensions()->count());
        // The purchase stays the promotion's own payment.
        $this->assertNull($promotion->fresh()->payment->promotion_extension_id);

        $this->actingAs($vendor->user, 'sanctum')->getJson("/api/vendors/me/promotions/{$promotion->id}")
            ->assertJsonPath('data.amount_paid_paise', 199_800);
    }

    public function test_the_details_show_comments_waiting_for_a_business_reply(): void
    {
        $zone = $this->zoneAt(-33.0, -70.0);
        $vendor = $this->vendorIn([$zone]);
        $promotion = $this->livePromotion($vendor, $zone);
        [, $customer] = $this->customer();

        $answered = $promotion->comments()->create(['customer_id' => $customer->id, 'body' => 'Price?']);
        $promotion->comments()->create(['vendor_id' => $vendor->id, 'parent_id' => $answered->id, 'body' => 'Rs 499']);
        $this->travel(1)->minutes();
        $promotion->comments()->create(['customer_id' => $customer->id, 'body' => 'Sunday open?']);

        $this->actingAs($vendor->user, 'sanctum')->getJson("/api/vendors/me/promotions/{$promotion->id}")
            ->assertOk()
            ->assertJsonPath('data.unanswered_comments', 1)
            ->assertJsonPath('data.recent_comments.0.needs_reply', true)
            ->assertJsonPath('data.recent_comments.1.needs_reply', false);

        $other = $this->vendorIn([$zone]);
        $this->actingAs($other->user, 'sanctum')->getJson("/api/vendors/me/promotions/{$promotion->id}")->assertNotFound();
    }

    public function test_edit_post_changes_the_caption_and_can_drop_the_photo(): void
    {
        $zone = $this->zoneAt(-33.0, -70.0);
        $vendor = $this->vendorIn([$zone]);
        $promotion = $this->livePromotion($vendor, $zone);

        $this->actingAs($vendor->user, 'sanctum')
            ->postJson("/api/vendors/me/promotions/{$promotion->id}/post", ['caption' => 'New text', 'remove_media' => true])
            ->assertOk()
            ->assertJsonPath('data.caption', 'New text')
            ->assertJsonPath('data.media_url', null);
    }
}

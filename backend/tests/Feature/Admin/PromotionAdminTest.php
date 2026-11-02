<?php

namespace Tests\Feature\Admin;

use App\Enums\UserRole;
use App\Filament\Resources\FeedCommentResource\Pages\ListFeedComments;
use App\Filament\Resources\PromotionPackageResource;
use App\Filament\Resources\PromotionPackageResource\Pages\CreatePromotionPackage;
use App\Filament\Resources\PromotionPackageResource\Pages\ListPromotionPackages;
use App\Filament\Resources\PromotionResource\Pages\ListPromotions;
use App\Models\Customer;
use App\Models\FeedComment;
use App\Models\Promotion;
use App\Models\PromotionPackage;
use App\Models\User;
use App\Models\Vendor;
use Filament\Facades\Filament;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Livewire\Livewire;
use Tests\TestCase;

/** The admin's Promotions group: packages, vendor promotions, feed comments. */
class PromotionAdminTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;

    protected function setUp(): void
    {
        parent::setUp();

        $this->admin = User::factory()->role(UserRole::Admin)->create(['permissions' => ['*'], 'must_change_password' => false]);
        $this->actingAs($this->admin);
        Filament::setCurrentPanel(Filament::getPanel('admin'));
    }

    private function promotion(): Promotion
    {
        $user = User::factory()->role(UserRole::Vendor)->create();
        $vendor = Vendor::create(['user_id' => $user->id, 'business_name' => 'Cool Air', 'owner_name' => 'Asha', 'phone' => '9811111111', 'status' => 'active']);

        return Promotion::create([
            'vendor_id' => $vendor->id,
            'promotion_package_id' => PromotionPackage::create(['name' => 'Weekly', 'duration_days' => 7, 'price_paise' => 49_900])->id,
            'caption' => 'Offer',
            'media_type' => 'image',
            'media_path' => 'x.jpg',
            'price_paise' => 49_900,
            'duration_days' => 7,
            'status' => Promotion::STATUS_LIVE,
            'starts_at' => now(),
            'ends_at' => now()->addDays(7),
            'idempotency_key' => (string) Str::uuid(),
        ]);
    }

    public function test_a_package_is_created_with_the_price_stored_in_paise(): void
    {
        Livewire::test(CreatePromotionPackage::class)
            ->fillForm([
                'name' => '3-Day Spotlight',
                'price_rupees' => '499.50',
                'duration_days' => 3,
                'allows_video' => true,
                'is_active' => true,
            ])
            ->call('create')
            ->assertHasNoFormErrors();

        $package = PromotionPackage::firstOrFail();
        $this->assertSame(49_950, $package->price_paise);
        $this->assertSame(3, $package->duration_days);
    }

    public function test_packages_have_no_delete(): void
    {
        $package = PromotionPackage::create(['name' => 'Weekly', 'duration_days' => 7, 'price_paise' => 100]);

        Livewire::test(ListPromotionPackages::class)
            ->assertTableActionDoesNotExist('delete')
            ->assertCanSeeTableRecords([$package]);

        $this->assertFalse($this->admin->can('delete', $package));
        $this->assertArrayNotHasKey('delete', PromotionPackageResource::getPages());
    }

    public function test_hiding_a_promotion_takes_it_out_of_the_feed(): void
    {
        $promotion = $this->promotion();

        Livewire::test(ListPromotions::class)
            ->callTableAction('hide', $promotion, ['reason' => 'Misleading offer'])
            ->assertHasNoTableActionErrors();

        $promotion->refresh();
        $this->assertTrue($promotion->is_hidden);
        $this->assertSame('Misleading offer', $promotion->hidden_reason);
        $this->assertFalse($promotion->isShowing());

        Livewire::test(ListPromotions::class)->callTableAction('unhide', $promotion);
        $this->assertTrue($promotion->fresh()->isShowing());
    }

    public function test_a_reported_comment_can_be_hidden(): void
    {
        $promotion = $this->promotion();
        $customer = Customer::create(['user_id' => User::factory()->role(UserRole::Customer)->create()->id]);
        $comment = $promotion->comments()->create(['customer_id' => $customer->id, 'body' => 'Spam!']);
        $comment->forceFill(['reports_count' => 2])->save();

        Livewire::test(ListFeedComments::class)
            ->assertCanSeeTableRecords([$comment])
            ->callTableAction('hide', $comment);

        $this->assertTrue(FeedComment::find($comment->id)->is_hidden);
    }

    public function test_a_sub_admin_without_the_moderate_permission_cannot_hide(): void
    {
        $promotion = $this->promotion();
        $subAdmin = User::factory()->role(UserRole::Admin)->create(['permissions' => ['promotions.viewAny'], 'must_change_password' => false]);
        $this->actingAs($subAdmin);

        Livewire::test(ListPromotions::class)->assertTableActionHidden('hide', $promotion);
    }
}

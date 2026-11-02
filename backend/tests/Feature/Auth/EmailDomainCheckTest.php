<?php

namespace Tests\Feature\Auth;

use App\Enums\UserRole;
use App\Filament\Resources\UserResource\Pages\CreateUser;
use App\Models\User;
use App\Rules\EmailDomainExists;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Notification;
use Livewire\Livewire;
use Tests\TestCase;

/**
 * App\Rules\EmailDomainExists (decided 2026-11-01): an email whose domain
 * cannot receive mail is refused before any account or link is made. DNS is
 * faked here — real lookups are off in tests (phpunit.xml).
 */
class EmailDomainCheckTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        config()->set('services.email_domain_check', true);
        // gmail.com receives mail; gmial.com does not; down.example = DNS could not be asked.
        EmailDomainExists::resolveUsing(fn (string $domain): ?bool => match ($domain) {
            'gmail.com' => true,
            'down.example' => null,
            default => false,
        });
        Notification::fake();
    }

    protected function tearDown(): void
    {
        EmailDomainExists::resolveUsing(null);

        parent::tearDown();
    }

    private function register(string $email): \Illuminate\Testing\TestResponse
    {
        return $this->postJson('/api/auth/register', ['name' => 'Ravi Patel', 'email' => $email, 'role' => 'customer']);
    }

    public function test_sign_up_refuses_a_domain_that_cannot_receive_email(): void
    {
        $this->register('ravi@gmial.com')->assertStatus(422);

        $this->assertDatabaseMissing('users', ['email' => 'ravi@gmial.com']);
        Notification::assertNothingSent();
    }

    public function test_sign_up_accepts_a_real_domain(): void
    {
        $this->register('ravi@gmail.com')->assertCreated();
    }

    /** An outage must not block every sign-up. */
    public function test_when_dns_cannot_be_asked_the_address_is_allowed(): void
    {
        $this->register('ravi@down.example')->assertCreated();
    }

    public function test_the_admin_users_form_refuses_a_bad_domain(): void
    {
        $this->actingAs(User::factory()->role(UserRole::Admin)->create());

        Livewire::test(CreateUser::class)
            ->fillForm([
                'name' => 'Riya Patel',
                'email' => 'riya@gmail.con',
                'role' => 'salesman',
                'salesman' => ['employee_code' => 'EMP-009', 'phone' => '9900000009', 'is_active' => true],
            ])
            ->call('create')
            ->assertHasFormErrors(['email']);

        $this->assertDatabaseMissing('users', ['email' => 'riya@gmail.con']);
    }
}

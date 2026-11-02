<x-filament-panels::page>
    @include('filament.super-admin.partials.two-factor-styles')

    <div class="tf-wrap">
        <div class="tf-card">
            <div class="tf-icon" aria-hidden="true">
                @if ($useRecovery)
                    <x-filament::icon icon="heroicon-o-key" />
                @else
                    <x-filament::icon icon="heroicon-o-shield-check" />
                @endif
            </div>

            <h2 class="tf-title">{{ $useRecovery ? 'Use a recovery code' : 'Two-step login' }}</h2>

            <p class="tf-sub">
                @if ($useRecovery)
                    Enter one of the recovery codes you saved when you set up two-step login.
                    Each code works once.
                @else
                    Open your authenticator app and enter the 6-digit code for
                    <strong>{{ auth()->user()->email }}</strong>.
                @endif
            </p>

            <form wire:submit="verify" class="tf-form">
                {{ $this->form }}

                <div class="tf-btn-full">
                    <x-filament::button type="submit" size="lg" icon="heroicon-m-arrow-right" icon-position="after">
                        Continue
                    </x-filament::button>
                </div>
            </form>

            <div class="tf-divider">or</div>

            <button type="button" class="tf-link" wire:click="toggleRecovery">
                {{ $useRecovery ? 'Use the code from my authenticator app' : 'Lost your phone? Use a recovery code' }}
            </button>

            @if ($useRecovery)
                <div class="tf-note">
                    <strong>No phone and no recovery codes?</strong>
                    Ask another super-admin to use <strong>Reset two-step login</strong> on the Admins screen,
                    or run <code>php artisan admin:reset-two-factor {{ auth()->user()->email }}</code> on the server.
                    You will then set it up again and get new codes.
                </div>
            @endif
        </div>
    </div>
</x-filament-panels::page>

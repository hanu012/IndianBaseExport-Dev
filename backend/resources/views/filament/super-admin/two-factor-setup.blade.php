<x-filament-panels::page>
    @include('filament.super-admin.partials.two-factor-styles')

    <div class="tf-wrap tf-wide">
        @if ($recoveryCodes !== [])
            {{-- Shown once, right after setup — never again. --}}
            <div class="tf-card"
                 x-data="{
                     copied: false,
                     codes: @js(implode("\n", $recoveryCodes)),
                     copy() { navigator.clipboard.writeText(this.codes); this.copied = true; setTimeout(() => this.copied = false, 2000) },
                     download() {
                         const text = 'Service Marketplace — Super Admin recovery codes\n{{ auth()->user()->email }}\nEach code works once.\n\n' + this.codes + '\n';
                         const link = document.createElement('a');
                         link.href = URL.createObjectURL(new Blob([text], { type: 'text/plain' }));
                         link.download = 'recovery-codes.txt';
                         link.click();
                         URL.revokeObjectURL(link.href);
                     },
                 }">
                <div class="tf-icon" aria-hidden="true"><x-filament::icon icon="heroicon-o-check-badge" /></div>
                <h2 class="tf-title">Two-step login is on</h2>
                <p class="tf-sub">Save these recovery codes now. If you lose your phone, each one lets you in once instead of an app code.</p>

                <ul class="tf-codes">
                    @foreach ($recoveryCodes as $code)
                        <li>{{ $code }}</li>
                    @endforeach
                </ul>

                <div class="tf-actions">
                    <x-filament::button color="gray" icon="heroicon-m-clipboard-document" x-on:click="copy()">
                        <span x-text="copied ? 'Copied' : 'Copy all'">Copy all</span>
                    </x-filament::button>
                    <x-filament::button color="gray" icon="heroicon-m-arrow-down-tray" x-on:click="download()">
                        Download .txt
                    </x-filament::button>
                </div>

                <div class="tf-note tf-warn">
                    <strong>They are not shown again.</strong> Keep them in a password manager or print them —
                    not on the same phone as your authenticator app.
                </div>

                <div class="tf-btn-full">
                    <x-filament::button size="lg" wire:click="finish" icon="heroicon-m-arrow-right" icon-position="after">
                        I have saved them — continue
                    </x-filament::button>
                </div>
            </div>
        @else
            <div class="tf-card">
                <div class="tf-icon" aria-hidden="true"><x-filament::icon icon="heroicon-o-device-phone-mobile" /></div>
                <h2 class="tf-title">Set up two-step login</h2>
                <p class="tf-sub">The Super Admin panel asks for a code from an authenticator app on your phone each time you sign in.</p>
            </div>

            <div class="tf-card">
                <div class="tf-step">
                    <span class="tf-step-num">1</span>
                    <div class="tf-step-body">
                        <div class="tf-step-title">Add this account to your authenticator app</div>
                        <p>
                            Use Google Authenticator, Microsoft Authenticator or Authy. Choose
                            <strong>Add account → Enter a setup key</strong> and type in:
                        </p>

                        <dl class="tf-fields">
                            <div class="tf-field">
                                <dt>Account name</dt>
                                <dd>{{ auth()->user()->email }}</dd>
                            </div>
                            <div class="tf-field">
                                <dt>Type of key</dt>
                                <dd>Time based</dd>
                            </div>
                        </dl>

                        <div class="tf-key"
                             x-data="{ copied: false, copy() { navigator.clipboard.writeText(@js(str_replace(' ', '', $this->formattedSecret()))); this.copied = true; setTimeout(() => this.copied = false, 2000) } }">
                            <code>{{ $this->formattedSecret() }}</code>
                            <x-filament::button size="sm" color="gray" icon="heroicon-m-clipboard-document" x-on:click="copy()">
                                <span x-text="copied ? 'Copied' : 'Copy key'">Copy key</span>
                            </x-filament::button>
                        </div>

                        <p>
                            <a href="{{ $this->otpauthUri() }}" class="tf-link" style="display: inline; text-align: left;">
                                Opening this on your phone? Tap here to add it straight to the app.
                            </a>
                        </p>
                    </div>
                </div>
            </div>

            <div class="tf-card">
                <div class="tf-step">
                    <span class="tf-step-num">2</span>
                    <div class="tf-step-body">
                        <div class="tf-step-title">Enter the 6-digit code the app shows</div>
                        <p>The code changes every 30 seconds — type the one showing now.</p>

                        <form wire:submit="confirm" class="tf-form" style="max-width: 22rem;">
                            {{ $this->form }}

                            <div class="tf-btn-full">
                                <x-filament::button type="submit" size="lg" icon="heroicon-m-lock-closed">
                                    Turn on two-step login
                                </x-filament::button>
                            </div>
                        </form>
                    </div>
                </div>
            </div>
        @endif
    </div>
</x-filament-panels::page>

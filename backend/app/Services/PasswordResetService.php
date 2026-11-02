<?php

namespace App\Services;

use App\Models\Setting;
use App\Models\User;
use App\Services\Firebase\FirebaseAuthClient;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Password;

/**
 * "Forgot password?" from the apps — the only way a forgotten password is
 * reset. Admins never set or see a user's password; there is no reset in
 * the panel.
 *
 * Always an emailed link, sent whichever way admin Settings → Password
 * reset selects:
 *
 *  - laravel  — Laravel's password broker emails a link to
 *               /password/reset/{token} (PasswordResetWebController).
 *               The default.
 *  - firebase — Firebase Authentication emails the link; it opens
 *               /password/firebase-action, which confirms the code with
 *               Firebase and saves the password in Laravel.
 *
 * The new password is saved here either way (and in Firebase too, for the
 * Firebase link); see AuthProvider for who checks it at sign-in.
 *
 * An address with no account never gets this far: the request refuses it
 * with "No account found" (RequestPasswordResetRequest). The null check
 * below stays as a backstop.
 *
 * Firebase chosen but not set up → the Laravel email is used. A send that
 * fails is logged loudly; the user sees the usual answer and can ask again.
 */
class PasswordResetService
{
    public const LARAVEL = 'laravel';

    public const FIREBASE = 'firebase';

    public const METHODS = [self::LARAVEL, self::FIREBASE];

    /** config/auth.php brokers: a 15-minute reset, a 7-day invite. */
    public const RESET_BROKER = 'users';

    public const INVITE_BROKER = 'invites';

    /** Super Admin → Sign-in: who sends "set your password" links. */
    public const INVITE_BY_FIREBASE = 'firebase';

    public const INVITE_BY_SERVER = 'server';

    public const INVITE_SENDERS = [self::INVITE_BY_FIREBASE, self::INVITE_BY_SERVER];

    /** Firebase's password-link codes stop working after an hour. */
    public const FIREBASE_LINK_MINUTES = 60;

    public function __construct(private readonly FirebaseAuthClient $firebase) {}

    /**
     * The method in force: the admin's choice, or Laravel when Firebase is
     * chosen but not set up. With Firebase sign-in on (AuthProvider), always
     * Firebase — its reset page sets the password in Firebase and here.
     */
    public function method(): string
    {
        if (AuthProvider::chosen() === AuthProvider::FIREBASE && $this->firebase->isConfigured()) {
            return self::FIREBASE;
        }

        $chosen = Setting::get('password_reset_method', self::LARAVEL);

        return $chosen === self::FIREBASE && $this->firebase->isConfigured()
            ? self::FIREBASE
            : self::LARAVEL;
    }

    /**
     * Emails a reset link to this address if it has an account. Returns the
     * method in force.
     */
    public function request(string $email): string
    {
        $method = $this->method();

        $user = User::query()
            // Case-insensitive collation: "Ravi@X.com" finds ravi@x.com.
            // A deleted (tombstoned) account never matches.
            ->where('email', trim($email))
            ->first();

        if ($user === null) {
            return $method;
        }

        try {
            $this->sendLink($user);
        } catch (\Throwable $e) {
            Log::error('Password reset email could not be sent', [
                'method' => $method,
                'user_id' => $user->getKey(),
                'error' => $e->getMessage(),
            ]);
        }

        return $method;
    }

    /**
     * Emails this user the link, by the method in force. Throws when it
     * could not go — for callers that must not carry on without it
     * (sign-up: the account has no usable password until the link is used).
     *
     * @throws \Throwable
     */
    public function sendLink(User $user): void
    {
        // An account that never chose its own password (admin-created,
        // salesman-sold, just registered) gets a "set your password" link
        // from whoever Super Admin → Sign-in picks (inviteSender()):
        //  - firebase (default): no mail server needed, but Firebase only
        //    emails accounts it holds, so one is made for the address as
        //    typed; accounts:expire-invites removes it if the link lapses.
        //  - server: OUR 7-day link, and no Firebase account until the person
        //    sets a password on our page (pushPassword) — needs MAIL_*.
        if ($user->must_change_password) {
            $this->inviteSender() === self::INVITE_BY_FIREBASE
                ? $this->sendFirebaseInvite($user)
                : $this->sendInviteLink($user);

            return;
        }

        $this->method() === self::FIREBASE
            ? $this->sendFirebaseLink($user)
            : $this->sendLaravelLink($user);
    }

    /**
     * Who sends a "set your password" link (decided 2026-11-02): the Super
     * Admin choice when Firebase is in use; this server whenever Firebase is
     * not (Laravel mode, or Firebase not set up).
     */
    public function inviteSender(): string
    {
        if ($this->method() !== self::FIREBASE) {
            return self::INVITE_BY_SERVER;
        }

        return Setting::get('invite_email_sender', self::INVITE_BY_FIREBASE) === self::INVITE_BY_SERVER
            ? self::INVITE_BY_SERVER
            : self::INVITE_BY_FIREBASE;
    }

    private function sendFirebaseInvite(User $user): void
    {
        // Creates the password-less Firebase account and links it
        // (users.firebase_uid), so later changes and deletes reach it.
        app(AuthProvider::class)->ensureAccount($user);
        $this->sendFirebaseLink($user);
        $this->recordInvite($user, self::FIREBASE_LINK_MINUTES);
    }

    /** When the link went, and when it stops working — for the admin lists. */
    private function recordInvite(User $user, int $minutes): void
    {
        $user->forceFill([
            'invite_sent_at' => now(),
            'invite_expires_at' => now()->addMinutes($minutes),
        ])->saveQuietly();
    }

    /** The broker for a "set your password" link: 7 days, not 15 minutes. */
    public static function brokerFor(?User $user): string
    {
        return $user?->must_change_password ? self::INVITE_BROKER : self::RESET_BROKER;
    }

    private function sendInviteLink(User $user): void
    {
        $status = Password::broker(self::INVITE_BROKER)->sendResetLink(['email' => $user->email]);

        if (! in_array($status, [Password::RESET_LINK_SENT, Password::RESET_THROTTLED], true)) {
            throw new \RuntimeException("Password broker did not send the link: {$status}");
        }

        $this->recordInvite($user, (int) config('auth.passwords.invites.expire'));
    }

    /**
     * The broker throttles a repeat within a minute itself (and reports
     * it rather than throwing); that is fine to ignore — an email went out
     * moments ago. Any other refusal means nothing was sent.
     */
    private function sendLaravelLink(User $user): void
    {
        $status = Password::broker(self::RESET_BROKER)->sendResetLink(['email' => $user->email]);

        if (! in_array($status, [Password::RESET_LINK_SENT, Password::RESET_THROTTLED], true)) {
            throw new \RuntimeException("Password broker did not send the link: {$status}");
        }
    }

    private function sendFirebaseLink(User $user): void
    {
        $this->firebase->ensureActionUrl(route('password.firebase.show'));
        $this->firebase->ensureUser($user->email);
        $this->firebase->sendPasswordResetEmail($user->email);
    }

    /** The app's confirmation text. */
    public static function message(): string
    {
        return 'We have sent a link to set a new password to this email. Check your inbox and spam folder.';
    }
}

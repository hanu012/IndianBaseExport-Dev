<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Support\Facades\Log;

/**
 * "Set your password" emails for accounts someone else created: a vendor a
 * salesman sold (at Subscribe) and any account an admin creates in the
 * panel. Replaces reading out a temporary password — only while Firebase
 * sign-in is on (AuthProvider); otherwise the temporary password flow is
 * untouched.
 *
 * It is OUR "set your password" email (PasswordResetService, the 7-day
 * invite link — decided 2026-11-01), not Firebase's: Firebase only emails
 * accounts it already holds, which meant creating a Firebase account for any
 * address typed in, real or not. Now the Firebase account is created only
 * when the person opens the link and sets a password
 * (PasswordResetWebController → AuthProvider::pushPassword), so Firebase
 * holds only people who proved the address is theirs. Needs working mail
 * (MAIL_* — with MAIL_MAILER=log nothing is delivered).
 *
 * Only for accounts still on a password they did not choose
 * (must_change_password = true) — an account whose owner set their own
 * password is never sent one by someone else. CLAUDE.md: passwords are
 * reset only by the user.
 *
 * Callers create the account with a temporary password as before, then call
 * send(). On success that password is simply never shown, so nobody holds
 * it; on failure the caller shows it as it always did — onboarding never
 * stalls on Firebase.
 */
class AccountInviteService
{
    public function __construct(
        private readonly AuthProvider $auth,
        private readonly PasswordResetService $links,
    ) {}

    public function enabled(): bool
    {
        return $this->auth->usesFirebase();
    }

    public function canInvite(User $user): bool
    {
        return $this->enabled() && $user->must_change_password && ! $user->isTombstoned();
    }

    /**
     * Emails the link. Returns the address, masked for display
     * ("r***@gmail.com"), or null when no link went out — not enabled, not
     * eligible, or the email could not be sent (logged).
     */
    public function send(User $user): ?string
    {
        if (! $this->canInvite($user)) {
            return null;
        }

        try {
            $this->links->sendLink($user);
        } catch (\Throwable $e) {
            Log::error('Set-your-password email could not be sent', [
                'user_id' => $user->getKey(),
                'error' => $e->getMessage(),
            ]);

            return null;
        }

        return self::mask($user->email);
    }

    /** "ravi.patel@gmail.com" → "r***@gmail.com" */
    public static function mask(string $email): string
    {
        [$local, $domain] = array_pad(explode('@', $email, 2), 2, '');

        return mb_substr($local, 0, 1).'***@'.$domain;
    }
}

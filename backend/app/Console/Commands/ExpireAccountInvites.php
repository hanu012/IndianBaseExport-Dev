<?php

namespace App\Console\Commands;

use App\Models\User;
use App\Services\AuthProvider;
use App\Services\Firebase\FirebaseAuthClient;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * Hourly (decided 2026-11-01, hourly + sign-up clean-up 2026-11-02):
 * accounts that never set their own password.
 *
 *  - Their "set your password" link stops working by itself (an hour when
 *    Firebase sent it, 7 days when this server did — invite_expires_at);
 *    the admin lists then show "Invite expired" (User::inviteStatus) and
 *    "Send password link" sends a new one. This only counts them.
 *  - Once the invite has lapsed (or none is out), any Firebase account such
 *    a user has is removed: with Firebase sending invites, one is made for
 *    the address as typed — real or mistyped — and this is the clean-up.
 *    Never while a link is still out.
 *  - App sign-ups (users.self_registered) whose link lapsed unused are
 *    deleted outright, with their vendor/customer row: nobody ever showed
 *    the address was theirs, and leaving the row would keep the address
 *    taken. Only if no device ever signed in. Admin-created and
 *    salesman-sold accounts keep their users row — it is the record; a new
 *    link or setting a password makes the Firebase account again.
 */
class ExpireAccountInvites extends Command
{
    protected $signature = 'accounts:expire-invites';

    protected $description = 'Report expired "set your password" invites, remove Firebase accounts of users who never set a password, and delete unconfirmed app sign-ups.';

    public function handle(FirebaseAuthClient $firebase, AuthProvider $auth): int
    {
        $expired = 0;
        $removed = 0;
        $deleted = 0;

        User::query()
            ->where('must_change_password', true)
            ->chunkById(200, function ($users) use ($firebase, $auth, &$expired, &$removed, &$deleted) {
                foreach ($users as $user) {
                    $status = $user->inviteStatus();

                    if ($status === User::INVITE_EXPIRED) {
                        $expired++;
                    }

                    // Never while a link is still out: a Firebase-sent link
                    // needs its Firebase account to work.
                    if ($status !== User::INVITE_SENT
                        && $firebase->isConfigured()
                        && $this->removeFirebaseAccount($firebase, $user)) {
                        $removed++;
                    }

                    if ($status === User::INVITE_EXPIRED
                        && $user->self_registered
                        && $this->deleteUnconfirmedSignUp($auth, $user)) {
                        $deleted++;
                    }
                }
            });

        $this->info("Expired invites: {$expired}; Firebase accounts removed: {$removed}; unconfirmed sign-ups deleted: {$deleted}.");

        return self::SUCCESS;
    }

    private function removeFirebaseAccount(FirebaseAuthClient $firebase, User $user): bool
    {
        try {
            // Older invites created the Firebase account without saving its
            // uid here, so look it up by email too.
            $uid = $user->firebase_uid ?? $firebase->findUid($user->email);

            if ($uid === null) {
                return false;
            }

            $firebase->deleteAccount($uid);
            $user->forceFill(['firebase_uid' => null])->saveQuietly();

            return true;
        } catch (\Throwable $e) {
            $this->warn("Could not remove the Firebase account of user {$user->id}: {$e->getMessage()}");

            return false;
        }
    }

    private function deleteUnconfirmedSignUp(AuthProvider $auth, User $user): bool
    {
        // A token means someone did sign in on a device — not a dead address.
        if ($user->tokens()->exists()) {
            return false;
        }

        try {
            DB::transaction(function () use ($auth, $user) {
                // Any Firebase account left (step above skipped or failed) goes
                // first, while the row still exists to clear firebase_uid on.
                $auth->forget($user);
                // Force: a soft-deleted row would keep the email taken, so the
                // person could never sign up again with the right address.
                // The vendor/customer row goes with it (cascade).
                $user->forceDelete();
            });

            return true;
        } catch (\Throwable $e) {
            $this->warn("Could not delete unconfirmed sign-up {$user->id}: {$e->getMessage()}");

            return false;
        }
    }
}

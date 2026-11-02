<?php

namespace App\Console\Commands;

use App\Models\User;
use App\Services\Firebase\FirebaseAuthClient;
use Illuminate\Console\Command;

/**
 * Daily (decided 2026-11-01): accounts that never set their own password.
 *
 *  - Their "set your password" link stops working by itself (an hour when
 *    Firebase sent it, 7 days when this server did — invite_expires_at);
 *    the admin lists then show "Invite expired" (User::inviteStatus) and
 *    "Send password link" sends a new one. This only counts them.
 *  - Once the invite has lapsed (or none is out), any Firebase account such
 *    a user has is removed: with Firebase sending invites, one is made for
 *    the address as typed — real or mistyped — and this is the clean-up.
 *    Never while a link is still out. The users row is untouched — it is
 *    the record; a new link or setting a password makes it again.
 */
class ExpireAccountInvites extends Command
{
    protected $signature = 'accounts:expire-invites';

    protected $description = 'Report expired "set your password" invites and remove Firebase accounts of users who never set a password.';

    public function handle(FirebaseAuthClient $firebase): int
    {
        $expired = 0;
        $removed = 0;

        User::query()
            ->where('must_change_password', true)
            ->chunkById(200, function ($users) use ($firebase, &$expired, &$removed) {
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
                }
            });

        $this->info("Expired invites: {$expired}; Firebase accounts removed: {$removed}.");

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
}

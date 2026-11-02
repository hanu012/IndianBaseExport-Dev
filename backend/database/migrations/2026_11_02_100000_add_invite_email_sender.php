<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Who sends the "set your password" email to an account that has not chosen
 * a password yet (decided 2026-11-02 — Super Admin → System settings →
 * Sign-in):
 *
 *  - firebase — Firebase's email (the default: no mail server needed). Its
 *               link lasts an hour, and Firebase needs the account first, so
 *               one is made for the address as typed; the daily
 *               accounts:expire-invites removes it if the invite lapses.
 *  - server   — this server's own email (needs MAIL_*), a 7-day link, and
 *               no Firebase account until the person sets a password.
 *
 * users.invite_expires_at: when the last such link stops working — an hour
 * or 7 days depending on who sent it, so the admin lists can say "Invite
 * expired" accurately.
 *
 * Not in SettingSeeder: its updateOrCreate would reset an admin's choice.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->timestamp('invite_expires_at')->nullable()->after('invite_sent_at');
        });

        if (! DB::table('settings')->where('key', 'invite_email_sender')->exists()) {
            DB::table('settings')->insert([
                'key' => 'invite_email_sender',
                'value' => 'firebase',
                'type' => 'string',
                'label' => 'Set-your-password emails sent by',
                'description' => 'firebase (no mail server needed) or server (needs MAIL_*) — for accounts that have not chosen a password yet.',
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
    }

    public function down(): void
    {
        DB::table('settings')->where('key', 'invite_email_sender')->delete();

        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('invite_expires_at');
        });
    }
};

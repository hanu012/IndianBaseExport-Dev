<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * When the last "set your password" link went to an account that has not
 * chosen a password yet (decided 2026-11-01). Lets the admin lists show
 * "Invite sent" / "Invite expired" — the link itself lasts 7 days
 * (auth.passwords.invites.expire).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->timestamp('invite_sent_at')->nullable()->after('must_change_password');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('invite_sent_at');
        });
    }
};

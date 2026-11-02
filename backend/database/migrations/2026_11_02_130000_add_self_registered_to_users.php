<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Marks accounts made by the app's own sign-up (auth/register), so
 * accounts:expire-invites can remove one whose address never confirmed — the
 * "set your password" link lapsed unused. Admin-created and salesman-sold
 * accounts are never removed this way; they stay false.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->boolean('self_registered')->default(false)->after('must_change_password');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('self_registered');
        });
    }
};

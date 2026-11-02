<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Promotion management (decided 2026-10-31, vendor promotion designs):
 *  - text-only promotions: media is optional; captions up to 300 characters;
 *  - Pause stops the clock (paused_at; the paused time is added back to
 *    ends_at on resume);
 *  - Extend buys the same package again — a promotion_extensions row paid
 *    like any purchase, whose days are added to ends_at once paid;
 *  - packages can be flagged "Most popular".
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('promotions', function (Blueprint $table) {
            $table->string('caption', 300)->change();
            $table->string('media_type', 10)->nullable()->change();
            $table->string('media_path')->nullable()->change();
            $table->timestamp('paused_at')->nullable()->after('ends_at');
        });

        Schema::table('promotion_packages', function (Blueprint $table) {
            $table->boolean('is_popular')->default(false)->after('allows_video');
        });

        Schema::create('promotion_extensions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('promotion_id')->constrained('promotions')->cascadeOnDelete();
            $table->unsignedInteger('days');
            $table->unsignedBigInteger('price_paise');
            // pending_payment | paid | cancelled
            $table->string('status', 20)->default('pending_payment');
            $table->uuid('idempotency_key')->unique();
            $table->timestamps();
        });

        Schema::table('payments', function (Blueprint $table) {
            $table->foreignId('promotion_extension_id')->nullable()->after('promotion_id')
                ->constrained('promotion_extensions')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('payments', function (Blueprint $table) {
            $table->dropConstrainedForeignId('promotion_extension_id');
        });

        Schema::dropIfExists('promotion_extensions');

        Schema::table('promotion_packages', function (Blueprint $table) {
            $table->dropColumn('is_popular');
        });

        Schema::table('promotions', function (Blueprint $table) {
            $table->dropColumn('paused_at');
        });
    }
};

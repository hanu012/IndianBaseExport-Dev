<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Paid promotions and the customer Feed (decided 2026-10-31).
 *
 * The admin defines promotion packages; a vendor buys one and posts one photo
 * or video with a caption into chosen zones. The customer app's Feed tab
 * shows, for the customer's zone, those paid promotions first and then the
 * portfolio photos/videos of vendors serving that zone. Customers like and
 * comment on both kinds of post, so likes and comments are polymorphic
 * (Promotion | Media).
 *
 * Statuses are plain strings, not enums, so a new state is a code change
 * rather than another raw ALTER (CLAUDE.md, "Widening an existing enum").
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('promotion_packages', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->text('description')->nullable();
            $table->unsignedInteger('duration_days');
            $table->unsignedBigInteger('price_paise');
            $table->unsignedInteger('max_zones')->default(3);
            $table->boolean('allows_video')->default(true);
            $table->boolean('is_active')->default(true);
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestamps();
        });

        Schema::create('promotions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('vendor_id')->constrained('vendors')->cascadeOnDelete();
            // Packages are switched off, never deleted, while bought.
            $table->foreignId('promotion_package_id')->constrained('promotion_packages')->restrictOnDelete();
            $table->string('caption', 150);
            $table->string('media_type', 10); // image | video
            $table->string('media_path');
            $table->string('disk')->nullable();
            // What the vendor paid for, frozen at purchase: a later package
            // edit never changes a running promotion.
            $table->unsignedBigInteger('price_paise');
            $table->unsignedInteger('duration_days');
            // pending_payment | live | ended | cancelled
            $table->string('status', 20)->default('pending_payment');
            $table->timestamp('starts_at')->nullable();
            $table->timestamp('ends_at')->nullable();
            $table->timestamp('ending_reminder_sent_at')->nullable();
            // Admin takedown — no review before going live (decided), so
            // this is how something unacceptable comes down.
            $table->boolean('is_hidden')->default(false);
            $table->text('hidden_reason')->nullable();
            $table->foreignId('hidden_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('hidden_at')->nullable();
            $table->unsignedBigInteger('views_count')->default(0);
            $table->uuid('idempotency_key')->unique();
            $table->timestamps();

            $table->index(['status', 'is_hidden', 'ends_at']);
            $table->index(['vendor_id', 'status']);
        });

        Schema::create('promotion_zone', function (Blueprint $table) {
            $table->foreignId('promotion_id')->constrained('promotions')->cascadeOnDelete();
            $table->foreignId('zone_id')->constrained('zones')->cascadeOnDelete();
            $table->primary(['promotion_id', 'zone_id']);
            $table->index('zone_id');
        });

        // Likes and comments on any feed post: a Promotion or a portfolio Media.
        Schema::create('feed_likes', function (Blueprint $table) {
            $table->id();
            $table->morphs('likeable');
            $table->foreignId('customer_id')->constrained('customers')->cascadeOnDelete();
            $table->timestamps();
            $table->unique(['likeable_type', 'likeable_id', 'customer_id'], 'feed_likes_unique');
        });

        Schema::create('feed_comments', function (Blueprint $table) {
            $table->id();
            $table->morphs('commentable');
            $table->foreignId('customer_id')->constrained('customers')->cascadeOnDelete();
            $table->string('body', 500);
            $table->boolean('is_hidden')->default(false);
            $table->foreignId('hidden_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('hidden_at')->nullable();
            $table->unsignedInteger('reports_count')->default(0);
            $table->timestamps();
            $table->index(['commentable_type', 'commentable_id', 'is_hidden', 'created_at'], 'feed_comments_listing');
        });

        Schema::create('feed_comment_reports', function (Blueprint $table) {
            $table->id();
            $table->foreignId('feed_comment_id')->constrained('feed_comments')->cascadeOnDelete();
            $table->foreignId('customer_id')->constrained('customers')->cascadeOnDelete();
            $table->string('reason', 500)->nullable();
            $table->timestamps();
            $table->unique(['feed_comment_id', 'customer_id']);
        });

        // A payment now belongs to a subscription OR a promotion.
        Schema::table('payments', function (Blueprint $table) {
            $table->unsignedBigInteger('subscription_id')->nullable()->change();
            $table->foreignId('promotion_id')->nullable()->after('subscription_id')
                ->constrained('promotions')->cascadeOnDelete();
        });

        // "Calls from this ad": a lead started from a promoted post.
        Schema::table('leads', function (Blueprint $table) {
            $table->foreignId('promotion_id')->nullable()->after('zone_id')
                ->constrained('promotions')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('leads', function (Blueprint $table) {
            $table->dropConstrainedForeignId('promotion_id');
        });

        Schema::table('payments', function (Blueprint $table) {
            $table->dropConstrainedForeignId('promotion_id');
        });

        Schema::dropIfExists('feed_comment_reports');
        Schema::dropIfExists('feed_comments');
        Schema::dropIfExists('feed_likes');
        Schema::dropIfExists('promotion_zone');
        Schema::dropIfExists('promotions');
        Schema::dropIfExists('promotion_packages');
    }
};

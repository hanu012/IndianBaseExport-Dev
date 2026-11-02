<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Feed comments get replies and a business author (decided 2026-10-31,
 * comments design): a comment may answer another (one level — replies hang
 * under a top-level comment), and the vendor who owns the post may reply as
 * the business. So a comment is written by a customer OR that vendor.
 * Comments can be liked through the existing polymorphic feed_likes.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('feed_comments', function (Blueprint $table) {
            $table->unsignedBigInteger('customer_id')->nullable()->change();
            $table->foreignId('vendor_id')->nullable()->after('customer_id')
                ->constrained('vendors')->cascadeOnDelete();
            $table->foreignId('parent_id')->nullable()->after('commentable_id')
                ->constrained('feed_comments')->cascadeOnDelete();
            $table->index(['parent_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::table('feed_comments', function (Blueprint $table) {
            $table->dropConstrainedForeignId('parent_id');
            $table->dropConstrainedForeignId('vendor_id');
        });
    }
};

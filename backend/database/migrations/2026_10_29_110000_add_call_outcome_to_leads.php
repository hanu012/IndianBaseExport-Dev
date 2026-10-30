<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Whether a call lead was actually answered, and for how long (decided
 * 2026-10-29).
 *
 * The customer's phone cannot know: Android tells an ordinary app when an
 * outgoing call starts and ends, never when it is picked up, so
 * call_duration_seconds includes ringing and is recorded for unanswered
 * calls too. The vendor's phone can — for an INCOMING call it reports
 * ringing, answered and ended. The vendor app sends those (times only, no
 * numbers) to POST vendors/me/calls, and CallOutcomeMatcher pairs each with
 * the call lead created just before it rang.
 *
 * call_outcome: null = unknown (the vendor app could not confirm it),
 * 'answered' or 'not_answered'. call_talk_seconds: answered to hung up —
 * the real conversation, set only when answered.
 *
 * Admin Settings → App → "Confirm answered calls (vendor app)" switches it.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('leads', function (Blueprint $table) {
            $table->enum('call_outcome', ['answered', 'not_answered'])->nullable()->after('call_duration_recorded_at');
            $table->unsignedInteger('call_talk_seconds')->nullable()->after('call_outcome');
            $table->timestamp('call_outcome_recorded_at')->nullable()->after('call_talk_seconds');

            // The matcher's lookup: this vendor's unconfirmed calls around a time.
            $table->index(['vendor_id', 'channel', 'call_outcome', 'created_at'], 'leads_call_outcome_match_index');
        });

        if (! DB::table('settings')->where('key', 'call_answer_detection_enabled')->exists()) {
            DB::table('settings')->insert([
                'key' => 'call_answer_detection_enabled',
                'value' => 'true',
                'type' => 'boolean',
                'group' => 'app',
                'label' => 'Confirm answered calls (vendor app)',
                'description' => 'The vendor app notices when a customer\'s call rings, is answered and ends, so calls show as Answered with the real talk time, or Not answered. Needs Call tracking on.',
                'is_editable' => true,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
    }

    public function down(): void
    {
        DB::table('settings')->where('key', 'call_answer_detection_enabled')->delete();

        Schema::table('leads', function (Blueprint $table) {
            $table->dropIndex('leads_call_outcome_match_index');
            $table->dropColumn(['call_outcome', 'call_talk_seconds', 'call_outcome_recorded_at']);
        });
    }
};

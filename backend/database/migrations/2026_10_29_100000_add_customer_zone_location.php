<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Customer location by zone (decided 2026-10-29).
 *
 * Admin Settings → App → "Map location in customer app". Off (the default):
 * the customer app sets its location by picking a main zone and then a
 * sub-zone from the zones the admin created — no map, no GPS, no saved
 * addresses. On: the map / search / GPS flow as before.
 *
 * customers.zone_id is the zone picked that way, kept beside the last point
 * and pincode as the customer's current location.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('customers', function (Blueprint $table) {
            // nullOnDelete: a zone an admin deletes must not take the
            // customer row with it, nor be blocked by it.
            $table->foreignId('zone_id')->nullable()->after('pincode')
                ->constrained('zones')->nullOnDelete();
        });

        if (! DB::table('settings')->where('key', 'customer_map_location_enabled')->exists()) {
            DB::table('settings')->insert([
                'key' => 'customer_map_location_enabled',
                'value' => 'false',
                'type' => 'boolean',
                'group' => 'app',
                'label' => 'Map location in customer app',
                'description' => 'On: customers set their location on a Google map (search, GPS, saved addresses). Off: they pick a main zone and sub-zone from the zones created here.',
                'is_editable' => true,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
    }

    public function down(): void
    {
        DB::table('settings')->where('key', 'customer_map_location_enabled')->delete();

        Schema::table('customers', function (Blueprint $table) {
            $table->dropConstrainedForeignId('zone_id');
        });
    }
};

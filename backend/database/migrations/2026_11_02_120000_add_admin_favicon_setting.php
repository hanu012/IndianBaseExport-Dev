<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Super Admin → System settings → Branding: an uploaded favicon for both
 * admin panels (a path on the public disk). Empty = the built-in icon pack
 * in public/favicons (resources/views/filament/hooks/favicons.blade.php).
 *
 * Not in SettingSeeder: its updateOrCreate would reset an admin's choice.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (! DB::table('settings')->where('key', 'admin_favicon')->exists()) {
            DB::table('settings')->insert([
                'key' => 'admin_favicon',
                'value' => null,
                'type' => 'string',
                'label' => 'Admin panel favicon',
                'description' => 'Uploaded browser-tab icon for /admin and /super-admin. Empty = the built-in icon.',
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
    }

    public function down(): void
    {
        DB::table('settings')->where('key', 'admin_favicon')->delete();
    }
};

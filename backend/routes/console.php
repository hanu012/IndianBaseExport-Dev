<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// BUILD_PLAN 7.1 / SPEC section 7 — Active -> Grace -> Expired.
Schedule::command('subscriptions:process-expiry')->daily();

// BUILD_PLAN 7.2 / SPEC section 5.12 — expiry reminders (T-15/T-7/T-1).
Schedule::command('subscriptions:send-expiry-reminders')->daily();

// Vendor KYC documents past their expiry date → Expired, vendor notified.
Schedule::command('kyc:expire-documents')->daily();

// Paid promotions past their days → ended; vendors reminded the day before.
Schedule::command('promotions:process-expiry')->daily();

// "Set your password" invites: Firebase accounts of anyone who never set a
// password are removed, and app sign-ups whose link lapsed unused are deleted.
// Hourly: a Firebase-sent link lasts an hour, so leftovers go the same day.
Schedule::command('accounts:expire-invites')->hourly();

// API error log rows older than ApiErrorLog::RETENTION_DAYS.
Schedule::command('model:prune', ['--model' => [\App\Models\ApiErrorLog::class]])->daily();

// Heartbeat for Super Admin → System health: proves `schedule:run` is being
// called (cron), so the daily expiry job above is actually happening.
Schedule::call(fn () => \Illuminate\Support\Facades\Cache::forever(\App\Support\SystemHealth::SCHEDULER_HEARTBEAT, now()->getTimestamp()))
    ->everyMinute()
    ->name('system-health-heartbeat');

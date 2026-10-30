<?php

namespace App\Services;

use App\Models\Lead;
use App\Models\Setting;
use App\Models\Vendor;
use Illuminate\Support\Carbon;

/**
 * Pairs an incoming call seen on the vendor's phone with the customer's
 * call lead, so the lead can say Answered (with the real talk time) or Not
 * answered.
 *
 * The vendor app reports only times — when the phone rang, whether and when
 * it was answered, when it ended — never a number: Android hides the
 * caller's number from an app without the restricted call-log permission,
 * and this does not need it. The pairing is by time instead: a customer
 * taps Call (the lead is created), the dialler opens, they press call, and
 * the vendor's phone rings shortly after. So the lead to pair is this
 * vendor's newest unconfirmed call lead created in the few minutes before
 * the ring. A ring with no such lead is somebody else's call and is
 * dropped — nothing about it is stored.
 */
class CallOutcomeMatcher
{
    /** Tap Call → press call in the dialler → it rings: allowed this long. */
    public const RING_AFTER_LEAD_MAX_SECONDS = 180;

    /** Clock difference the server's correction may leave between the phones. */
    public const CLOCK_TOLERANCE_SECONDS = 30;

    /**
     * Admin Settings → App: "Call tracking in apps" AND "Confirm answered
     * calls (vendor app)".
     */
    public static function enabled(): bool
    {
        return (bool) Setting::get('call_tracking_enabled', true)
            && (bool) Setting::get('call_answer_detection_enabled', true);
    }

    /**
     * Records one call on its lead. Returns the lead, or null when no call
     * lead fits (a personal call, or one already confirmed).
     */
    public function match(Vendor $vendor, Carbon $rangAt, bool $answered, ?int $talkSeconds): ?Lead
    {
        $lead = Lead::query()
            ->where('vendor_id', $vendor->id)
            ->where('channel', 'call')
            ->whereNull('call_outcome')
            ->whereBetween('created_at', [
                $rangAt->copy()->subSeconds(self::RING_AFTER_LEAD_MAX_SECONDS),
                $rangAt->copy()->addSeconds(self::CLOCK_TOLERANCE_SECONDS),
            ])
            // The newest one: two customers calling minutes apart each get
            // the ring that followed their own tap.
            ->latest('created_at')
            ->latest('id')
            ->first();

        $lead?->recordCallOutcome($answered, $talkSeconds);

        return $lead;
    }
}

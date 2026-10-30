package com.servicemarketplace.service_marketplace

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.TelephonyManager

/**
 * The vendor app's half of "was the customer's call answered?" — hears an
 * incoming call ring, get picked up and end (needs READ_PHONE_STATE), and
 * hands the times to IncomingCallStore. Declared only in the vendor
 * flavour's manifest, so it runs even while the app is closed.
 *
 * Some phones send each state twice (once per SIM); the store ignores the
 * repeats.
 */
class IncomingCallReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) return

        when (intent.getStringExtra(TelephonyManager.EXTRA_STATE)) {
            TelephonyManager.EXTRA_STATE_RINGING -> IncomingCallStore.onRinging(context)
            TelephonyManager.EXTRA_STATE_OFFHOOK -> IncomingCallStore.onOffhook(context)
            TelephonyManager.EXTRA_STATE_IDLE -> IncomingCallStore.onIdle(context)
        }
    }
}

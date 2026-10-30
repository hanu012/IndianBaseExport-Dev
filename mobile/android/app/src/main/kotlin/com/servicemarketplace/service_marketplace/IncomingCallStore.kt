package com.servicemarketplace.service_marketplace

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * Incoming calls the vendor's phone saw (vendor app, Android only), kept
 * until Flutter has sent them to the server (IncomingCallReporter.flush).
 *
 * Only times are kept — when it rang, when (if) it was answered, how long
 * the talk lasted — never a number: the server pairs each ring with the
 * customer call lead created just before it (CallOutcomeMatcher), and
 * drops any ring that pairs with nothing.
 *
 * For an INCOMING call Android does say when it is answered: RINGING, then
 * OFFHOOK the moment it is picked up, then IDLE when it ends. RINGING then
 * IDLE is a call nobody answered. (An outgoing call goes straight to
 * OFFHOOK with no RINGING, so the vendor's own calls are never recorded.)
 */
object IncomingCallStore {
    private const val PREFS = "incoming_calls"
    private const val RING_AT = "ring_at"
    private const val ANSWERED_AT = "answered_at"
    private const val LAST_STATE = "last_state"
    private const val QUEUE = "queue"

    /** Older than the server's window is no use to anyone. */
    private const val MAX_AGE_MS = 24L * 60 * 60 * 1000
    private const val MAX_QUEUED = 50

    /** Same cap as Lead::MAX_CALL_DURATION_SECONDS on the server. */
    private const val MAX_TALK_SECONDS = 3600L

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun onRinging(context: Context) {
        val p = prefs(context)

        // A second call ringing while already on one (call waiting) cannot
        // be told apart from the first by state alone — skip it rather than
        // record the ongoing call as its answer.
        if (p.getString(LAST_STATE, IDLE) == OFFHOOK || p.getLong(RING_AT, 0L) != 0L) {
            p.edit().putString(LAST_STATE, RINGING).commit()
            return
        }

        p.edit()
            .putLong(RING_AT, System.currentTimeMillis())
            .putLong(ANSWERED_AT, 0L)
            .putString(LAST_STATE, RINGING)
            .commit()
    }

    fun onOffhook(context: Context) {
        val p = prefs(context)
        val editor = p.edit().putString(LAST_STATE, OFFHOOK)

        if (p.getLong(RING_AT, 0L) != 0L && p.getLong(ANSWERED_AT, 0L) == 0L) {
            editor.putLong(ANSWERED_AT, System.currentTimeMillis())
        }

        editor.commit()
    }

    fun onIdle(context: Context) {
        val p = prefs(context)
        val ringAt = p.getLong(RING_AT, 0L)

        if (ringAt == 0L) {
            p.edit().putString(LAST_STATE, IDLE).commit()
            return
        }

        val answeredAt = p.getLong(ANSWERED_AT, 0L)
        val call = JSONObject()
            .put("rang_at", ringAt)
            .put("answered", answeredAt != 0L)

        if (answeredAt != 0L) {
            call.put(
                "talk_seconds",
                ((System.currentTimeMillis() - answeredAt) / 1000).coerceIn(0L, MAX_TALK_SECONDS),
            )
        }

        val queue = fresh(queue(p))
        queue.add(call)

        p.edit()
            .putString(QUEUE, JSONArray(queue.takeLast(MAX_QUEUED)).toString())
            .remove(RING_AT)
            .remove(ANSWERED_AT)
            .putString(LAST_STATE, IDLE)
            .commit()
    }

    /** Calls waiting to be sent, oldest first: {rang_at (epoch ms), answered, talk_seconds?}. */
    fun peek(context: Context): List<Map<String, Any?>> =
        fresh(queue(prefs(context))).map { call ->
            mapOf(
                "rang_at" to call.getLong("rang_at"),
                "answered" to call.getBoolean("answered"),
                "talk_seconds" to if (call.has("talk_seconds")) call.getLong("talk_seconds") else null,
            )
        }

    /** Drops the calls the server has received — every one that rang at or before [upTo]. */
    fun ack(context: Context, upTo: Long) {
        val p = prefs(context)
        val left = fresh(queue(p)).filter { it.getLong("rang_at") > upTo }
        p.edit().putString(QUEUE, JSONArray(left).toString()).commit()
    }

    private fun queue(p: android.content.SharedPreferences): List<JSONObject> {
        val raw = p.getString(QUEUE, null) ?: return emptyList()

        return try {
            val array = JSONArray(raw)
            List(array.length()) { array.getJSONObject(it) }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun fresh(calls: List<JSONObject>): MutableList<JSONObject> {
        val cutoff = System.currentTimeMillis() - MAX_AGE_MS
        return calls.filter { it.optLong("rang_at", 0L) >= cutoff }.toMutableList()
    }

    private const val IDLE = "idle"
    private const val RINGING = "ringing"
    private const val OFFHOOK = "offhook"
}

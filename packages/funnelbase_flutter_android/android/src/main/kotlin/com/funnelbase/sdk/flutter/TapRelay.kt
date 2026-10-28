package com.funnelbase.sdk.flutter

import android.content.Context
import android.content.Intent
import android.util.Log
import com.funnelbase.sdk.AnalyticsPush
import com.funnelbase.sdk.PushPayload

/**
 * Hands tapped notifications to Dart, holding them until Dart is listening.
 *
 * A tap reaches the app as an intent: the SDK's tap activity records the open and starts the
 * launcher activity with the push in its extras — a cold start's first intent, or `onNewIntent`
 * on the running `FlutterActivity`, which is `singleTop`. The plugin never registers the native
 * tap handler: with one, the SDK would not start the app's activity, and a tap from the
 * background would leave the app where it was.
 *
 * A tap that arrives before Dart has called `pushTapsReady` — every cold start's — is held here,
 * and so is any while the engine is detached.
 */
internal class TapRelay(context: Context) {

    private val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
    private val pending = mutableListOf<PushTapMessage>()
    private var api: AnalyticsFlutterApi? = null
    private var ready = false

    fun attach(api: AnalyticsFlutterApi) {
        this.api = api
        ready = false
    }

    fun detach() {
        api = null
        ready = false
    }

    /** Dart has its handler set up: deliver what was held, and everything after it at once. */
    fun ready() {
        ready = true
        val held = pending.toList()
        pending.clear()
        held.forEach(::deliver)
    }

    /**
     * The push an intent carries, if any, taken off it so that the same intent is never delivered
     * twice — and remembered by delivery, because an activity recreated after a configuration
     * change or a process death is handed its original intent again, extras and all.
     */
    fun take(intent: Intent?) {
        val payload = AnalyticsPush.payloadFrom(intent) ?: return
        val actionId = AnalyticsPush.actionIdFrom(intent)
        intent?.removeExtra(AnalyticsPush.EXTRA_PAYLOAD)
        intent?.removeExtra(AnalyticsPush.EXTRA_ACTION_ID)
        if (!firstTime(payload.deliveryId, actionId)) return

        val tap = PushTapMessage(payload.toMessage(), actionId)
        if (ready && api != null) deliver(tap) else pending += tap
    }

    private fun deliver(tap: PushTapMessage) {
        val target = api
        if (target == null) {
            pending += tap
            return
        }
        target.onPushTapped(tap) { result ->
            result.onFailure { Log.w(TAG, "A push tap could not reach Dart: ${it.message}") }
        }
    }

    /** True the first time this delivery and button are seen; the last few are kept on disk. */
    private fun firstTime(deliveryId: String, actionId: String?): Boolean {
        val key = "$deliveryId/${actionId.orEmpty()}"
        val seen = preferences.getString(SEEN, "").orEmpty().split('\n').filter { it.isNotEmpty() }
        if (key in seen) return false
        preferences.edit().putString(SEEN, (seen + key).takeLast(KEEP).joinToString("\n")).apply()
        return true
    }

    private companion object {
        // ConfigStore's file, under its name from before the rename.
        const val PREFERENCES = "analytics_flutter"
        const val SEEN = "taps_seen"
        const val KEEP = 20
    }
}

internal fun PushPayload.toMessage() = PushPayloadMessage(
    deliveryId = deliveryId,
    runId = runId,
    title = title,
    body = body,
    imageUrl = imageUrl,
    deepLink = deepLink,
    collapseKey = collapseKey,
    buttons = buttons.map { PushButtonMessage(it.id, it.title, it.deepLink) },
    data = data,
)

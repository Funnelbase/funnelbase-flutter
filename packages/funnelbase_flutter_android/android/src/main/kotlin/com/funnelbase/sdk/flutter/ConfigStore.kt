package com.funnelbase.sdk.flutter

import android.content.Context
import android.util.Log
import com.funnelbase.sdk.AnalyticsConfig
import org.json.JSONObject
import kotlin.math.roundToLong

/**
 * The configuration Dart last passed to `Analytics.initialize`, kept for the next process start.
 *
 * JSON through `org.json`, which the platform has: sdk-android keeps kotlinx-serialization to
 * itself, and a plugin adding a JSON library to every app for twelve fields would be a poor trade.
 */
internal object ConfigStore {

    // The package's name before it was Funnelbase; kept, so an installed app keeps its config.
    private const val PREFERENCES = "analytics_flutter"
    private const val KEY = "config"

    fun write(context: Context, config: AndroidConfigMessage) {
        val json = JSONObject()
            .put("apiKey", config.apiKey)
            .put("endpoint", config.endpoint)
            .put("flushIntervalSeconds", config.flushIntervalSeconds)
            .put("flushBatchSize", config.flushBatchSize)
            .put("maxQueuedEvents", config.maxQueuedEvents)
            .put("sessionTimeoutMinutes", config.sessionTimeoutMinutes)
            .put("trackApplicationLifecycle", config.trackApplicationLifecycle)
            .put("debugLogging", config.debugLogging)
            .put("pushChannelId", config.pushChannelId)
            .put("pushChannelName", config.pushChannelName)
            .put("pushSmallIcon", config.pushSmallIcon ?: JSONObject.NULL)
            .put("pushMaxImageBytes", config.pushMaxImageBytes)
        // commit, not apply: the next read may be a process start moments from now, after a crash.
        preferences(context).edit().putString(KEY, json.toString()).commit()
    }

    /** Null when Dart has never initialised the SDK on this install, or the stored copy is unreadable. */
    fun read(context: Context): AndroidConfigMessage? {
        val stored = preferences(context).getString(KEY, null) ?: return null
        return runCatching {
            val json = JSONObject(stored)
            AndroidConfigMessage(
                apiKey = json.getString("apiKey"),
                endpoint = json.getString("endpoint"),
                flushIntervalSeconds = json.getLong("flushIntervalSeconds"),
                flushBatchSize = json.getLong("flushBatchSize"),
                maxQueuedEvents = json.getLong("maxQueuedEvents"),
                sessionTimeoutMinutes = json.getDouble("sessionTimeoutMinutes"),
                trackApplicationLifecycle = json.getBoolean("trackApplicationLifecycle"),
                debugLogging = json.getBoolean("debugLogging"),
                pushChannelId = json.getString("pushChannelId"),
                pushChannelName = json.getString("pushChannelName"),
                pushSmallIcon = if (json.isNull("pushSmallIcon")) null else json.getString("pushSmallIcon"),
                pushMaxImageBytes = json.getLong("pushMaxImageBytes"),
            )
        }.onFailure { Log.w(TAG, "The stored configuration is unreadable; waiting for Dart: ${it.message}") }
            .getOrNull()
    }

    private fun preferences(context: Context) = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
}

/**
 * The native configuration for [message]. `autoTrackScreenViews` is always off: a Flutter app is one
 * Activity, and an automatic screen view would report `MainActivity` on every foreground and bury
 * the real screens, which Dart reports instead.
 *
 * Null, logged, for a configuration the native SDK refuses — never a crash, since this runs at
 * process start from a content provider, where a throw would take the app down before it opens.
 */
internal fun AndroidConfigMessage.toNativeConfig(context: Context): AnalyticsConfig? {
    // The native setting is whole minutes; Dart's is a double because iOS's is.
    val minutes = sessionTimeoutMinutes.roundToLong().coerceAtLeast(1)
    if (minutes.toDouble() != sessionTimeoutMinutes) {
        Log.w(TAG, "sessionTimeoutMinutes is whole minutes on Android — using $minutes")
    }
    return runCatching {
        AnalyticsConfig(
            apiKey = apiKey,
            endpoint = endpoint,
            flushIntervalSeconds = flushIntervalSeconds,
            flushBatchSize = flushBatchSize.toInt(),
            maxQueuedEvents = maxQueuedEvents.toInt(),
            sessionTimeoutMinutes = minutes,
            trackApplicationLifecycle = trackApplicationLifecycle,
            autoTrackScreenViews = false,
            debugLogging = debugLogging,
            pushChannelId = pushChannelId,
            pushChannelName = pushChannelName,
            pushSmallIconResId = smallIconId(context, pushSmallIcon),
            pushMaxImageBytes = pushMaxImageBytes,
        )
    }.onFailure { Log.w(TAG, "The native SDK refused this configuration: ${it.message}") }
        .getOrNull()
}

/**
 * A drawable's id by its name, as Dart can only name it. Zero — the app's own icon — when there is
 * no name or no such drawable, the second logged: a typo would otherwise show the wrong icon with
 * no hint as to why.
 */
private fun smallIconId(context: Context, name: String?): Int {
    if (name.isNullOrBlank()) return 0
    // getIdentifier is the only way from a name to an id; R is not visible to a library.
    @Suppress("DiscouragedApi")
    val id = context.resources.getIdentifier(name, "drawable", context.packageName)
    if (id == 0) Log.w(TAG, "No drawable named '$name' — notifications use the app's icon")
    return id
}

internal const val TAG = "Analytics"

package com.funnelbase.sdk.flutter

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import com.funnelbase.sdk.Analytics
import com.funnelbase.sdk.TopicsException
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry

/**
 * The Android side of funnelbase_flutter: each call from Dart onto the native SDK's method of the
 * same name, and nothing the SDK does itself.
 *
 * What is here and not in sdk-android is what only a Flutter app needs: starting the SDK from Dart
 * and before Dart ([AnalyticsFlutter]), handing taps to Dart ([TapRelay]), and asking for the
 * notification permission, which the SDK leaves to an app because it has no activity to ask from.
 */
class AnalyticsFlutterPlugin : FlutterPlugin, ActivityAware, AnalyticsHostApi {

    private lateinit var context: Context
    private lateinit var taps: TapRelay
    private var activity: ActivityPluginBinding? = null
    private val newIntents = PluginRegistry.NewIntentListener { intent ->
        taps.take(intent)
        // Not consumed: the app, or another plugin, may route the same intent's deep link.
        false
    }
    private val permissionAnswers = PluginRegistry.RequestPermissionsResultListener { code, _, _ ->
        if (code != PERMISSION_REQUEST) return@RequestPermissionsResultListener false
        answerPermission()
        true
    }
    private val waitingForPermission = mutableListOf<(Result<Boolean>) -> Unit>()

    // --- FlutterPlugin ---

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        taps = TapRelay(context)
        taps.attach(AnalyticsFlutterApi(binding.binaryMessenger))
        AnalyticsHostApi.setUp(binding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        AnalyticsHostApi.setUp(binding.binaryMessenger, null)
        taps.detach()
    }

    // --- ActivityAware ---

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding
        binding.addOnNewIntentListener(newIntents)
        binding.addRequestPermissionsResultListener(permissionAnswers)
        // The intent that started the activity: a cold start from a tapped notification.
        taps.take(binding.activity.intent)
    }

    override fun onDetachedFromActivity() {
        release()
        // A prompt whose activity went away for good will never be answered by it; answer with
        // what the system says now.
        answerPermission()
    }

    /**
     * A rotation: the prompt outlives it, and its answer arrives at the recreated activity, where
     * [onReattachedToActivityForConfigChanges] is listening again.
     */
    override fun onDetachedFromActivityForConfigChanges() = release()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)

    // --- AnalyticsHostApi ---

    override fun initialize(config: AndroidConfigMessage) = AnalyticsFlutter.startFromDart(context, config)

    override fun track(eventName: String, properties: Map<String, Any>) = Analytics.track(eventName, properties)

    override fun screen(screenName: String, properties: Map<String, Any>) = Analytics.screen(screenName, properties)

    override fun identify(userId: String, traits: Map<String, Any>) = Analytics.identify(userId, traits)

    override fun flush() = Analytics.flush()

    override fun reset() = Analytics.reset()

    override fun setPushToken(token: String, kind: String) = Analytics.push.setToken(token, kind)

    override fun refreshPushToken() = Analytics.push.refreshToken()

    override fun notificationsEnabled(): Boolean = Analytics.push.notificationsEnabled()

    override fun registeredPushToken(): String? = Analytics.push.registeredToken()

    /**
     * Android 13's runtime permission, asked from the attached activity. Below 13 there is nothing
     * to ask, and with no activity nowhere to ask from; both answer with what the system says now.
     * The answer is re-registered with the token either way, because the token's `status` is the
     * permission.
     */
    override fun requestNotificationPermission(callback: (Result<Boolean>) -> Unit) {
        val host = activity?.activity
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU || host == null || granted(host)) {
            Analytics.push.refreshToken()
            callback(Result.success(Analytics.push.notificationsEnabled()))
            return
        }
        if (!declared(host)) {
            Log.w(TAG, "POST_NOTIFICATIONS is not in the app's manifest, so Android refuses it without asking")
        }
        waitingForPermission += callback
        if (waitingForPermission.size == 1) {
            host.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), PERMISSION_REQUEST)
        }
    }

    override fun setTopic(key: String, subscribed: Boolean) = Analytics.topics.set(key, subscribed)

    override fun fetchTopics(callback: (Result<List<TopicChoiceMessage>>) -> Unit) {
        Analytics.topics.fetch { result ->
            result.fold(
                onSuccess = { topics ->
                    callback(Result.success(topics.map { TopicChoiceMessage(it.key, it.name, it.description, it.subscribed, it.chosen) }))
                },
                onFailure = { callback(Result.failure(it.toFlutterError())) },
            )
        }
    }

    override fun pushTapsReady() = taps.ready()

    // --- Internals ---

    private fun release() {
        activity?.removeOnNewIntentListener(newIntents)
        activity?.removeRequestPermissionsResultListener(permissionAnswers)
        activity = null
    }

    private fun answerPermission() {
        if (waitingForPermission.isEmpty()) return
        Analytics.push.refreshToken()
        val enabled = Analytics.push.notificationsEnabled()
        val callbacks = waitingForPermission.toList()
        waitingForPermission.clear()
        callbacks.forEach { it(Result.success(enabled)) }
    }

    private fun granted(activity: Activity) =
        activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    private fun declared(activity: Activity): Boolean = runCatching {
        val info = activity.packageManager.getPackageInfo(activity.packageName, PackageManager.GET_PERMISSIONS)
        info.requestedPermissions.orEmpty().contains(Manifest.permission.POST_NOTIFICATIONS)
    }.getOrDefault(true)

    private companion object {
        /** Any number of the app's own would do; this one is unlikely to collide with them. */
        const val PERMISSION_REQUEST = 0x414E
    }
}

/**
 * The native SDK's four reasons, as the codes the Dart side turns back into `TopicsException`s.
 */
internal fun Throwable.toFlutterError(): FlutterError = when (this) {
    is TopicsException.Http -> FlutterError("http", message, status)
    is TopicsException.Network -> FlutterError("network", message, null)
    is TopicsException.Malformed -> FlutterError("malformed", message, null)
    is TopicsException.NotInitialized -> FlutterError("not_initialized", message, null)
    else -> FlutterError("network", message ?: javaClass.simpleName, null)
}

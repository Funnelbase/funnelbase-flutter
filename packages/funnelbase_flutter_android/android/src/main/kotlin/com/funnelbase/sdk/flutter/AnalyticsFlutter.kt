package com.funnelbase.sdk.flutter

import android.content.Context
import android.util.Log
import com.funnelbase.sdk.Analytics

/**
 * Where the native SDK is started, from either of the two paths that may get there first, and the
 * one hook a Flutter app's own Android code needs.
 *
 * The two paths: the content provider at process start, from the configuration Dart last passed,
 * and Dart's `Analytics.initialize`, which on the first launch of an install is the only one. The
 * native SDK accepts one `initialize` per process, so this decides which runs and what the other
 * does:
 * - nothing started yet → start now, and keep the configuration for the next process;
 * - started with the same configuration → nothing;
 * - started with a different one (a rotated key, a new endpoint) → keep it for the next process,
 *   and say so: the SDK cannot be restarted under a queue it is writing.
 */
object AnalyticsFlutter {

    private val lock = Any()
    private var startedWith: AndroidConfigMessage? = null
    private var context: Context? = null
    private val waiting = mutableListOf<(Context) -> Unit>()

    /**
     * Runs [block] once the native SDK is initialised — at once if it already is, on this thread;
     * otherwise on the thread that initialises it.
     *
     * For an app's own Android code that calls the native SDK, which may not run before it is
     * initialised and cannot know which path will initialise it. The case it exists for is
     * Firebase's token, which `sdk-android-fcm` registers on request:
     *
     * ```kotlin
     * class MainApplication : Application() {
     *     override fun onCreate() {
     *         super.onCreate()
     *         AnalyticsFlutter.doOnInitialized { AnalyticsMessagingService.registerCurrentToken(it) }
     *     }
     * }
     * ```
     */
    @JvmStatic
    fun doOnInitialized(block: (Context) -> Unit) {
        val ready = synchronized(lock) {
            context ?: run {
                waiting += block
                null
            }
        }
        ready?.let(block)
    }

    /** The content provider's path: the stored configuration, if Dart has ever passed one. */
    internal fun startFromStore(context: Context) {
        val stored = ConfigStore.read(context) ?: return
        start(context, stored)
    }

    /** Dart's path. */
    internal fun startFromDart(context: Context, config: AndroidConfigMessage) {
        ConfigStore.write(context, config)
        val current = synchronized(lock) { startedWith }
        when (current) {
            null -> start(context, config)
            config -> Unit
            else -> Log.w(
                TAG,
                "Analytics was started with a different configuration when this process began; the new one " +
                    "takes effect at the next launch",
            )
        }
    }

    private fun start(context: Context, config: AndroidConfigMessage) {
        val native = config.toNativeConfig(context) ?: return
        val application = context.applicationContext
        val toRun = synchronized(lock) {
            if (startedWith != null) return
            Analytics.initialize(application, native)
            startedWith = config
            this.context = application
            waiting.toList().also { waiting.clear() }
        }
        toRun.forEach { block ->
            runCatching { block(application) }.onFailure { Log.w(TAG, "A doOnInitialized block failed: ${it.message}") }
        }
    }
}

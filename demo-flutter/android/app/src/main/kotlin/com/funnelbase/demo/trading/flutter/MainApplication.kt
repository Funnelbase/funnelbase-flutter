package com.funnelbase.demo.trading.flutter

import android.app.Application
import android.util.Log
import com.funnelbase.sdk.flutter.AnalyticsFlutter
import com.funnelbase.sdk.fcm.AnalyticsMessagingService

/**
 * The one piece of push setup that has to be native: asking Firebase for this install's token.
 *
 * `onNewToken` fires only when a token *changes*, so an install whose token was issued before the app
 * had analytics would never register it otherwise — demo-android asks once per launch for the same
 * reason. It waits for the SDK: on most launches funnelbase_flutter_android starts it before this runs,
 * from the configuration Dart last passed, but on an install's first launch only Dart's
 * `Analytics.initialize` does, later. Without a Firebase project there is nothing to ask, and the glue
 * says so rather than failing.
 */
class MainApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        AnalyticsFlutter.doOnInitialized { context ->
            runCatching { AnalyticsMessagingService.registerCurrentToken(context) }
                .onFailure { Log.w(TAG, "Could not ask Firebase for a push token: ${it.message}") }
        }
    }

    private companion object {
        const val TAG = "TradeDemo"
    }
}

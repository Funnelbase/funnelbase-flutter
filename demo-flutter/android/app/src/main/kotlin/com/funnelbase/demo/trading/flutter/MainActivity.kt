package com.funnelbase.demo.trading.flutter

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import com.funnelbase.sdk.Analytics
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The app's single Activity, and the demo's own native channel, `trade_demo/native`.
 *
 * The channel exists for the two things on the Notifications screens that are native by nature and
 * belong to no SDK API:
 * - **deliverPush** hands a simulated payload to `Analytics.push.handleMessage`, exactly as the
 *   Firebase glue hands a real one, so the notification, its image and buttons, `$push_received` and
 *   the tap are the SDK's real ones (demo-android's simulate buttons, docs/demo-app.md "Push");
 * - **openNotificationSettings** opens the system screen where the app's notifications, and the SDK's
 *   channel, are switched back on.
 */
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "trade_demo/native").setMethodCallHandler { call, result ->
            when (call.method) {
                "deliverPush" -> {
                    @Suppress("UNCHECKED_CAST")
                    val data = (call.arguments as? Map<String, String>).orEmpty()
                    // False before Analytics.initialize, which the SDK also logs.
                    result.success(Analytics.push.handleMessage(data))
                }
                "openNotificationSettings" -> {
                    startActivity(
                        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                            .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            .setData(Uri.fromParts("package", packageName, null))
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}

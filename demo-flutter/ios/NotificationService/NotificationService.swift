import FunnelbaseNotificationService

/// The whole of the extension, as in demo-ios.
///
/// Everything a notification service extension does for this platform's pushes — the receipt, the
/// buttons, the image — is in sdk-ios, because none of it is app-specific, and none of it is
/// Flutter's: the extension is its own process, where no Dart runs (docs/sdk-flutter.md, "Push").
/// What the app supplies is the app group, which lets a receipt recorded here reach the app's upload
/// queue and be sent under the app's identity. It must match `DemoConfig.appGroup` in lib/config.dart
/// and both targets' entitlements.
///
/// The app group and `aps-environment` are entitlements, so a build for a device needs a developer
/// team to sign (ios/Flutter/Signing.example.xcconfig). A simulator build needs neither.
class NotificationService: AnalyticsNotificationService {

    override var appGroup: String? { "group.com.analytics.demo.trading.flutter" }

    // A laptop's fake provider serves the image over plain http, and Apple's transport security
    // would otherwise refuse it here even though the Info.plist allows local networking.
    override var allowInsecureImages: Bool { true }
}

import Funnelbase
import Flutter
import UIKit
import UserNotifications
import funnelbase_flutter_ios

/// The app delegate, and the demo's own native channel, `trade_demo/native`.
///
/// `AnalyticsFlutter.didFinishLaunching()` comes first, before `super`: under the scene lifecycle
/// plugins register when the engine starts, which can be after Apple delivers the tap that launched
/// the app — this starts the SDK from the last launch's configuration and installs the package's
/// notification-center delegate in time (funnelbase_flutter_ios). The demo sets no delegate of its own
/// after it, which would replace that one.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    AnalyticsFlutter.didFinishLaunching()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TradeDemoNative") else { return }
    FlutterMethodChannel(name: "trade_demo/native", binaryMessenger: registrar.messenger())
      .setMethodCallHandler(TradeDemoNative.handle)
  }
}

/// The two things on the Notifications screens that are native by nature and belong to no SDK API.
///
/// - **deliverPush** posts a simulated payload as a local notification, as demo-ios's PushSimulation
///   does. Nothing local can make iOS run a notification service extension, so the image and the
///   `$push_received` receipt — the extension's work — are missing; the text, the buttons and the
///   tap, which the SDK reports as `$push_opened`, are real.
/// - **openNotificationSettings** opens this app's page in the Settings app.
enum TradeDemoNative {

  static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "deliverPush":
      let data = (call.arguments as? [String: String]) ?? [:]
      result(post(data))
    case "openNotificationSettings":
      if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
        UIApplication.shared.open(url)
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Posts one, a few seconds from now so the banner can be seen after backgrounding the app.
  ///
  /// `NotificationPlan` is the SDK's own decision about what a push becomes, and the extension builds
  /// a real one from exactly this — so the category here is the one a real delivery of the same
  /// payload would use, and the buttons are registered under it the same way.
  private static func post(_ data: [String: String]) -> Bool {
    guard let payload = PushParser.parse(data) else { return false }
    let plan = NotificationPlan.of(payload, allowInsecureImages: true)

    let content = UNMutableNotificationContent()
    content.title = payload.title
    content.body = payload.body
    content.sound = .default
    content.userInfo = data
    if let thread = plan.threadIdentifier {
      content.threadIdentifier = thread
    }
    if let category = plan.categoryIdentifier {
      register(buttons: plan.buttons, under: category)
      content.categoryIdentifier = category
    }

    // A collapse key replaces: the request identifier is what the system de-duplicates on.
    let request = UNNotificationRequest(
      identifier: payload.collapseKey ?? payload.deliveryId,
      content: content,
      trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
    )
    UNUserNotificationCenter.current().add(request)
    return true
  }

  /// Existing categories are kept: the app's own must not be lost to a simulated campaign.
  private static func register(buttons: [PushButton], under identifier: String) {
    let center = UNUserNotificationCenter.current()
    let actions = buttons.map { UNNotificationAction(identifier: $0.id, title: $0.title, options: [.foreground]) }
    let category = UNNotificationCategory(identifier: identifier, actions: actions, intentIdentifiers: [], options: [])
    center.getNotificationCategories { existing in
      var categories = existing.filter { $0.identifier != identifier }
      categories.insert(category)
      center.setNotificationCategories(categories)
    }
  }
}

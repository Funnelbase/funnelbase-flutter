import Funnelbase
import UIKit
import UserNotifications

/// The one call an app makes natively, from its app delegate, before anything else:
///
/// ```swift
/// override func application(
///     _ application: UIApplication,
///     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
/// ) -> Bool {
///     AnalyticsFlutter.didFinishLaunching()
///     return super.application(application, didFinishLaunchingWithOptions: launchOptions)
/// }
/// ```
///
/// It is what makes the tap that launched the app safe under the scene lifecycle. Apple delivers
/// that tap to whatever is the notification center's delegate once launching finishes. A Flutter app
/// on `FlutterImplicitEngineDelegate` registers its plugins when the engine starts, which can be
/// later than that — so the plugin, and FlutterAppDelegate's forwarding to it, may not exist yet,
/// and the open is never reported. This starts the SDK from the last launch's configuration and
/// makes a delegate of the package's own the center's delegate, both before `didFinishLaunching`
/// returns.
///
/// An app that never calls it still works as before: the plugin starts the SDK when it is
/// registered and hears taps through FlutterAppDelegate. Only a tap that arrives before the engine
/// starts is at risk without it. funnelbase_flutter_android's `AnalyticsFlutter` is the Android
/// mirror (docs/sdk-flutter.md).
public enum AnalyticsFlutter {

    /// Call from `application(_:didFinishLaunchingWithOptions:)`, before `super`. Safe to call more
    /// than once; only the first does anything.
    public static func didFinishLaunching() {
        ConfigStore.startFromLastConfig()
        NotificationProxy.install()
    }
}

/// Taps of ours, in the order they happened, waiting for a plugin to hand them to Dart.
///
/// Process-wide rather than the plugin's, because the delegate that hears a tap can exist before
/// any plugin does. Main thread only.
enum TapRelay {

    private static var held: [PushTapMessage] = []
    private static var sink: ((PushTapMessage) -> Void)?

    /// Responses already answered, so a tap heard twice — by the proxy and again by the plugin
    /// through FlutterAppDelegate, when some other delegate in between forwards to both — reports
    /// one open. The last few are enough: the same response is delivered within moments.
    private static var answered: [String] = []

    /// The plugin that delivers taps to Dart. Whatever was held is delivered to it at once.
    static func attach(_ deliver: @escaping (PushTapMessage) -> Void) {
        sink = deliver
        let waiting = held
        held.removeAll()
        waiting.forEach(deliver)
    }

    /// Reports the open and queues the tap for Dart. False, having done nothing, when the push is
    /// not ours — another sender's notification is left to whoever sent it. True for ours, including
    /// a dismissal (reported as nothing, and leading nowhere) and a response already answered.
    static func handle(_ response: UNNotificationResponse) -> Bool {
        let request = response.notification.request
        let key = "\(request.identifier)|\(response.actionIdentifier)|\(response.notification.date.timeIntervalSince1970)"
        if answered.contains(key) { return PushParser.parse(request.content.userInfo) != nil }

        guard let payload = Analytics.push.handle(response: response) else { return false }
        answered.append(key)
        if answered.count > 16 { answered.removeFirst() }

        guard response.actionIdentifier != UNNotificationDismissActionIdentifier else { return true }
        let actionId = response.actionIdentifier == UNNotificationDefaultActionIdentifier ? nil : response.actionIdentifier
        let tap = PushTapMessage(payload: Messages.payload(payload), actionId: actionId)
        if let sink { sink(tap) } else { held.append(tap) }
        return true
    }

    static func isOurs(_ notification: UNNotification) -> Bool {
        PushParser.parse(notification.request.content.userInfo) != nil
    }
}

/// The notification center's delegate while the app runs, installed by
/// `AnalyticsFlutter.didFinishLaunching`: it answers our pushes itself and passes everything else to
/// the delegate it replaced, or to FlutterAppDelegate, which forwards to every plugin — so another
/// plugin's notifications behave exactly as if this were not here.
final class NotificationProxy: NSObject, UNUserNotificationCenterDelegate {

    /// Held here because the center holds its delegate weakly.
    private static var shared: NotificationProxy?

    static var isInstalled: Bool { shared != nil }

    /// The delegate before this one — usually nil this early, the app delegate if the app set it.
    private weak var next: UNUserNotificationCenterDelegate?

    private init(next: UNUserNotificationCenterDelegate?) {
        self.next = next
    }

    static func install() {
        guard shared == nil else { return }
        let center = UNUserNotificationCenter.current()
        let proxy = NotificationProxy(next: center.delegate)
        shared = proxy
        center.delegate = proxy
    }

    /// Where a push that is not ours goes: the replaced delegate, else the app delegate when it is
    /// one (FlutterAppDelegate is, and forwards to the plugins).
    private var forwardee: UNUserNotificationCenterDelegate? {
        if let next, next !== self { return next }
        guard let app = UIApplication.shared.delegate as? UNUserNotificationCenterDelegate, app !== self else { return nil }
        return app
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if TapRelay.handle(response) {
            completionHandler()
            return
        }
        if let forwardee, forwardee.responds(to: #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:))) {
            forwardee.userNotificationCenter?(center, didReceive: response, withCompletionHandler: completionHandler)
        } else {
            completionHandler()
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if TapRelay.isOurs(notification) {
            // Shown in the foreground as in the background. No receipt from here: the notification
            // service extension reports it for every campaign push, whatever the app is doing.
            completionHandler([.banner, .sound, .list])
            return
        }
        if let forwardee, forwardee.responds(to: #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:willPresent:withCompletionHandler:))) {
            forwardee.userNotificationCenter?(center, willPresent: notification, withCompletionHandler: completionHandler)
        } else {
            // What the system does with no delegate at all: nothing shown in the foreground.
            completionHandler([])
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, openSettingsFor notification: UNNotification?) {
        guard let forwardee, forwardee.responds(to: #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:openSettingsFor:))) else { return }
        forwardee.userNotificationCenter?(center, openSettingsFor: notification)
    }
}

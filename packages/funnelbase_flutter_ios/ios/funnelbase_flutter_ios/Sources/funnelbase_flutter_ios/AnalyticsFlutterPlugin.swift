import Funnelbase
import Flutter
import UIKit
import UserNotifications

/// The iOS half of funnelbase_flutter: every call from Dart onto `sdk-ios`'s own method of the same
/// name, and the three things a Flutter app cannot do from Dart — be started by a tap before any
/// Dart runs, receive Apple's token, and hear about a tap (docs/sdk-flutter.md).
///
/// It holds no analytics logic. The queue, the session, the identity and the push rules are the
/// native SDK's, which is the point of wrapping it: a Flutter app sends exactly what a native one
/// does, and a fix to the contract reaches it without a line changed here.
public final class AnalyticsFlutterPlugin: NSObject, FlutterPlugin {

    /// The plugin that answers notification callbacks. An app with more than one engine registers
    /// the plugin once per engine, and every registered plugin hears every callback — so only the
    /// first one acts, or one tap would report two opens.
    private static weak var primary: AnalyticsFlutterPlugin?

    private let flutterApi: AnalyticsFlutterApi
    private var dartListening = false
    private var heldTaps: [PushTapMessage] = []

    init(flutterApi: AnalyticsFlutterApi) {
        self.flutterApi = flutterApi
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        // First, before anything can call into the SDK: a tap that launched the app is answered by
        // the native SDK, and Dart has not run yet. See `ConfigStore`.
        ConfigStore.startFromLastConfig()

        let plugin = AnalyticsFlutterPlugin(flutterApi: AnalyticsFlutterApi(binaryMessenger: registrar.messenger()))
        AnalyticsHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: plugin)
        registrar.addApplicationDelegate(plugin)
        if primary == nil {
            primary = plugin
            // Taps heard before this plugin existed — by `AnalyticsFlutter`'s delegate, during
            // launch — are waiting in the relay, and come through here from now on.
            TapRelay.attach { [weak plugin] tap in plugin?.deliver(tap) }
        }

        // FlutterAppDelegate is a notification center delegate that forwards every callback to the
        // plugins registered above — but only once something makes it the center's delegate. If
        // nothing has, it is made one here. An app (or firebase_messaging) that sets a delegate of
        // its own keeps it, and must forward to FlutterAppDelegate for taps to reach this plugin.
        //
        // That is the path for an app that does not call `AnalyticsFlutter.didFinishLaunching`, and
        // under the scene lifecycle it is late: plugins are registered when the engine starts, after
        // launching may have finished, and a tap that launched the app can be delivered to nobody.
        // The hook installs a delegate of the package's own before then, and this is skipped.
        let center = UNUserNotificationCenter.current()
        if center.delegate == nil, let appDelegate = UIApplication.shared.delegate as? UNUserNotificationCenterDelegate {
            center.delegate = appDelegate
        }
    }

    // MARK: - Taps

    private func deliver(_ tap: PushTapMessage) {
        guard dartListening else {
            heldTaps.append(tap)
            return
        }
        flutterApi.onPushTapped(tap: tap) { result in
            if case .failure(let error) = result {
                print("[Analytics] A tap could not be handed to Dart: \(error.message ?? error.code)")
            }
        }
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // With `AnalyticsFlutter`'s delegate installed, our pushes are answered there and never
        // forwarded, so what reaches this is normally someone else's. Not taken on trust: another
        // delegate placed in front of both may hand the same response to each, and an open
        // reported twice is a wrong number on the campaign report — so the relay remembers the
        // responses it answered and answers each once, whichever path hears it first.
        guard Self.primary === self else { return }
        // The relay reports the open and queues the tap, or returns false when the push is not
        // ours — another sender's notification is left to whoever sent it, completion included.
        guard TapRelay.handle(response) else { return }
        completionHandler()
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        guard Self.primary === self, !NotificationProxy.isInstalled, TapRelay.isOurs(notification) else { return }
        // Shown in the foreground as it would be in the background. No receipt from here, on
        // purpose: on Apple devices the receipt belongs to the notification service extension,
        // which the system runs for every campaign push whatever the app is doing — reporting it
        // again would count one delivery twice.
        completionHandler([.banner, .sound, .list])
    }

    // MARK: - Apple's token

    public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Only when the app said this deployment talks to Apple directly. An app on Firebase is
        // issued an APNs token too — Firebase asks for one — and registering it would replace the
        // Firebase token this install is reached by.
        guard ConfigStore.running?.registerApnsToken == true else { return }
        Analytics.push.setAPNSToken(deviceToken)
    }

    public func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // A simulator with no push support and a build with no provisioning both land here, and
        // neither is a reason to stop: a token can still be registered by hand from Dart.
        guard ConfigStore.running?.registerApnsToken == true else { return }
        print("[Analytics] APNs would not issue a token: \(error.localizedDescription)")
    }
}

// MARK: - The host API

extension AnalyticsFlutterPlugin: AnalyticsHostApi {

    func initialize(config: IosConfigMessage) throws {
        ConfigStore.initializeFromDart(StoredConfig(config))
    }

    func track(eventName: String, properties: [String: Any]) throws {
        Analytics.track(eventName, properties: Values.native(properties))
    }

    func screen(screenName: String, properties: [String: Any]) throws {
        Analytics.screen(screenName, properties: Values.native(properties))
    }

    func identify(userId: String, traits: [String: Any]) throws {
        Analytics.identify(userId, traits: Values.native(traits))
    }

    func flush() throws {
        Analytics.flush()
    }

    func reset() throws {
        Analytics.reset()
    }

    func setPushToken(token: String, kind: String) throws {
        Analytics.push.setToken(token, kind: kind)
    }

    func refreshPushToken() throws {
        Analytics.push.refreshToken()
    }

    func notificationsEnabled(completion: @escaping (Result<Bool, Error>) -> Void) {
        // Apple answers on a queue of its own; a channel reply belongs on the main thread.
        Analytics.push.notificationsEnabled { allowed in
            DispatchQueue.main.async { completion(.success(allowed)) }
        }
    }

    func registeredPushToken() throws -> String? {
        Analytics.push.registeredToken()
    }

    func requestNotificationPermission(completion: @escaping (Result<Bool, Error>) -> Void) {
        // The SDK registers the answer and, on a yes, registers for remote notifications.
        Analytics.push.requestAuthorization { granted in
            DispatchQueue.main.async { completion(.success(granted)) }
        }
    }

    func setTopic(key: String, subscribed: Bool) throws {
        Analytics.topics.set(key, subscribed: subscribed)
    }

    func fetchTopics(completion: @escaping (Result<[TopicChoiceMessage], Error>) -> Void) {
        Analytics.topics.fetch { result in
            completion(result.map { $0.map(Messages.topic) }.mapError(Messages.topicsError))
        }
    }

    func pushTapsReady() throws {
        dartListening = true
        let held = heldTaps
        heldTaps.removeAll()
        held.forEach(deliver)
    }
}

// MARK: - Values

/// Property values as the SDK has to see them.
enum Values {

    /// A map from the channel, with every number made the Swift type it was in Dart.
    ///
    /// The standard codec hands a Dart `int`, `double` and `bool` over alike, as `NSNumber`, and
    /// Swift's `as? Bool` succeeds on an `NSNumber` holding 0 or 1 — so the SDK, which tries `Bool`
    /// before `Int`, would send a Dart `1` as JSON `true` and lose the column it belongs in. The
    /// number's own Core Foundation type says which it was.
    static func native(_ map: [String: Any]) -> [String: Any?] {
        map.mapValues { value -> Any? in
            guard let number = value as? NSNumber else { return value }
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return number.boolValue }
            if CFNumberIsFloatType(number) { return number.doubleValue }
            return number.intValue
        }
    }
}

// MARK: - Messages

/// The native SDK's types as the channel carries them.
enum Messages {

    static func payload(_ payload: PushPayload) -> PushPayloadMessage {
        PushPayloadMessage(
            deliveryId: payload.deliveryId,
            runId: payload.runId,
            title: payload.title,
            body: payload.body,
            imageUrl: payload.imageUrl,
            deepLink: payload.deepLink,
            collapseKey: payload.collapseKey,
            buttons: payload.buttons.map { PushButtonMessage(id: $0.id, title: $0.title, deepLink: $0.deepLink) },
            data: payload.data
        )
    }

    static func topic(_ choice: TopicChoice) -> TopicChoiceMessage {
        TopicChoiceMessage(
            key: choice.key,
            name: choice.name,
            topicDescription: choice.description,
            subscribed: choice.subscribed,
            chosen: choice.chosen
        )
    }

    /// `TopicsError`'s four cases as the codes Dart maps back to `TopicsException`.
    static func topicsError(_ error: Error) -> Error {
        switch error as? TopicsError {
        case .http(let status):
            return PigeonError(code: "http", message: "HTTP \(status)", details: status)
        case .network(let message):
            return PigeonError(code: "network", message: message, details: nil)
        case .malformed:
            return PigeonError(code: "malformed", message: "Unreadable topics response", details: nil)
        case .notInitialized:
            return PigeonError(code: "not_initialized", message: "Analytics.initialize has not been called", details: nil)
        case nil:
            return PigeonError(code: "network", message: error.localizedDescription, details: nil)
        }
    }
}

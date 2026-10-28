import Funnelbase
import Foundation
import UIKit

/// The configuration Dart passed, as it is kept between launches. Codable and Equatable so a launch
/// can tell whether Dart asked for what is already running.
struct StoredConfig: Codable, Equatable {
    var apiKey: String
    var endpoint: String
    var flushIntervalSeconds: Int
    var flushBatchSize: Int
    var maxQueuedEvents: Int
    var sessionTimeoutMinutes: Double
    var trackApplicationLifecycle: Bool
    var debugLogging: Bool
    var appGroup: String?
    var registerApnsToken: Bool

    init(_ message: IosConfigMessage) {
        apiKey = message.apiKey
        endpoint = message.endpoint
        flushIntervalSeconds = Int(message.flushIntervalSeconds)
        flushBatchSize = Int(message.flushBatchSize)
        maxQueuedEvents = Int(message.maxQueuedEvents)
        sessionTimeoutMinutes = message.sessionTimeoutMinutes
        trackApplicationLifecycle = message.trackApplicationLifecycle
        debugLogging = message.debugLogging
        appGroup = message.appGroup
        registerApnsToken = message.registerApnsToken
    }

    var native: AnalyticsConfig {
        AnalyticsConfig(
            apiKey: apiKey,
            endpoint: endpoint,
            flushIntervalSeconds: TimeInterval(flushIntervalSeconds),
            flushBatchSize: flushBatchSize,
            maxQueuedEvents: maxQueuedEvents,
            sessionTimeoutMinutes: sessionTimeoutMinutes,
            trackApplicationLifecycle: trackApplicationLifecycle,
            debugLogging: debugLogging,
            appGroup: appGroup
        )
    }
}

/// Starts the native SDK before Dart can, from the configuration Dart passed last time.
///
/// A Flutter app's Dart runs only once its engine has started, and a native app initialises in
/// `didFinishLaunching`. The gap matters for push: a tap that launches the app is answered by the
/// native SDK, which reports the open — and an SDK not yet initialised reports nothing. So the last
/// configuration Dart passed is kept in the app's own defaults, and the plugin starts the SDK with
/// it as soon as it is registered, before Dart's first frame.
///
/// The cost is that a changed configuration — a rotated key — takes effect at the next launch, not
/// at the `initialize` that passed it: the SDK starts once per process. It is said so in the log.
///
/// The app's own defaults rather than the app group's, like the SDK's identity: a group container
/// survives the app being deleted, and a reinstall is a new install (funnelbase-ios, docs/sdk-ios.md).
enum ConfigStore {

    // The package's name before it was Funnelbase; kept, so an installed app keeps its config.
    private static let key = "analytics_flutter.config"
    private static let lock = NSLock()

    /// The configuration the SDK is running with in this process, or nil before it starts.
    private(set) static var running: StoredConfig? {
        get { lock.lock(); defer { lock.unlock() }; return _running }
        set { lock.lock(); _running = newValue; lock.unlock() }
    }
    private static var _running: StoredConfig?

    /// At plugin registration: starts the SDK with the configuration of the last launch, if there
    /// was one. Nothing on the very first launch — Dart's `initialize` is then the start.
    static func startFromLastConfig() {
        guard running == nil, let stored = load() else { return }
        if stored.debugLogging { print("[Analytics] Started before Dart, with the last launch's configuration") }
        start(stored)
    }

    /// Dart's `initialize`.
    static func initializeFromDart(_ config: StoredConfig) {
        guard let current = running else {
            save(config)
            start(config)
            return
        }
        guard current != config else { return }
        save(config)
        print("[Analytics] initialize was given a different configuration than this launch started with — "
            + "it is saved, and takes effect at the next launch")
    }

    private static func start(_ config: StoredConfig) {
        running = config
        Analytics.initialize(config.native)
        if config.registerApnsToken { registerIfAlreadyAllowed() }
    }

    /// Asks APNs for this install's token on every launch, when the person has already allowed
    /// notifications. A token can be reissued without the app being told, and asking is free when
    /// permission is granted: no prompt is shown.
    private static func registerIfAlreadyAllowed() {
        Analytics.push.notificationsEnabled { allowed in
            guard allowed else { return }
            DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
        }
    }

    private static func load() -> StoredConfig? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(StoredConfig.self, from: data)
    }

    private static func save(_ config: StoredConfig) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

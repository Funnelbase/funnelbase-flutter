import 'package:flutter/services.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'types.dart';

/// What a platform package implements: every call `funnelbase_flutter` makes, one to one onto the
/// native SDK's own method of the same name.
///
/// Values arrive already checked and encoded. A property map holds only strings, numbers and
/// booleans — dates are ISO text by then, nulls are gone — so an implementation passes it to the
/// native SDK as it is, and never has a second rule for what a value may be.
///
/// The default instance throws a [MissingPluginException] from every method: the SDK runs on
/// Android and iOS only, and a build for anything else should fail where it is tested rather than
/// collect nothing in silence (docs/sdk-flutter.md, "Platforms").
abstract class AnalyticsPlatform extends PlatformInterface {
  AnalyticsPlatform() : super(token: _token);

  static final Object _token = Object();

  static AnalyticsPlatform _instance = _UnsupportedPlatform();

  /// The implementation in use. A platform package sets it from its `registerWith`.
  static AnalyticsPlatform get instance => _instance;

  static set instance(AnalyticsPlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  /// Starts the native SDK, and remembers [config] for the next process start (see the platform
  /// packages: a push or a tap can start the process before any Dart runs).
  Future<void> initialize(AnalyticsConfig config);

  Future<void> track(String eventName, Map<String, Object> properties);

  Future<void> screen(String screenName, Map<String, Object> properties);

  Future<void> identify(String userId, Map<String, Object> traits);

  Future<void> flush();

  Future<void> reset();

  Future<void> setPushToken(String token, String kind);

  Future<void> refreshPushToken();

  Future<bool> notificationsEnabled();

  Future<String?> registeredPushToken();

  /// Asks for permission to post notifications, and re-registers the token with the answer.
  Future<bool> requestNotificationPermission();

  Future<void> setTopic(String key, bool subscribed);

  /// Throws a [TopicsException].
  Future<List<TopicChoice>> fetchTopics();

  /// Every tapped notification, including the one that started the app. A tap that arrives before
  /// anything listens is held and delivered to the first listener.
  Stream<PushTap> get pushTaps;
}

final class _UnsupportedPlatform extends AnalyticsPlatform {
  static MissingPluginException _error() => MissingPluginException(
        'funnelbase_flutter runs on Android and iOS only (docs/sdk-flutter.md). '
        'Guard the calls on other platforms if the app builds for them.',
      );

  Never _unsupported() => throw _error();

  @override
  Future<void> initialize(AnalyticsConfig config) async => _unsupported();

  @override
  Future<void> track(String eventName, Map<String, Object> properties) async => _unsupported();

  @override
  Future<void> screen(String screenName, Map<String, Object> properties) async => _unsupported();

  @override
  Future<void> identify(String userId, Map<String, Object> traits) async => _unsupported();

  @override
  Future<void> flush() async => _unsupported();

  @override
  Future<void> reset() async => _unsupported();

  @override
  Future<void> setPushToken(String token, String kind) async => _unsupported();

  @override
  Future<void> refreshPushToken() async => _unsupported();

  @override
  Future<bool> notificationsEnabled() async => _unsupported();

  @override
  Future<String?> registeredPushToken() async => _unsupported();

  @override
  Future<bool> requestNotificationPermission() async => _unsupported();

  @override
  Future<void> setTopic(String key, bool subscribed) async => _unsupported();

  @override
  Future<List<TopicChoice>> fetchTopics() async => _unsupported();

  @override
  Stream<PushTap> get pushTaps => Stream.error(_error());
}

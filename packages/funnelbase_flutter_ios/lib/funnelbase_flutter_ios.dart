/// The iOS implementation of funnelbase_flutter: each call onto `sdk-ios` through a Pigeon channel
/// (docs/sdk-flutter.md). Apps do not import this package; funnelbase_flutter selects it.
library;

import 'dart:async';

import 'package:funnelbase_flutter_platform_interface/funnelbase_flutter_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'src/messages.g.dart';

/// [AnalyticsPlatform] on iOS.
class AnalyticsIOS extends AnalyticsPlatform {
  /// [hostApi] and [setUpFlutterApi] are for tests; an app gets the real channel.
  AnalyticsIOS({
    @visibleForTesting AnalyticsHostApi? hostApi,
    @visibleForTesting void Function(AnalyticsFlutterApi api)? setUpFlutterApi,
  })  : _host = hostApi ?? AnalyticsHostApi(),
        _setUpFlutterApi = setUpFlutterApi ?? AnalyticsFlutterApi.setUp;

  /// Called by Flutter's plugin registrant when the app starts on iOS.
  static void registerWith() {
    AnalyticsPlatform.instance = AnalyticsIOS();
  }

  final AnalyticsHostApi _host;
  final void Function(AnalyticsFlutterApi api) _setUpFlutterApi;

  // Taps wait twice, once on each side. The plugin holds them until Dart can take them, which is
  // once this side is listening on the channel ([_wireTaps]); this side holds them until the app
  // listens to [pushTaps], which may be several frames later — a cold start's tap arrives while the
  // first screen is still being built.
  final List<PushTap> _held = [];
  late final StreamController<PushTap> _taps = StreamController.broadcast(onListen: _release);
  bool _tapsWired = false;

  void _release() {
    final held = List.of(_held);
    _held.clear();
    held.forEach(_taps.add);
  }

  void _onTap(PushTap tap) {
    if (_taps.hasListener) {
      _taps.add(tap);
    } else {
      _held.add(tap);
    }
  }

  /// Opens the native side's held taps to this one, once: at [initialize] or at the first look at
  /// [pushTaps], whichever is first.
  void _wireTaps() {
    if (_tapsWired) return;
    _tapsWired = true;
    _setUpFlutterApi(_TapReceiver(_onTap));
    _host.pushTapsReady().catchError((Object error) => debugPrint('[Analytics] Taps were not wired: $error'));
  }

  @override
  Future<void> initialize(AnalyticsConfig config) async {
    _wireTaps();
    await _host.initialize(configMessage(config));
  }

  @override
  Future<void> track(String eventName, Map<String, Object> properties) => _host.track(eventName, properties);

  @override
  Future<void> screen(String screenName, Map<String, Object> properties) => _host.screen(screenName, properties);

  @override
  Future<void> identify(String userId, Map<String, Object> traits) => _host.identify(userId, traits);

  @override
  Future<void> flush() => _host.flush();

  @override
  Future<void> reset() => _host.reset();

  @override
  Future<void> setPushToken(String token, String kind) => _host.setPushToken(token, kind);

  @override
  Future<void> refreshPushToken() => _host.refreshPushToken();

  @override
  Future<bool> notificationsEnabled() => _host.notificationsEnabled();

  @override
  Future<String?> registeredPushToken() => _host.registeredPushToken();

  @override
  Future<bool> requestNotificationPermission() => _host.requestNotificationPermission();

  @override
  Future<void> setTopic(String key, bool subscribed) => _host.setTopic(key, subscribed);

  @override
  Future<List<TopicChoice>> fetchTopics() async {
    try {
      final topics = await _host.fetchTopics();
      return topics.map(topicChoice).toList();
    } on PlatformException catch (error) {
      throw topicsException(error);
    }
  }

  @override
  Stream<PushTap> get pushTaps {
    _wireTaps();
    return _taps.stream;
  }
}

class _TapReceiver implements AnalyticsFlutterApi {
  _TapReceiver(this._onTap);

  final void Function(PushTap tap) _onTap;

  @override
  void onPushTapped(PushTapMessage tap) => _onTap(pushTap(tap));
}

/// [AnalyticsConfig] as the channel carries it: the common fields and [IosOptions], flat.
@visibleForTesting
IosConfigMessage configMessage(AnalyticsConfig config) => IosConfigMessage(
      apiKey: config.apiKey,
      endpoint: config.endpoint,
      flushIntervalSeconds: config.flushIntervalSeconds,
      flushBatchSize: config.flushBatchSize,
      maxQueuedEvents: config.maxQueuedEvents,
      sessionTimeoutMinutes: config.sessionTimeoutMinutes,
      trackApplicationLifecycle: config.trackApplicationLifecycle,
      debugLogging: config.debugLogging,
      appGroup: config.ios.appGroup,
      registerApnsToken: config.ios.registerApnsToken,
    );

@visibleForTesting
PushTap pushTap(PushTapMessage message) {
  final payload = message.payload;
  return PushTap(
    payload: PushPayload(
      deliveryId: payload.deliveryId,
      runId: payload.runId,
      title: payload.title,
      body: payload.body,
      imageUrl: payload.imageUrl,
      deepLink: payload.deepLink,
      collapseKey: payload.collapseKey,
      buttons: [
        for (final button in payload.buttons) PushButton(id: button.id, title: button.title, deepLink: button.deepLink),
      ],
      data: payload.data,
    ),
    actionId: message.actionId,
  );
}

@visibleForTesting
TopicChoice topicChoice(TopicChoiceMessage message) => TopicChoice(
      key: message.key,
      name: message.name,
      description: message.topicDescription,
      subscribed: message.subscribed,
      chosen: message.chosen,
    );

/// The plugin's error codes, back to `TopicsError`'s four cases.
@visibleForTesting
TopicsException topicsException(PlatformException error) {
  final message = error.message ?? error.code;
  return switch (error.code) {
    'http' => TopicsHttpException(error.details is int ? error.details as int : 0, message),
    'malformed' => TopicsMalformedException(message),
    'not_initialized' => const TopicsNotInitializedException(),
    _ => TopicsNetworkException(message),
  };
}

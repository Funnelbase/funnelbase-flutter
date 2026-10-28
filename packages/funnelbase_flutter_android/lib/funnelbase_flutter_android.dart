/// The Android implementation of funnelbase_flutter: every call onto `sdk-android` through a Pigeon
/// channel (pigeons/messages.dart). Apps never import this; Flutter registers it for Android.
library;

import 'dart:async';

import 'package:funnelbase_flutter_platform_interface/funnelbase_flutter_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'src/messages.g.dart';

/// [AnalyticsPlatform] on Android. A one-to-one translation: no rule of the SDK's lives here.
class AnalyticsAndroid extends AnalyticsPlatform {
  /// [hostApi] is the channel to Kotlin; tests pass a fake.
  AnalyticsAndroid({@visibleForTesting AnalyticsHostApi? hostApi}) : _host = hostApi ?? AnalyticsHostApi();

  /// Called by Flutter's plugin registrant on Android.
  static void registerWith() {
    AnalyticsPlatform.instance = AnalyticsAndroid();
  }

  final AnalyticsHostApi _host;

  @override
  Future<void> initialize(AnalyticsConfig config) => _host.initialize(configMessage(config));

  /// [config] as the channel carries it: the common fields and the Android options, flat.
  @visibleForTesting
  static AndroidConfigMessage configMessage(AnalyticsConfig config) => AndroidConfigMessage(
        apiKey: config.apiKey,
        endpoint: config.endpoint,
        flushIntervalSeconds: config.flushIntervalSeconds,
        flushBatchSize: config.flushBatchSize,
        maxQueuedEvents: config.maxQueuedEvents,
        sessionTimeoutMinutes: config.sessionTimeoutMinutes,
        trackApplicationLifecycle: config.trackApplicationLifecycle,
        debugLogging: config.debugLogging,
        pushChannelId: config.android.pushChannelId,
        pushChannelName: config.android.pushChannelName,
        pushSmallIcon: config.android.pushSmallIcon,
        pushMaxImageBytes: config.android.pushMaxImageBytes,
      );

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
      return [
        for (final topic in topics)
          TopicChoice(
            key: topic.key,
            name: topic.name,
            description: topic.description,
            subscribed: topic.subscribed,
            chosen: topic.chosen,
          ),
      ];
    } on PlatformException catch (error) {
      throw topicsException(error);
    }
  }

  /// The Kotlin side's error codes, back as the native SDK's four reasons.
  @visibleForTesting
  static TopicsException topicsException(PlatformException error) {
    final message = error.message ?? error.code;
    return switch (error.code) {
      'http' => TopicsHttpException((error.details as num?)?.toInt() ?? 0, message),
      'malformed' => TopicsMalformedException(message),
      'not_initialized' => const TopicsNotInitializedException(),
      _ => TopicsNetworkException(message),
    };
  }

  // --- Taps ---

  late final _taps = _HeldTaps();
  bool _listening = false;

  /// Receives taps from Kotlin. Exposed so tests can hand it one.
  @visibleForTesting
  AnalyticsFlutterApi get tapReceiver => _taps;

  /// On first use, sets up the receiver and tells Kotlin it may deliver what it has held since the
  /// process started — a cold start's tap among them. From then on a tap waits here, rather than
  /// natively, until something listens.
  @override
  Stream<PushTap> get pushTaps {
    if (!_listening) {
      _listening = true;
      AnalyticsFlutterApi.setUp(_taps);
      _host.pushTapsReady().catchError((Object error) => debugPrint('[Analytics] pushTapsReady failed: $error'));
    }
    return _taps.stream;
  }
}

/// Taps from Kotlin, held while nobody listens and delivered to the next listener.
class _HeldTaps implements AnalyticsFlutterApi {
  _HeldTaps() {
    _controller = StreamController<PushTap>.broadcast(onListen: _release);
  }

  late final StreamController<PushTap> _controller;
  final _held = <PushTap>[];

  Stream<PushTap> get stream => _controller.stream;

  @override
  void onPushTapped(PushTapMessage tap) {
    final converted = _convert(tap);
    if (_controller.hasListener) {
      _controller.add(converted);
    } else {
      _held.add(converted);
    }
  }

  void _release() {
    // After the listen call returns, so the listener that triggered it is the one that gets them.
    scheduleMicrotask(() {
      final held = List.of(_held);
      _held.clear();
      held.forEach(_controller.add);
    });
  }

  static PushTap _convert(PushTapMessage tap) => PushTap(
        payload: PushPayload(
          deliveryId: tap.payload.deliveryId,
          runId: tap.payload.runId,
          title: tap.payload.title,
          body: tap.payload.body,
          imageUrl: tap.payload.imageUrl,
          deepLink: tap.payload.deepLink,
          collapseKey: tap.payload.collapseKey,
          buttons: [
            for (final button in tap.payload.buttons)
              PushButton(id: button.id, title: button.title, deepLink: button.deepLink),
          ],
          data: tap.payload.data,
        ),
        actionId: tap.actionId,
      );
}

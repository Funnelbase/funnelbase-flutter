import 'dart:async';

import 'package:funnelbase_flutter/funnelbase_flutter.dart';
import 'package:funnelbase_flutter/src/properties.dart';
import 'package:funnelbase_flutter_platform_interface/funnelbase_flutter_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Records every call, as the native SDK would receive it.
class FakePlatform extends AnalyticsPlatform with MockPlatformInterfaceMixin {
  final calls = <String>[];
  final sent = <(String, Map<String, Object>)>[];
  Object? failWith;
  final taps = StreamController<PushTap>.broadcast();

  Future<void> _record(String call) async {
    calls.add(call);
    final failure = failWith;
    if (failure != null) throw failure;
  }

  @override
  Future<void> initialize(AnalyticsConfig config) => _record('initialize');

  @override
  Future<void> track(String eventName, Map<String, Object> properties) {
    sent.add((eventName, properties));
    return _record('track $eventName');
  }

  @override
  Future<void> screen(String screenName, Map<String, Object> properties) => _record('screen $screenName');

  @override
  Future<void> identify(String userId, Map<String, Object> traits) {
    sent.add((r'$identify', traits));
    return _record('identify $userId');
  }

  @override
  Future<void> flush() => _record('flush');

  @override
  Future<void> reset() => _record('reset');

  @override
  Future<void> setPushToken(String token, String kind) => _record('setPushToken $token $kind');

  @override
  Future<void> refreshPushToken() => _record('refreshPushToken');

  @override
  Future<bool> notificationsEnabled() async {
    await _record('notificationsEnabled');
    return true;
  }

  @override
  Future<String?> registeredPushToken() async {
    await _record('registeredPushToken');
    return 'tok';
  }

  @override
  Future<bool> requestNotificationPermission() async {
    await _record('requestNotificationPermission');
    return true;
  }

  @override
  Future<void> setTopic(String key, bool subscribed) => _record('setTopic $key $subscribed');

  @override
  Future<List<TopicChoice>> fetchTopics() async {
    await _record('fetchTopics');
    return const [];
  }

  @override
  Stream<PushTap> get pushTaps => taps.stream;
}

void main() {
  // The instance the platform interface starts with, before any test replaces it.
  final defaultInstance = AnalyticsPlatform.instance;
  late FakePlatform platform;

  setUp(() {
    platform = FakePlatform();
    AnalyticsPlatform.instance = platform;
  });

  group('properties', () {
    test('keeps strings, numbers and booleans as they are, and drops nulls', () {
      expect(
        encodeProperties({'s': 'a', 'i': 42, 'd': 1.5, 'b': true, 'n': null}),
        {'s': 'a', 'i': 42, 'd': 1.5, 'b': true},
      );
    });

    test('sends a day as YYYY-MM-DD', () {
      expect(encodeProperties({'renews': const AnalyticsDay(2026, 11, 3)}), {'renews': '2026-11-03'});
    });

    test('sends a moment in UTC with Z, with the fraction only when there is one', () {
      // The same text Android's Instant.truncatedTo(MILLIS).toString() writes.
      expect(isoMoment(DateTime.utc(2026, 11, 3, 9)), '2026-11-03T09:00:00Z');
      expect(isoMoment(DateTime.utc(2026, 11, 3, 9, 0, 0, 120)), '2026-11-03T09:00:00.120Z');
      expect(isoMoment(DateTime.utc(2026, 11, 3, 9, 0, 0, 7, 999)), '2026-11-03T09:00:00.007Z');
    });

    test('converts a local moment to UTC', () {
      final local = DateTime(2026, 11, 3, 9);
      expect(isoMoment(local), isoMoment(local.toUtc()));
    });

    test('sends an enum by name and anything else as its string form', () {
      expect(encodeProperties({'e': _Plan.pro, 'o': const _Thing()}), {'e': 'pro', 'o': 'thing'});
    });
  });

  group('calls', () {
    test('track goes to the platform with its encoded properties', () async {
      await Analytics.track('instrument_viewed', {'symbol': 'AAPL', 'none': null});
      final (name, properties) = platform.sent.single;
      expect(name, 'instrument_viewed');
      expect(properties, {'symbol': 'AAPL'});
    });

    test(r'a reserved $ name is refused before it reaches the platform', () async {
      await Analytics.track(r'$screen_view');
      expect(platform.calls, isEmpty);
    });

    test('a topic key the server would refuse never reaches the platform', () async {
      await Analytics.topics.set('Promotions', subscribed: false);
      await Analytics.topics.set('promotions', subscribed: false);
      expect(platform.calls, ['setTopic promotions false']);
    });

    test('a platform failure is logged and dropped, never thrown at the app', () async {
      platform.failWith = PlatformException(code: 'boom');
      await Analytics.track('instrument_viewed');
      await Analytics.flush();
      expect(await Analytics.push.notificationsEnabled(), isFalse);
      expect(await Analytics.push.registeredToken(), isNull);
    });

    test('an unsupported platform fails loudly', () async {
      platform.failWith = MissingPluginException('no');
      expect(Analytics.track('instrument_viewed'), throwsA(isA<MissingPluginException>()));
      expect(Analytics.push.notificationsEnabled(), throwsA(isA<MissingPluginException>()));
    });

    test('the default platform refuses every call', () async {
      AnalyticsPlatform.instance = defaultInstance;
      expect(Analytics.flush(), throwsA(isA<MissingPluginException>()));
      expect(Analytics.push.taps.first, throwsA(isA<MissingPluginException>()));
    });

    test('initialize refuses a config the native SDKs would refuse', () {
      expect(() => Analytics.initialize(const AnalyticsConfig(apiKey: ' ', endpoint: 'http://x')), throwsArgumentError);
      expect(() => Analytics.initialize(const AnalyticsConfig(apiKey: 'k', endpoint: 'ingest')), throwsArgumentError);
      expect(
        () => Analytics.initialize(const AnalyticsConfig(apiKey: 'k', endpoint: 'http://x', flushBatchSize: 501)),
        throwsArgumentError,
      );
      expect(
        () => Analytics.initialize(
            const AnalyticsConfig(apiKey: 'k', endpoint: 'http://x', flushBatchSize: 20, maxQueuedEvents: 10)),
        throwsArgumentError,
      );
    });
  });

  group('PushTap.link', () {
    const payload = PushPayload(
      deliveryId: 'd',
      runId: 'r',
      deepLink: 'trade://markets',
      buttons: [
        PushButton(id: 'buy', title: 'Buy', deepLink: 'trade://instrument/AAPL'),
        PushButton(id: 'later', title: 'Later'),
      ],
    );

    test("is the tapped button's link, else the message's", () {
      expect(const PushTap(payload: payload).link, 'trade://markets');
      expect(const PushTap(payload: payload, actionId: 'buy').link, 'trade://instrument/AAPL');
      expect(const PushTap(payload: payload, actionId: 'later').link, 'trade://markets');
    });
  });

  group('AnalyticsNavigatorObserver', () {
    testWidgets('reports a push, and the screen underneath on the way back', (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(WidgetsApp(
        navigatorKey: navigator,
        color: const Color(0xFF000000),
        navigatorObservers: [AnalyticsNavigatorObserver()],
        onGenerateRoute: (settings) => PageRouteBuilder<void>(
          settings: settings,
          pageBuilder: (_, _, _) => const SizedBox(),
        ),
        initialRoute: 'home',
      ));
      navigator.currentState!.pushNamed('detail');
      await tester.pumpAndSettle();
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(platform.calls, ['screen home', 'screen detail', 'screen home']);
    });

    testWidgets('skips dialogs, unnamed routes and routes the extractor declines', (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(WidgetsApp(
        navigatorKey: navigator,
        color: const Color(0xFF000000),
        navigatorObservers: [
          AnalyticsNavigatorObserver(screenNameExtractor: (route) => route.settings.name == 'shell' ? null : 'screen_${route.settings.name}'),
        ],
        onGenerateRoute: (settings) => PageRouteBuilder<void>(
          settings: settings,
          pageBuilder: (_, _, _) => const SizedBox(),
        ),
        initialRoute: 'shell',
      ));
      navigator.currentState!.push(RawDialogRoute<void>(pageBuilder: (_, _, _) => const SizedBox()));
      await tester.pumpAndSettle();
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      navigator.currentState!.pushNamed('detail');
      await tester.pumpAndSettle();
      expect(platform.calls, ['screen screen_detail']);
    });
  });
}

enum _Plan { pro }

class _Thing {
  const _Thing();

  @override
  String toString() => 'thing';
}

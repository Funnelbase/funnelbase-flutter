import 'dart:async';

import 'package:funnelbase_flutter_platform_interface/funnelbase_flutter_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:trade_demo/app.dart';
import 'package:trade_demo/app_state.dart';
import 'package:trade_demo/data/market_data.dart';
import 'package:trade_demo/data/session_store.dart';
import 'package:trade_demo/identity/user_id.dart';

/// Records every call the app makes into the SDK, in order, as one readable line each.
class _RecordingPlatform extends AnalyticsPlatform with MockPlatformInterfaceMixin {
  final calls = <String>[];
  final taps = StreamController<PushTap>();

  List<String> get screens => [
        for (final c in calls)
          if (c.startsWith('screen ')) c.substring(7),
      ];

  @override
  Future<void> initialize(AnalyticsConfig config) async => calls.add('initialize');

  @override
  Future<void> track(String eventName, Map<String, Object> properties) async => calls.add('track $eventName $properties');

  @override
  Future<void> screen(String screenName, Map<String, Object> properties) async => calls.add('screen $screenName');

  @override
  Future<void> identify(String userId, Map<String, Object> traits) async => calls.add('identify $userId $traits');

  @override
  Future<void> flush() async {}

  @override
  Future<void> reset() async => calls.add('reset');

  @override
  Future<void> setPushToken(String token, String kind) async {}

  @override
  Future<void> refreshPushToken() async {}

  @override
  Future<bool> notificationsEnabled() async => true;

  @override
  Future<String?> registeredPushToken() async => null;

  @override
  Future<bool> requestNotificationPermission() async => true;

  @override
  Future<void> setTopic(String key, bool subscribed) async {}

  @override
  Future<List<TopicChoice>> fetchTopics() async => const [];

  @override
  Stream<PushTap> get pushTaps => taps.stream;
}

/// The screen-view taxonomy, walked end to end: the regression docs/demo-app.md names as the
/// Android demo's missing test — a screen that loses its report, or reports twice, fails here.
void main() {
  late _RecordingPlatform platform;

  setUp(() {
    platform = _RecordingPlatform();
    AnalyticsPlatform.instance = platform;
  });

  Future<AppState> launch(WidgetTester tester, {String? signedInAs}) async {
    // A tall phone, so every list row the walk taps is laid out.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    final store = await SessionStore.load(
      MemorySessionFile(signedInAs == null ? null : '{"username":"$signedInAs","favourites":["AAPL"]}'),
    );
    final state = AppState(store, MarketData.current)..identify();
    await tester.pumpWidget(TradeDemoApp(state: state));
    await tester.pumpAndSettle();
    return state;
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder.hitTestable().first);
    await tester.pumpAndSettle();
  }

  testWidgets('sign-up, the tabs and an instrument report each screen exactly once', (tester) async {
    await launch(tester);
    final symbol = MarketData.current.instruments.first.symbol;

    await tap(tester, find.text('Create account'));
    await tap(tester, find.text('Next'));
    await tap(tester, find.text('Next'));
    await tap(tester, find.text('Continue'));
    await tester.enterText(find.byType(TextField), 'ada');
    await tester.pump();
    await tap(tester, find.widgetWithText(FilledButton, 'Create account'));
    await tap(tester, find.text('Markets'));
    await tap(tester, find.text(symbol));
    await tap(tester, find.byType(BackButton));
    // The chips filter within a screen and are not navigation.
    await tap(tester, find.text('Orders'));
    await tap(tester, find.textContaining('Filled ('));

    expect(platform.screens, [
      'welcome',
      'signup_intro_1',
      'signup_intro_2',
      'signup_intro_3',
      'signup_username',
      'dashboard',
      'markets',
      'instrument_detail',
      'markets',
      'orders',
    ]);
    expect(platform.calls, contains('track instrument_viewed {symbol: $symbol}'));

    // The sign-up's identify is the link: it comes before the first signed-in screen, and no alias.
    final identify = platform.calls.indexWhere((c) => c.startsWith('identify ${UserId.forUsername('ada')}'));
    expect(identify, greaterThan(platform.calls.indexOf('screen signup_username')));
    expect(identify, lessThan(platform.calls.indexOf('screen dashboard')));
    expect(platform.calls[identify], contains('plan: free'));
  });

  testWidgets('a relaunch while signed in identifies before the first screen view', (tester) async {
    await launch(tester, signedInAs: 'grace');

    expect(platform.calls.first, startsWith('identify ${UserId.forUsername('grace')}'));
    expect(platform.screens, ['dashboard']);
  });

  testWidgets('sign-out resets and lands on welcome', (tester) async {
    await launch(tester, signedInAs: 'grace');
    await tap(tester, find.byTooltip('Sign out'));

    expect(platform.calls, contains('reset'));
    expect(platform.screens, ['dashboard', 'welcome']);
  });

  testWidgets('the notifications screen and its topics report on the way in and back', (tester) async {
    await launch(tester, signedInAs: 'grace');
    await tap(tester, find.byTooltip('Notifications'));
    await tap(tester, find.text('Choose topics'));
    await tap(tester, find.byType(BackButton));
    await tap(tester, find.byType(BackButton));

    expect(platform.screens, ['dashboard', 'push_settings', 'notification_settings', 'push_settings', 'dashboard']);
  });

  testWidgets('a pro sign-in sends the renewal day as a calendar day', (tester) async {
    await launch(tester);
    await tap(tester, find.text('Sign in'));
    await tester.enterText(find.byType(TextField).first, 'ada');
    await tester.pump();
    await tap(tester, find.byType(Switch));
    await tap(tester, find.widgetWithText(FilledButton, 'Sign in'));

    final identify = platform.calls.firstWhere((c) => c.startsWith('identify '));
    expect(identify, contains('plan: pro'));
    expect(identify, matches(RegExp(r'plan_renews_on: \d{4}-\d{2}-\d{2}[,}]')));
    expect(platform.screens, ['welcome', 'sign_in', 'dashboard']);
  });

  testWidgets('a tapped push opens the instrument or tab its link names', (tester) async {
    await launch(tester, signedInAs: 'grace');

    platform.taps.add(const PushTap(
      payload: PushPayload(deliveryId: 'd', runId: 'r', deepLink: 'trade://instrument/msft'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Microsoft Corporation'), findsOneWidget);

    platform.taps.add(const PushTap(payload: PushPayload(deliveryId: 'd', runId: 'r', deepLink: 'trade://news')));
    await tester.pumpAndSettle();

    expect(platform.screens, ['dashboard', 'instrument_detail', 'news']);
    expect(platform.calls, contains('track instrument_viewed {symbol: MSFT}'));
  });
}

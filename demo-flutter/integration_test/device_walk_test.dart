import 'package:funnelbase_flutter/funnelbase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:trade_demo/app.dart';
import 'package:trade_demo/app_state.dart';
import 'package:trade_demo/config.dart';
import 'package:trade_demo/data/market_data.dart';
import 'package:trade_demo/data/session_store.dart';

/// The sign-up walk of `test/screen_views_test.dart`, on a device or simulator, through the real
/// plugin and the real native SDK — so what it proves is what reaches the server, not what Dart
/// asked for. It asserts nothing about the server; read the result on the dashboard
/// (docs/sdk-flutter.md, "The demo app"):
///
/// ```
/// flutter test integration_test --dart-define-from-file=config.json -d <device>
/// ```
///
/// The username is `walk-<platform>`, so a run is one recognisable person per platform. A
/// simulator is the reason it exists: an iOS simulator cannot be tapped from a script.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sign up, browse an instrument and come back, through the native SDK', (tester) async {
    final config = DemoConfig.analytics();
    expect(config, isNotNull, reason: 'run with --dart-define-from-file=config.json holding a key');
    await Analytics.initialize(config!);

    final store = await SessionStore.load(MemorySessionFile(null));
    final state = AppState(store, MarketData.current)..identify();
    await tester.pumpWidget(TradeDemoApp(state: state));
    await tester.pumpAndSettle();

    Future<void> tap(Finder finder) async {
      await tester.tap(finder.hitTestable().first);
      await tester.pumpAndSettle();
    }

    final symbol = MarketData.current.instruments.first.symbol;
    await tap(find.text('Create account'));
    await tap(find.text('Next'));
    await tap(find.text('Next'));
    await tap(find.text('Continue'));
    await tester.enterText(find.byType(TextField), 'walk-${Theme.of(tester.element(find.byType(TextField))).platform.name}');
    await tester.pump();
    await tap(find.widgetWithText(FilledButton, 'Create account'));
    await tap(find.text('Markets'));
    await tap(find.text(symbol));
    await tap(find.byType(BackButton));
    await tap(find.text('Orders'));

    await Analytics.flush();
    // The upload is the native SDK's, on its own thread: give it a moment before the test ends.
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 5)));
  });
}

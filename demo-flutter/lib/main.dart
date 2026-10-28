import 'package:funnelbase_flutter/funnelbase_flutter.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'app_state.dart';
import 'config.dart';
import 'data/market_data.dart';
import 'data/session_store.dart';

/// The trading demo in Flutter: demo-android screen for screen, sending the same taxonomy through
/// `funnelbase_flutter` (docs/demo-app.md, docs/sdk-flutter.md).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = DemoConfig.analytics();
  if (config == null) {
    debugPrint('[TradeDemo] No ingest key configured — analytics is off. '
        'Copy demo-flutter/config.example.json to config.json and run with '
        '--dart-define-from-file=config.json; see docs/sdk-flutter.md.');
  } else {
    await Analytics.initialize(config);
  }

  final store = await SessionStore.load(AppSupportSessionFile());
  final state = AppState(store, MarketData.current);
  // A relaunch of an already-signed-in app re-identifies before the first frame, so the `$identify`
  // is the launch's first event — ahead of the screen views — and the session's start carries the
  // account. The SDK keeps the user id itself; this sends the traits and marks the launch.
  state.identify();

  runApp(TradeDemoApp(state: state));
}

import 'dart:io';

import 'package:funnelbase_flutter/funnelbase_flutter.dart';
import 'package:flutter/foundation.dart';

/// The demo's settings, from `--dart-define-from-file=config.json`.
///
/// The key is a credential and is not in the repository: `config.json` is gitignored and absent on a
/// clean clone, exactly as demo-android's `local.properties` and demo-ios's `Config.xcconfig` are.
/// `config.example.json` is the committed template. A key per platform, because an ingest key is
/// issued for one platform and the server refuses it for the other.
abstract final class DemoConfig {
  static const _androidKey = String.fromEnvironment('ANALYTICS_API_KEY_ANDROID');
  static const _iosKey = String.fromEnvironment('ANALYTICS_API_KEY_IOS');

  // 10.0.2.2 is the emulator's route to the host, where docker-compose listens; the iOS simulator
  // shares the host's loopback. A physical device wants the host's LAN address instead.
  static const _androidEndpoint =
      String.fromEnvironment('ANALYTICS_ENDPOINT_ANDROID', defaultValue: 'http://10.0.2.2:8080');
  static const _iosEndpoint = String.fromEnvironment('ANALYTICS_ENDPOINT_IOS', defaultValue: 'http://localhost:8080');

  /// Shared with the notification service extension, and the reason a receipt it records reaches
  /// this app's upload queue. Must match the entitlement on both targets.
  static const appGroup = 'group.com.analytics.demo.trading.flutter';

  /// The SDK's configuration for this platform, or null when no key is set — and with no key the
  /// app runs normally and initialises no SDK. A demo that crashes on a fresh clone is worse than
  /// one that quietly collects nothing.
  static AnalyticsConfig? analytics() {
    final key = (Platform.isIOS ? _iosKey : _androidKey).trim();
    final endpoint = Platform.isIOS ? _iosEndpoint : _androidEndpoint;
    if (key.isEmpty || !endpoint.startsWith('http')) return null;
    return AnalyticsConfig(
      apiKey: key,
      endpoint: endpoint,
      debugLogging: kDebugMode,
      ios: const IosOptions(appGroup: appGroup, registerApnsToken: true),
    );
  }
}

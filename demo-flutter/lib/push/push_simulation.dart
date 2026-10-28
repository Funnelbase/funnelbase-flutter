import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';

/// Payloads shaped exactly as the Funnelbase backend sends them — the same three demo-android's and
/// demo-ios's `PushSimulation` build — so the app can show what a campaign will look like without
/// Firebase, APNs or a network.
///
/// Delivering one is native (`deliver`), never Dart: rendering a push and recording its receipt
/// belong to the native SDK, which does them when no Dart is running at all (docs/sdk-flutter.md,
/// "Push"). On Android the map goes to `Analytics.push.handleMessage`, so everything after the
/// transport is real — the parse, the notification, its image and buttons, `$push_received`, the
/// tap. On iOS nothing local can run a notification service extension, so the map is posted as a
/// local notification with the same `userInfo`: the text, buttons and tap are real, the image and
/// the receipt are not (demo-ios's PushSimulation says why).
abstract final class PushSimulation {
  static const _native = MethodChannel('trade_demo/native');

  /// A sample image served on the host's port 9099 (a local push provider stand-in, run beside the
  /// backend), as each platform reaches the host: an Android
  /// emulator through its 10.0.2.2 alias, the iOS simulator on the host's own loopback.
  static String get localImageUrl =>
      Platform.isAndroid ? 'http://10.0.2.2:9099/media/sample.png' : 'http://localhost:9099/media/sample.png';

  /// Where [localImageUrl] points, for the screen to say.
  static String get imageHost => Platform.isAndroid ? '10.0.2.2:9099' : 'localhost:9099';

  /// The run id a simulated push claims. Deliberately not a uuid, so a receipt from a simulation is
  /// recognisable in the data rather than counting against a campaign that was never sent.
  static const simulatedRun = 'simulated-local-run';

  /// Title, body, a deep link, and nothing else: what most campaigns are.
  static Map<String, String> basic(String deliveryId) => {
        'delivery_id': deliveryId,
        'run_id': simulatedRun,
        'title': 'AAPL is up 2.4%',
        'body': "Apple leads the index this morning after yesterday's close.",
        'deep_link': 'trade://instrument/AAPL',
      };

  /// An image, a long body and two buttons that lead to different places.
  static Map<String, String> rich(String deliveryId) => {
        'delivery_id': deliveryId,
        'run_id': simulatedRun,
        'title': 'Your order filled',
        'body': '12 shares of MSFT at \$412.80. The rest of the order was cancelled at the close, '
            'and the cash is back in your account.',
        'image_url': localImageUrl,
        'deep_link': 'trade://orders',
        'buttons': '[{"id":"view_order","title":"View order","deep_link":"trade://instrument/MSFT"},'
            '{"id":"markets","title":"Markets","deep_link":"trade://markets"}]',
      };

  /// Two of these replace one another rather than stacking, which is what a collapse key is for.
  static Map<String, String> collapsing(String deliveryId) => {
        'delivery_id': deliveryId,
        'run_id': simulatedRun,
        'title': 'Market close',
        'body': 'The index finished at ${4800 + Random().nextInt(401)}, a new print each time.',
        'collapse_key': 'market_close',
      };

  /// A delivery id per simulated push, so each one is its own notification and its own receipt.
  static String deliveryId() =>
      'sim-${List.generate(8, (_) => Random().nextInt(16).toRadixString(16)).join()}';

  /// Hands [data] to the native side as the transport would. False when the SDK did not take it —
  /// on Android, before `Analytics.initialize`.
  static Future<bool> deliver(Map<String, String> data) async =>
      await _native.invokeMethod<bool>('deliverPush', data) ?? false;

  /// The system's notification settings for this app, the only place the switch (and on Android a
  /// blocked channel) can be turned back on.
  static Future<void> openNotificationSettings() => _native.invokeMethod<void>('openNotificationSettings');
}

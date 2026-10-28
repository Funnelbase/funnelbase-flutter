import 'package:funnelbase_flutter/funnelbase_flutter.dart';

/// What the app does with a push once the SDK has reported it: where to go.
///
/// The SDK does not navigate — it cannot know this app's routes — so it hands the tap over and this
/// is the app's half. Pure, so the routing is testable without a device; the same rules as
/// demo-android's `PushRouting.kt`.
abstract final class PushRouting {
  /// The scheme the demo's own deep links use, as the campaign writes them.
  static const scheme = 'trade';

  /// The route a push should open, or null to leave the app where it is. Understands the demo's
  /// two link shapes and ignores anything else, because a campaign can always be sent with a link
  /// this build does not know yet.
  ///
  ///     trade://instrument/AAPL  →  instrument/AAPL
  ///     trade://markets          →  markets
  static String? routeFor(String? link) {
    if (link == null || link.trim().isEmpty) return null;
    const prefix = '$scheme://';
    if (!link.startsWith(prefix)) return null;
    final parts = link.substring(prefix.length).split('/').where((p) => p.trim().isNotEmpty).toList();
    if (parts.isEmpty) return null;
    if (parts[0] == 'instrument' && parts.length >= 2) return 'instrument/${parts[1].toUpperCase()}';
    if (_tabs.contains(parts[0])) return parts[0];
    return null;
  }

  /// The link a tap followed: the button's own, if it had one, else the message's.
  static String? linkFor(PushTap tap) => tap.link;

  static const _tabs = {'dashboard', 'markets', 'orders', 'news'};
}

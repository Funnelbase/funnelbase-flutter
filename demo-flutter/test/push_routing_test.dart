import 'package:funnelbase_flutter/funnelbase_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trade_demo/push/push_routing.dart';

/// The app's half of a tap: the SDK reports the open and hands the push over, and this decides
/// where to go. A campaign is written long after a build ships, so an unknown link has to be
/// harmless rather than a crash or a blank screen. Ported from demo-android's `PushRoutingTest`.
void main() {
  PushPayload payload({String? deepLink, List<PushButton> buttons = const []}) => PushPayload(
        deliveryId: 'del-1',
        runId: 'run-1',
        title: 'Your order filled',
        body: 'AAPL, 12 shares',
        deepLink: deepLink,
        buttons: buttons,
      );

  test('an instrument link opens that instrument, whatever case it was written in', () {
    expect(PushRouting.routeFor('trade://instrument/AAPL'), 'instrument/AAPL');
    expect(PushRouting.routeFor('trade://instrument/aapl'), 'instrument/AAPL');
    expect(PushRouting.routeFor('trade://instrument/AAPL/'), 'instrument/AAPL');
  });

  test('a tab link opens that tab', () {
    expect(PushRouting.routeFor('trade://markets'), 'markets');
    expect(PushRouting.routeFor('trade://news'), 'news');
  });

  test('a link this build does not know leaves the app where it is', () {
    expect(PushRouting.routeFor(null), isNull);
    expect(PushRouting.routeFor(''), isNull);
    expect(PushRouting.routeFor('trade://portfolio/rebalance'), isNull, reason: 'a route a later version may add');
    expect(PushRouting.routeFor('https://example.com/promo'), isNull, reason: "someone else's link");
    expect(PushRouting.routeFor('trade://instrument'), isNull, reason: 'an instrument link with no instrument');
  });

  /// A button carries its own link, and that is the point of a button: "View order" and "Later" on
  /// one push lead to different places.
  test("a button's link wins over the message's, and the message's is the fallback", () {
    const buttons = [
      PushButton(id: 'view', title: 'View', deepLink: 'trade://instrument/MSFT'),
      PushButton(id: 'later', title: 'Later'),
    ];
    final push = payload(deepLink: 'trade://orders', buttons: buttons);

    expect(PushRouting.linkFor(PushTap(payload: push, actionId: 'view')), 'trade://instrument/MSFT');
    expect(PushRouting.linkFor(PushTap(payload: push, actionId: 'later')), 'trade://orders',
        reason: 'a button with no link of its own');
    expect(PushRouting.linkFor(PushTap(payload: push)), 'trade://orders', reason: 'the notification itself');
    expect(PushRouting.linkFor(PushTap(payload: payload())), isNull);
  });
}

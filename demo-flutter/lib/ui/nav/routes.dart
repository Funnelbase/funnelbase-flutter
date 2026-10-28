import 'package:flutter/material.dart';

import '../../analytics/screens.dart';

/// Navigation routes.
///
/// Separate from `analytics/screens.dart` on purpose. These are addresses the navigator resolves;
/// those are the dimension a dashboard groups by. Reusing one string for both means a routing
/// refactor silently rewrites the analytics taxonomy — so [screenFor] maps one to the other.
abstract final class Routes {
  static const welcome = '/welcome';
  static const signIn = '/sign_in';
  static const signUp = '/sign_up';

  /// The four tabs, one route: the shell reports which tab is showing itself.
  static const home = '/home';

  /// Reached from the dashboard's bell, not a tab: push is a setting, not a section of the product.
  static const push = '/push';

  /// Reached from the push screen: which kinds of message this person wants.
  static const topics = '/push/topics';

  static const _instrumentPrefix = '/instrument/';

  static String instrument(String symbol) => '$_instrumentPrefix$symbol';

  /// The symbol in an instrument route, or null for any other route.
  static String? symbolOf(String? route) =>
      route != null && route.startsWith(_instrumentPrefix) ? route.substring(_instrumentPrefix.length) : null;

  /// The screen a route shows, for `AnalyticsNavigatorObserver`, or null for a route that reports
  /// its own screens: the tab shell (one route, four tabs) and the sign-up flow (one route, three
  /// pager pages and the username step) — a route change cannot see either, and reporting the
  /// route as well would count every arrival twice.
  static String? screenFor(Route<dynamic> route) {
    final name = route.settings.name;
    if (symbolOf(name) != null) return Screens.instrumentDetail;
    return switch (name) {
      welcome => Screens.welcome,
      signIn => Screens.signIn,
      push => Screens.push,
      topics => Screens.notificationSettings,
      _ => null,
    };
  }
}

/// The four bottom-bar tabs, in display order.
enum AppTab {
  dashboard('dashboard', 'Dashboard', Icons.space_dashboard, Screens.dashboard),
  markets('markets', 'Markets', Icons.candlestick_chart, Screens.markets),
  orders('orders', 'Orders', Icons.receipt_long, Screens.orders),
  news('news', 'News', Icons.article, Screens.news);

  const AppTab(this.link, this.label, this.icon, this.screenName);

  /// The name a push's deep link uses for the tab (`trade://markets`).
  final String link;
  final String label;
  final IconData icon;
  final String screenName;

  static AppTab? byLink(String link) {
    for (final tab in values) {
      if (tab.link == link) return tab;
    }
    return null;
  }
}

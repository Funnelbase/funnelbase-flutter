import 'package:flutter/widgets.dart';

import 'analytics.dart';

/// Names the screen a route shows, or null for a route that is not a screen of its own.
typedef ScreenNameExtractor = String? Function(Route<dynamic> route);

/// Reports a screen view whenever the route on top of a [Navigator] changes: pushed, replaced, or
/// revealed by a pop.
///
/// ```dart
/// MaterialApp(navigatorObservers: [AnalyticsNavigatorObserver()], ...)
/// ```
///
/// A Flutter app is one Activity and one view controller, so the native SDKs' automatic screen
/// view cannot see its screens; this is what replaces it. Only page routes count by default —
/// a dialog or a bottom sheet sits over a screen, it is not one — and a route with no name is
/// skipped rather than reported as `null`.
///
/// Pass [screenNameExtractor] to keep screen names apart from route names. They look alike and are
/// not the same thing: a route is an address the router resolves, a screen name is a dashboard
/// dimension, and sharing one string means a routing refactor silently renames a chart's series.
/// Return null from it for a route that reports its own screens — a shell whose tabs, or a pager
/// whose pages, each call [Analytics.screen] — so nothing is counted twice.
class AnalyticsNavigatorObserver extends RouteObserver<ModalRoute<dynamic>> {
  AnalyticsNavigatorObserver({ScreenNameExtractor? screenNameExtractor, bool Function(Route<dynamic>)? routeFilter})
      : _nameOf = screenNameExtractor ?? _routeName,
        _counts = routeFilter ?? _isPage;

  final ScreenNameExtractor _nameOf;
  final bool Function(Route<dynamic>) _counts;

  static String? _routeName(Route<dynamic> route) => route.settings.name;

  static bool _isPage(Route<dynamic> route) => route is PageRoute;

  void _report(Route<dynamic>? route) {
    if (route == null || !_counts(route)) return;
    final name = _nameOf(route);
    if (name == null || name.isEmpty) return;
    Analytics.screen(name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _report(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _report(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    // Coming back is arriving: the screen underneath is on screen again. Only when a page left —
    // a closed dialog uncovers nothing.
    if (_counts(route)) _report(previousRoute);
  }
}

import 'package:funnelbase_flutter/funnelbase_flutter.dart';
import 'package:flutter/widgets.dart';

import 'routes.dart';

/// What the screens that report their own screen views need from the navigation: the observer, to
/// hear when their route is uncovered, and the tab being shown.
class NavScope extends InheritedWidget {
  const NavScope({super.key, required this.observer, required this.tab, required super.child});

  final AnalyticsNavigatorObserver observer;

  /// The tab the shell shows. Set from outside by a push that leads to a tab.
  final ValueNotifier<AppTab> tab;

  static NavScope of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<NavScope>()!;

  @override
  bool updateShouldNotify(NavScope oldWidget) => observer != oldWidget.observer || tab != oldWidget.tab;
}

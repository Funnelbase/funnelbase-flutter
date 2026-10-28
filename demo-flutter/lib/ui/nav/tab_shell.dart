import 'package:funnelbase_flutter/funnelbase_flutter.dart';
import 'package:flutter/material.dart';

import '../dashboard/dashboard_screen.dart';
import '../markets/markets_screen.dart';
import '../news/news_screen.dart';
import '../orders/orders_screen.dart';
import 'nav_scope.dart';
import 'routes.dart';

/// The signed-in app: four tabs under one bottom bar, each tab's own state kept while another is
/// showing — what demo-android's `switchTab` saves and restores.
///
/// One route for four screens, so the navigator observer cannot tell them apart and
/// `Routes.screenFor` returns null for it. The shell reports instead, exactly once per arrival:
/// when it is first shown, when the tab changes while it is showing, and when a route on top of it
/// (an instrument, the notifications screen) is popped and it is uncovered.
class TabShell extends StatefulWidget {
  const TabShell({super.key});

  @override
  State<TabShell> createState() => _TabShellState();
}

class _TabShellState extends State<TabShell> with RouteAware {
  NavScope? _nav;
  ModalRoute<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nav = NavScope.of(context);
    final route = ModalRoute.of(context);
    if (nav == _nav && route == _route) return;
    _unsubscribe();
    _nav = nav..tab.addListener(_tabChanged);
    _route = route;
    if (route != null) nav.observer.subscribe(this, route);
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  void _unsubscribe() {
    _nav?.tab.removeListener(_tabChanged);
    _nav?.observer.unsubscribe(this);
  }

  void _report() => Analytics.screen(_nav!.tab.value.screenName);

  /// The shell arrived: the observer's `didPush` fired with nothing to report, so this does.
  @override
  void didPush() => _report();

  /// Uncovered by a pop.
  @override
  void didPopNext() => _report();

  void _tabChanged() {
    setState(() {});
    // A tab chosen while another route covers the shell is reported when the shell is uncovered.
    if (_route?.isCurrent ?? false) _report();
  }

  void _select(AppTab tab) {
    if (_nav!.tab.value != tab) _nav!.tab.value = tab;
  }

  @override
  Widget build(BuildContext context) {
    final tab = NavScope.of(context).tab.value;
    return PopScope(
      // Back from any tab but the first goes to the first, rather than walking the tabs visited.
      canPop: tab == AppTab.dashboard,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(AppTab.dashboard);
      },
      child: Scaffold(
        body: IndexedStack(
          index: tab.index,
          children: [
            DashboardScreen(onSeeAllNews: () => _select(AppTab.news)),
            const MarketsScreen(),
            const OrdersScreen(),
            const NewsScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab.index,
          onDestinationSelected: (index) => _select(AppTab.values[index]),
          // Labels always shown: an icon-only bar makes people guess what a candlestick means.
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            for (final t in AppTab.values) NavigationDestination(icon: Icon(t.icon), label: t.label),
          ],
        ),
      ),
    );
  }
}

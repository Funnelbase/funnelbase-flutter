import 'dart:async';

import 'package:funnelbase_flutter/funnelbase_flutter.dart';
import 'package:flutter/material.dart';

import 'app_state.dart';
import 'push/push_routing.dart';
import 'ui/instrument/instrument_screen.dart';
import 'ui/nav/nav_scope.dart';
import 'ui/nav/routes.dart';
import 'ui/nav/tab_shell.dart';
import 'ui/onboarding/sign_in_screen.dart';
import 'ui/onboarding/sign_up_flow.dart';
import 'ui/onboarding/welcome_screen.dart';
import 'ui/push/push_screen.dart';
import 'ui/push/topics_screen.dart';
import 'ui/theme.dart';

/// The whole app: one navigator for onboarding and the signed-in screens, its first route chosen
/// from the stored session, and the one place a tapped push is routed.
class TradeDemoApp extends StatefulWidget {
  const TradeDemoApp({super.key, required this.state});

  final AppState state;

  @override
  State<TradeDemoApp> createState() => _TradeDemoAppState();
}

class _TradeDemoAppState extends State<TradeDemoApp> {
  final _navigator = GlobalKey<NavigatorState>();

  /// Every pushed route is a screen view, named by `Routes.screenFor` — the screen names are not the
  /// route names. The tab shell and the sign-up flow report their own.
  final _observer = AnalyticsNavigatorObserver(screenNameExtractor: Routes.screenFor);

  final _tab = ValueNotifier(AppTab.dashboard);
  StreamSubscription<PushTap>? _taps;

  @override
  void initState() {
    super.initState();
    // Listened to at once: the SDK holds a tap that arrived before anything listened — the one that
    // started the app — and hands it to this first listener.
    _taps = Analytics.push.taps.listen(_onTap, onError: (Object _) {});
  }

  @override
  void dispose() {
    _taps?.cancel();
    _tab.dispose();
    super.dispose();
  }

  /// Where a tapped push leads. The SDK has already recorded the open; this is the navigation it
  /// cannot do. A push that arrives before anyone has signed in leads nowhere — the screens behind
  /// it need an account — and a link this build does not know leaves the app where it is.
  void _onTap(PushTap tap) {
    final route = PushRouting.routeFor(PushRouting.linkFor(tap));
    if (route == null || !widget.state.isSignedIn) return;
    final navigator = _navigator.currentState;
    if (navigator == null) {
      // A cold start's tap can arrive before the navigator exists: try again after the first frame.
      WidgetsBinding.instance
        ..addPostFrameCallback((_) => _onTap(tap))
        ..ensureVisualUpdate();
      return;
    }
    final tab = AppTab.byLink(route);
    if (tab != null) {
      // A fresh shell on that tab, with whatever was on top of it gone — replaced in one step, so no
      // screen in between is uncovered and reported on the way.
      _tab.value = tab;
      navigator.pushNamedAndRemoveUntil(Routes.home, (_) => false);
    } else {
      navigator.pushNamed('/$route');
    }
  }

  Route<dynamic> _route(RouteSettings settings) {
    final symbol = Routes.symbolOf(settings.name);
    final Widget page = switch (settings.name) {
      _ when symbol != null => InstrumentScreen(symbol: symbol),
      Routes.signIn => const SignInScreen(),
      Routes.signUp => const SignUpFlow(),
      Routes.home => const TabShell(),
      Routes.push => const PushScreen(),
      Routes.topics => const TopicsScreen(),
      _ => const WelcomeScreen(),
    };
    return MaterialPageRoute(settings: settings, builder: (_) => page);
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: widget.state,
      child: NavScope(
        observer: _observer,
        tab: _tab,
        child: MaterialApp(
          title: 'Trade Demo',
          debugShowCheckedModeBanner: false,
          theme: tradeTheme(),
          navigatorKey: _navigator,
          navigatorObservers: [_observer],
          onGenerateRoute: _route,
          // One first route, not the path split into routes the way `initialRoute` treats a name
          // that starts with a slash.
          onGenerateInitialRoutes: (_) => [
            _route(RouteSettings(name: widget.state.isSignedIn ? Routes.home : Routes.welcome)),
          ],
        ),
      ),
    );
  }
}

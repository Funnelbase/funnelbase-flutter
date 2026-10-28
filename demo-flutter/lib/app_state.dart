import 'package:funnelbase_flutter/funnelbase_flutter.dart';
import 'package:flutter/widgets.dart';

import 'data/market_data.dart';
import 'data/session_store.dart';
import 'identity/user_id.dart';

/// The app's entire mutable state: who is signed in and what they favourited.
///
/// It is also the one place that touches identity in the SDK. Keeping `identify` and `reset` next to
/// the state change they describe is what stops a screen from flipping the username without telling
/// analytics about it — the rule demo-android's `AppState` keeps, and docs/demo-app.md "Identity".
class AppState extends ChangeNotifier {
  AppState(this._store, this.market) {
    // A first run seeds a handful, so the dashboard's favourites card has something in it.
    if (_store.isFirstRun) _store.favourites = market.defaultFavourites;
  }

  final SessionStore _store;
  final MarketData market;

  String? get username => _store.username;
  bool get isSignedIn => username != null;
  Set<String> get favourites => _store.favourites;

  /// Sign-in with any credentials — there is no auth backend.
  ///
  /// One `identify`, and that is the whole of it (docs/event-contract.md): the `$identify` carries
  /// the device's anonymous id and the account together, which is the link. Signing in as a
  /// different account is an account switch, which the SDK resets for itself.
  void signIn(String username, {bool pro = false}) {
    _store.username = username.trim();
    // No billing either: the sign-in screen's switch says which plan the account is on, and a pro
    // plan renews 30 days from the sign-in — a calendar day, what a journey's "wait until a date"
    // and a segment's "in the next N days" read.
    _store.planRenewsOn = pro ? AnalyticsDay.of(DateTime.now().add(const Duration(days: _planPeriodDays))) : null;
    identify();
    notifyListeners();
  }

  /// Registration: the same `identify` as a sign-in, and no alias call before it. The intro pages
  /// viewed before the account existed were sent under the anonymous id the `$identify` now
  /// carries beside the new user id, which is what attaches them to the account.
  void signUp(String username) => signIn(username);

  /// Sends `$identify` for whoever is signed in, with every trait the app knows: `username`, `plan`
  /// and, on pro, `plan_renews_on` as a day the SDK sends as `YYYY-MM-DD`.
  ///
  /// Called by every sign-in, and once at launch while signed in, before the first frame — so it is
  /// the launch's first event, ahead of the screen views, and the session's start carries the
  /// account.
  void identify() {
    final name = username;
    if (name == null) return;
    Analytics.identify(UserId.forUsername(name), {'username': name, ..._planTraits()});
  }

  Map<String, Object> _planTraits() {
    var renewsOn = _store.planRenewsOn;
    if (renewsOn == null) return {'plan': 'free'};
    // A relaunch long after the sign-in: the plan has renewed since, as often as it took.
    final today = AnalyticsDay.of(DateTime.now());
    var day = DateTime.utc(renewsOn.year, renewsOn.month, renewsOn.day);
    final todayUtc = DateTime.utc(today.year, today.month, today.day);
    while (day.isBefore(todayUtc)) {
      day = day.add(const Duration(days: _planPeriodDays));
    }
    renewsOn = AnalyticsDay.of(day);
    _store.planRenewsOn = renewsOn;
    return {'plan': 'pro', 'plan_renews_on': renewsOn};
  }

  /// Sign-out. `Analytics.reset()` uploads what is queued before clearing the identity, so the end
  /// of this person's session is not attributed to whoever signs in next.
  void signOut() {
    _store.clearUser();
    Analytics.reset();
    notifyListeners();
  }

  bool isFavourite(String symbol) => favourites.contains(symbol);

  void toggleFavourite(String symbol) {
    final next = {...favourites};
    if (!next.remove(symbol)) next.add(symbol);
    _store.favourites = next;
    notifyListeners();
  }

  /// How often a pro plan renews; the trading simulator's renewals are 30 days apart too.
  static const _planPeriodDays = 30;
}

/// Hands [AppState] to every screen, and rebuilds the ones that read it when it changes.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

/// Every screen name this app reports, in one place — the same taxonomy as demo-android's
/// `Screens.kt` and demo-ios's `Screens.swift`, so the three demos read as one product in the
/// dashboard (docs/demo-app.md).
///
/// `screen_name` is a dashboard dimension, so these strings are the taxonomy: renaming one splits a
/// chart in two rather than relabelling it. They are kept apart from the route names in
/// `ui/nav/routes.dart` so a routing refactor cannot silently rewrite the analytics.
abstract final class Screens {
  static const welcome = 'welcome';
  static const signIn = 'sign_in';

  /// The paged sign-up intro. 1-based: `signup_intro_1` reads better in a chart than `_0`.
  static String signUpIntro(int page) => 'signup_intro_${page + 1}';

  static const signUpUsername = 'signup_username';

  static const dashboard = 'dashboard';
  static const markets = 'markets';
  static const orders = 'orders';
  static const news = 'news';

  /// Which instrument is on it is an `instrument_viewed` event, not a screen property.
  static const instrumentDetail = 'instrument_detail';

  /// Notifications: the permission, this install's token, and the simulated campaigns.
  static const push = 'push_settings';

  /// Notification settings: a switch per topic the dashboard lists, reached from [push].
  static const notificationSettings = 'notification_settings';
}

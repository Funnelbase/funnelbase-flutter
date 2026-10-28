import 'package:funnelbase_flutter_platform_interface/funnelbase_flutter_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'properties.dart';

/// The SDK's entire public surface, mirroring the native SDKs method for method: `initialize`,
/// `track`, `screen`, `identify`, `flush`, `reset`, [push] and [topics].
///
/// Every call goes to the native SDK, which owns the queue, the session, the identity and the
/// upload, so what a Flutter app sends is exactly what a native one does (docs/event-contract.md).
///
/// Like the native SDKs, nothing here throws at the app for a failure of analytics: a call before
/// [initialize], a refused value or a failed channel call is logged and dropped. The one exception
/// is a platform with no implementation, where every call throws a [MissingPluginException] — the
/// SDK runs on Android and iOS only, and a build for anything else should fail where it is tested
/// rather than collect nothing in silence. [AnalyticsTopics.fetch] throws a [TopicsException],
/// because a settings screen has to show the failure.
abstract final class Analytics {
  static AnalyticsPlatform get _platform => AnalyticsPlatform.instance;

  /// Starts the SDK. Call once, as early as the app starts — in `main`, before `runApp`.
  ///
  /// The platform packages remember [config] and start the native SDK with it at the next process
  /// start, before any Dart runs, because a push or a tap can start the app with no Dart at all
  /// (docs/sdk-flutter.md, "Before Dart runs"). So a changed config — a rotated key — takes effect
  /// at the next launch, and the platform logs that it will.
  static Future<void> initialize(AnalyticsConfig config) {
    if (config.apiKey.trim().isEmpty) {
      throw ArgumentError.value(config.apiKey, 'apiKey', 'must not be blank');
    }
    if (!config.endpoint.startsWith('http')) {
      throw ArgumentError.value(config.endpoint, 'endpoint', 'must be an absolute http(s) URL');
    }
    if (config.flushBatchSize < 1 || config.flushBatchSize > _maxBatchSize) {
      throw ArgumentError.value(config.flushBatchSize, 'flushBatchSize', 'must be between 1 and $_maxBatchSize');
    }
    if (config.maxQueuedEvents < config.flushBatchSize) {
      throw ArgumentError.value(config.maxQueuedEvents, 'maxQueuedEvents', 'must be at least flushBatchSize');
    }
    return _call('initialize', () => _platform.initialize(config));
  }

  /// Records a custom event.
  ///
  /// Values may be a [String], a [num], a [bool], a date, or null (dropped). Types are kept end to
  /// end, so send `42` rather than `'42'` if you will ever filter on a range. A date goes out as ISO
  /// text, what a property declared `date` accepts: an [AnalyticsDay] as a calendar day
  /// (`2026-11-03`), a [DateTime] as an exact moment in UTC (`2026-11-03T09:00:00Z`). Anything else
  /// is sent as its string form, as the native SDKs do.
  static Future<void> track(String eventName, [Map<String, Object?> properties = const {}]) {
    if (eventName.startsWith(r'$')) {
      // The server rejects these anyway; refusing here points at the call site.
      debugPrint("[Analytics] Event names starting with '\$' are reserved — ignoring '$eventName'");
      return Future.value();
    }
    return _call('track', () => _platform.track(eventName, encodeProperties(properties)));
  }

  /// Records a screen view. `AnalyticsNavigatorObserver` calls this for pushed routes; call it
  /// yourself for what a route change cannot see — a tab, a page of a pager.
  static Future<void> screen(String screenName, [Map<String, Object?> properties = const {}]) =>
      _call('screen', () => _platform.screen(screenName, encodeProperties(properties)));

  /// Associates what follows with a known account, and updates their traits.
  ///
  /// Call at sign-in, at sign-up, and on every launch while signed in, before the first screen view
  /// of that launch. The `$identify` it sends carries the anonymous id and the user id together,
  /// and that is the link: there is no alias call. A *different* account than the one signed in is
  /// an account switch, which the SDK treats as a [reset] first. Traits take the same values as
  /// [track]'s properties, dates included.
  static Future<void> identify(String userId, [Map<String, Object?> traits = const {}]) =>
      _call('identify', () => _platform.identify(userId, encodeProperties(traits)));

  /// Uploads queued events now instead of waiting for the next interval.
  static Future<void> flush() => _call('flush', _platform.flush);

  /// Sign-out: a new anonymous id and a new session, so the next person to use the device does not
  /// inherit this one's identity. The device id is untouched.
  static Future<void> reset() => _call('reset', _platform.reset);

  /// Push: registering this install's token, the permission, and the taps.
  static const AnalyticsPush push = AnalyticsPush._();

  /// Notification topics: the app's list, and switching one on or off for this person.
  static const AnalyticsTopics topics = AnalyticsTopics._();

  /// The ingestion API's own per-batch limit.
  static const _maxBatchSize = 500;
}

/// Push, as the SDK sees it: a token to register, the permission, and taps to route. Reached as
/// `Analytics.push`.
///
/// Rendering a push and reporting its receipt are native and never pass through Dart: on Android
/// the app adds `sdk-android-fcm` (or hands messages to the SDK natively), on iOS a notification
/// service extension does it — both run when the app's Dart does not (docs/sdk-flutter.md, "Push").
final class AnalyticsPush {
  const AnalyticsPush._();

  /// Registers this install's push token with its [kind], one of [TokenKinds]. Sends `$push_token`
  /// only when something changed since the last one, so it is safe on every launch.
  Future<void> setToken(String token, {String kind = TokenKinds.fcm}) =>
      _call('push.setToken', () => AnalyticsPlatform.instance.setPushToken(token, kind));

  /// Re-registers the last token if the permission has changed under it. The SDKs call it
  /// themselves at startup; [requestPermission] calls it with the answer.
  Future<void> refreshToken() => _call('push.refreshToken', AnalyticsPlatform.instance.refreshPushToken);

  /// Asks the person for permission to show notifications — Android 13's runtime permission, iOS's
  /// authorization — and registers the answer. True when notifications are allowed afterwards. On
  /// iOS an answer of yes also registers for remote notifications. On Android the app's manifest
  /// must declare `android.permission.POST_NOTIFICATIONS`: neither the SDK nor the plugin does, so
  /// that a permission never reaches an app through the manifest merge, and without it the answer
  /// is false.
  Future<bool> requestPermission() =>
      _value('push.requestPermission', AnalyticsPlatform.instance.requestNotificationPermission, false);

  /// Whether a push can reach the person now. On Android this includes the SDK's own channel being
  /// switched on.
  Future<bool> notificationsEnabled() =>
      _value('push.notificationsEnabled', AnalyticsPlatform.instance.notificationsEnabled, false);

  /// The token this install last registered, or null. For a settings or debug screen.
  Future<String?> registeredToken() =>
      _value('push.registeredToken', AnalyticsPlatform.instance.registeredPushToken, null);

  /// Every tapped notification of ours, the one that started the app included. The SDK has already
  /// recorded the open; what is left is where to go, which only the app knows. Taps that arrive
  /// before anything listens are held for the first listener, so a cold start's tap is not lost
  /// while the app is still building its first screen.
  Stream<PushTap> get taps => AnalyticsPlatform.instance.pushTaps;
}

/// Notification topics: the kinds of message an app sends, each of which a person may switch off
/// or on. Reached as `Analytics.topics`.
///
/// The list is the dashboard's, never the app's: show what [fetch] returns, so a topic added in the
/// dashboard appears without a release. A choice belongs to the person, not the install.
final class AnalyticsTopics {
  const AnalyticsTopics._();

  /// Switches the topic [key] on or off for the current person. Queued and retried like every
  /// event, and shown by [fetch] at once, before the server holds it.
  Future<void> set(String key, {required bool subscribed}) {
    if (!_topicKey.hasMatch(key)) {
      debugPrint("[Analytics] '$key' is not a topic key (lowercase letters, digits and underscores) — ignoring");
      return Future.value();
    }
    return _call('topics.set', () => AnalyticsPlatform.instance.setTopic(key, subscribed));
  }

  /// The app's topics and this person's choice on each. Throws a [TopicsException] — offline, a
  /// 503, before [Analytics.initialize] — for the screen to show with a retry.
  Future<List<TopicChoice>> fetch() => AnalyticsPlatform.instance.fetchTopics();

  /// The server's rule for a key, so a typo is caught where it was made.
  static final _topicKey = RegExp(r'^[a-z][a-z0-9_]{0,63}$');
}

/// Runs a call whose failure is analytics' own and never the app's: logged and dropped. Only an
/// unsupported platform's [MissingPluginException] goes through.
Future<void> _call(String operation, Future<void> Function() body) async {
  try {
    await body();
  } on MissingPluginException {
    rethrow;
  } catch (error) {
    debugPrint('[Analytics] $operation failed: $error');
  }
}

Future<T> _value<T>(String operation, Future<T> Function() body, T fallback) async {
  try {
    return await body();
  } on MissingPluginException {
    rethrow;
  } catch (error) {
    debugPrint('[Analytics] $operation failed: $error');
    return fallback;
  }
}

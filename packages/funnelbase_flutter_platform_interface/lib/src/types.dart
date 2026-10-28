import 'package:flutter/foundation.dart';

/// How the SDK behaves. Only the key and the endpoint have no default.
///
/// The fields and their defaults are the native SDKs' own `AnalyticsConfig`, so one document
/// describes all three clients. What only one platform reads sits in [android] or [ios].
///
/// There is no `autoTrackScreenViews`: a Flutter app is one Activity and one view controller, so the
/// native automatic screen view would report the host's name on every foreground. The Android
/// package always turns it off, and screens are reported from Dart — by `AnalyticsNavigatorObserver`
/// or by `Analytics.screen`.
@immutable
class AnalyticsConfig {
  const AnalyticsConfig({
    required this.apiKey,
    required this.endpoint,
    this.flushIntervalSeconds = 30,
    this.flushBatchSize = 20,
    this.maxQueuedEvents = 1000,
    this.sessionTimeoutMinutes = 30,
    this.trackApplicationLifecycle = true,
    this.debugLogging = false,
    this.android = const AndroidOptions(),
    this.ios = const IosOptions(),
  });

  /// Issued per app and platform in the dashboard. Resolves server-side to a tenant and an app.
  final String apiKey;

  /// The ingestion API's base URL, such as `https://ingest.example.com`.
  final String endpoint;

  /// How often a partial batch is uploaded anyway.
  final int flushIntervalSeconds;

  /// Upload as soon as this many events are queued.
  final int flushBatchSize;

  /// The offline queue's cap; past it the oldest events are dropped.
  final int maxQueuedEvents;

  /// Inactivity before a new session starts. Android's SDK counts whole minutes, so there it is
  /// rounded to the nearest one, never below 1.
  final double sessionTimeoutMinutes;

  /// Uploads the queue when the app goes to the background, the last reliable moment before the
  /// process may be killed. Almost always right to leave on.
  final bool trackApplicationLifecycle;

  /// Logs queue and upload activity: logcat on Android, the console on iOS.
  final bool debugLogging;

  final AndroidOptions android;
  final IosOptions ios;

  @override
  bool operator ==(Object other) =>
      other is AnalyticsConfig &&
      other.apiKey == apiKey &&
      other.endpoint == endpoint &&
      other.flushIntervalSeconds == flushIntervalSeconds &&
      other.flushBatchSize == flushBatchSize &&
      other.maxQueuedEvents == maxQueuedEvents &&
      other.sessionTimeoutMinutes == sessionTimeoutMinutes &&
      other.trackApplicationLifecycle == trackApplicationLifecycle &&
      other.debugLogging == debugLogging &&
      other.android == android &&
      other.ios == ios;

  @override
  int get hashCode => Object.hash(apiKey, endpoint, flushIntervalSeconds, flushBatchSize, maxQueuedEvents,
      sessionTimeoutMinutes, trackApplicationLifecycle, debugLogging, android, ios);
}

/// What only the Android SDK reads: where a push is drawn.
@immutable
class AndroidOptions {
  const AndroidOptions({
    this.pushChannelId = 'analytics-push',
    this.pushChannelName = 'Notifications',
    this.pushSmallIcon,
    this.pushMaxImageBytes = 1000000,
  });

  /// The notification channel a push lands on when the message names none.
  final String pushChannelId;

  /// The channel's name in the system's notification settings.
  final String pushChannelName;

  /// The small icon every notification needs, as the name of a drawable in the app's Android
  /// resources (`ic_stat_notify`). Null means the app's own icon. A name rather than the native
  /// SDK's resource id, because an id only exists inside the Android build.
  final String? pushSmallIcon;

  /// The largest image downloaded for a rich notification.
  final int pushMaxImageBytes;

  @override
  bool operator ==(Object other) =>
      other is AndroidOptions &&
      other.pushChannelId == pushChannelId &&
      other.pushChannelName == pushChannelName &&
      other.pushSmallIcon == pushSmallIcon &&
      other.pushMaxImageBytes == pushMaxImageBytes;

  @override
  int get hashCode => Object.hash(pushChannelId, pushChannelName, pushSmallIcon, pushMaxImageBytes);
}

/// What only the iOS SDK reads.
@immutable
class IosOptions {
  const IosOptions({this.appGroup, this.registerApnsToken = false});

  /// The app group the app shares with its notification service extension, which is how a receipt
  /// the extension records reaches the app's queue (funnelbase-ios, docs/sdk-ios.md, "Why an app group").
  final String? appGroup;

  /// Registers Apple's own device token, as kind `apns`, whenever iOS issues one — for a deployment
  /// that sends to Apple directly. Off by default: an app on Firebase registers Firebase's token
  /// instead, and an install has one registration, so registering both would race.
  final bool registerApnsToken;

  @override
  bool operator ==(Object other) =>
      other is IosOptions && other.appGroup == appGroup && other.registerApnsToken == registerApnsToken;

  @override
  int get hashCode => Object.hash(appGroup, registerApnsToken);
}

/// What kind of address a push token is, as the registry records it.
abstract final class TokenKinds {
  /// Firebase Cloud Messaging, on Android and on Apple devices through Firebase.
  static const fcm = 'fcm';

  /// An Apple device token, for a deployment that talks to Apple directly.
  static const apns = 'apns';

  /// An id some other gateway understands, for a custom integration.
  static const opaque = 'opaque';
}

/// One action button under a notification. [id] is what the open reports as `action_id`.
@immutable
class PushButton {
  const PushButton({required this.id, required this.title, this.deepLink});

  final String id;
  final String title;

  /// Where this button leads, overriding the message's own deep link.
  final String? deepLink;

  @override
  bool operator ==(Object other) =>
      other is PushButton && other.id == id && other.title == title && other.deepLink == deepLink;

  @override
  int get hashCode => Object.hash(id, title, deepLink);
}

/// A push the platform sent, as it arrived.
@immutable
class PushPayload {
  const PushPayload({
    required this.deliveryId,
    required this.runId,
    this.title = '',
    this.body = '',
    this.imageUrl,
    this.deepLink,
    this.collapseKey,
    this.buttons = const [],
    this.data = const {},
  });

  final String deliveryId;
  final String runId;
  final String title;
  final String body;
  final String? imageUrl;
  final String? deepLink;
  final String? collapseKey;
  final List<PushButton> buttons;

  /// Whatever the campaign added, without the keys the delivery layer uses.
  final Map<String, String> data;

  @override
  bool operator ==(Object other) =>
      other is PushPayload &&
      other.deliveryId == deliveryId &&
      other.runId == runId &&
      other.title == title &&
      other.body == body &&
      other.imageUrl == imageUrl &&
      other.deepLink == deepLink &&
      other.collapseKey == collapseKey &&
      listEquals(other.buttons, buttons) &&
      mapEquals(other.data, data);

  @override
  int get hashCode =>
      Object.hash(deliveryId, runId, title, body, imageUrl, deepLink, collapseKey, Object.hashAll(buttons));
}

/// A tapped notification, handed to the app: the push, and which button was tapped, or null for
/// the notification itself. The SDK has already reported `$push_opened` by the time the app sees
/// one; what is left is routing, which only the app knows how to do.
@immutable
class PushTap {
  const PushTap({required this.payload, this.actionId});

  final PushPayload payload;
  final String? actionId;

  /// Where the tap leads: the tapped button's own link when it has one, else the message's.
  String? get link {
    final id = actionId;
    if (id != null) {
      for (final button in payload.buttons) {
        if (button.id == id && button.deepLink != null) return button.deepLink;
      }
    }
    return payload.deepLink;
  }

  @override
  bool operator ==(Object other) => other is PushTap && other.payload == payload && other.actionId == actionId;

  @override
  int get hashCode => Object.hash(payload, actionId);
}

/// One of the app's notification topics, and where this person stands on it.
@immutable
class TopicChoice {
  const TopicChoice({
    required this.key,
    required this.name,
    this.description,
    required this.subscribed,
    required this.chosen,
  });

  /// What the app and the campaigns name the topic by (`promotions`); never changes.
  final String key;

  /// What to show the person, as the dashboard names it.
  final String name;

  /// A line under the name, or null when the dashboard gave none.
  final String? description;

  /// Whether the person gets messages sent under this topic.
  final bool subscribed;

  /// Whether [subscribed] is the person's own choice rather than the topic's default.
  final bool chosen;

  @override
  bool operator ==(Object other) =>
      other is TopicChoice &&
      other.key == key &&
      other.name == name &&
      other.description == description &&
      other.subscribed == subscribed &&
      other.chosen == chosen;

  @override
  int get hashCode => Object.hash(key, name, description, subscribed, chosen);
}

/// Why the topics could not be read: the native SDKs' four cases.
sealed class TopicsException implements Exception {
  const TopicsException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The server answered, and not with a 2xx: `503 topics_unavailable`, a bad key's 401.
final class TopicsHttpException extends TopicsException {
  const TopicsHttpException(this.status, super.message);

  final int status;
}

/// No answer arrived: offline, a timeout, a refused connection.
final class TopicsNetworkException extends TopicsException {
  const TopicsNetworkException(super.message);
}

/// An answer arrived that is not the topics response.
final class TopicsMalformedException extends TopicsException {
  const TopicsMalformedException(super.message);
}

/// `Analytics.initialize` has not been called.
final class TopicsNotInitializedException extends TopicsException {
  const TopicsNotInitializedException() : super('Analytics.initialize has not been called');
}

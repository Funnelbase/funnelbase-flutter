// The channel between AnalyticsAndroid (Dart) and AnalyticsFlutterPlugin (Kotlin).
//
// Regenerate after a change, from this package's directory:
//
//     dart run pigeon --input pigeons/messages.dart
//
// The generated files are checked in, as every Pigeon user does: building the app needs no
// code generation step.
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    kotlinOut: 'android/src/main/kotlin/com/funnelbase/sdk/flutter/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.funnelbase.sdk.flutter'),
    dartPackageName: 'funnelbase_flutter_android',
  ),
)
/// `AnalyticsConfig` with its Android options flattened in, field for field the native
/// `com.funnelbase.sdk.AnalyticsConfig` less `autoTrackScreenViews`, which the plugin always turns
/// off.
class AndroidConfigMessage {
  AndroidConfigMessage({
    required this.apiKey,
    required this.endpoint,
    required this.flushIntervalSeconds,
    required this.flushBatchSize,
    required this.maxQueuedEvents,
    required this.sessionTimeoutMinutes,
    required this.trackApplicationLifecycle,
    required this.debugLogging,
    required this.pushChannelId,
    required this.pushChannelName,
    required this.pushSmallIcon,
    required this.pushMaxImageBytes,
  });

  String apiKey;
  String endpoint;
  int flushIntervalSeconds;
  int flushBatchSize;
  int maxQueuedEvents;
  double sessionTimeoutMinutes;
  bool trackApplicationLifecycle;
  bool debugLogging;
  String pushChannelId;
  String pushChannelName;

  /// A drawable's name, resolved to a resource id on the Kotlin side.
  String? pushSmallIcon;
  int pushMaxImageBytes;
}

class PushButtonMessage {
  PushButtonMessage({required this.id, required this.title, required this.deepLink});

  String id;
  String title;
  String? deepLink;
}

class PushPayloadMessage {
  PushPayloadMessage({
    required this.deliveryId,
    required this.runId,
    required this.title,
    required this.body,
    required this.imageUrl,
    required this.deepLink,
    required this.collapseKey,
    required this.buttons,
    required this.data,
  });

  String deliveryId;
  String runId;
  String title;
  String body;
  String? imageUrl;
  String? deepLink;
  String? collapseKey;
  List<PushButtonMessage> buttons;
  Map<String, String> data;
}

class PushTapMessage {
  PushTapMessage({required this.payload, required this.actionId});

  PushPayloadMessage payload;
  String? actionId;
}

class TopicChoiceMessage {
  TopicChoiceMessage({
    required this.key,
    required this.name,
    required this.description,
    required this.subscribed,
    required this.chosen,
  });

  String key;
  String name;
  String? description;
  bool subscribed;
  bool chosen;
}

/// One method per `AnalyticsPlatform` method, each onto the native SDK's own.
///
/// [fetchTopics] fails with a FlutterError whose code is `http` (details: the status), `network`,
/// `malformed` or `not_initialized` — the native `TopicsException`'s four cases.
@HostApi()
abstract class AnalyticsHostApi {
  void initialize(AndroidConfigMessage config);

  void track(String eventName, Map<String, Object> properties);

  void screen(String screenName, Map<String, Object> properties);

  void identify(String userId, Map<String, Object> traits);

  void flush();

  void reset();

  void setPushToken(String token, String kind);

  void refreshPushToken();

  bool notificationsEnabled();

  String? registeredPushToken();

  @async
  bool requestNotificationPermission();

  void setTopic(String key, bool subscribed);

  @async
  List<TopicChoiceMessage> fetchTopics();

  /// Dart is listening for taps: deliver the ones held since the process started, then each as it
  /// comes.
  void pushTapsReady();
}

@FlutterApi()
abstract class AnalyticsFlutterApi {
  void onPushTapped(PushTapMessage tap);
}

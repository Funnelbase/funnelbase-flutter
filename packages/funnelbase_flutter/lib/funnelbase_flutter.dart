/// The analytics SDK for Flutter apps: the same event contract as the Android and iOS SDKs,
/// because it is those SDKs — every call here goes to the native SDK on the device
/// (docs/sdk-flutter.md).
///
/// ```dart
/// await Analytics.initialize(const AnalyticsConfig(apiKey: key, endpoint: 'https://ingest.example.com'));
/// Analytics.track('checkout_completed', {'cart_total': 42.5, 'currency': 'EUR'});
/// ```
library;

export 'package:funnelbase_flutter_platform_interface/funnelbase_flutter_platform_interface.dart'
    show
        AnalyticsConfig,
        AndroidOptions,
        IosOptions,
        PushButton,
        PushPayload,
        PushTap,
        TokenKinds,
        TopicChoice,
        TopicsException,
        TopicsHttpException,
        TopicsMalformedException,
        TopicsNetworkException,
        TopicsNotInitializedException;

export 'src/analytics.dart';
export 'src/analytics_day.dart';
export 'src/navigator_observer.dart';

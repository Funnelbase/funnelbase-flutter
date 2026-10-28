# funnelbase_flutter_android

The Android implementation of [`funnelbase_flutter`](https://pub.dev/packages/funnelbase_flutter),
over the native Funnelbase Android SDK (`com.funnel-base:funnelbase-android`, from Maven Central).
Apps depend on `funnelbase_flutter`, which selects this package; nothing imports it directly.

- `pigeons/messages.dart` is the channel; regenerate with `dart run pigeon --input pigeons/messages.dart`.
- `AnalyticsFlutterInitProvider` starts the native SDK at process start from the configuration Dart
  last passed, so a push or a tap that starts the app before any Dart is not lost.
- `AnalyticsFlutter.doOnInitialized { … }` is for the app's own Kotlin that calls the native SDK,
  such as registering Firebase's token through `funnelbase-android-fcm`.

See [docs/sdk-flutter.md](https://github.com/Funnelbase/funnelbase-flutter/blob/main/docs/sdk-flutter.md).

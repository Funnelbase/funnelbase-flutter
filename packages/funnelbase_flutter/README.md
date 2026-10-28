# funnelbase_flutter

[Funnelbase](https://funnel-base.com) analytics and push for Flutter apps. Every call goes to the
native Funnelbase SDK on the device —
[funnelbase-android](https://github.com/Funnelbase/funnelbase-android) through
`funnelbase_flutter_android`,
[funnelbase-ios](https://github.com/Funnelbase/funnelbase-ios) through `funnelbase_flutter_ios` —
which owns the queue, the session, identity, the upload, push and topics. So a Flutter app sends
exactly what a native one does. Android and iOS only; any other platform throws.

## Install

```bash
flutter pub add funnelbase_flutter
```

- **iOS:** the plugin is Swift Package Manager only (no podspec) and needs iOS 16. Enable Flutter's
  SwiftPM integration in the app's `pubspec.yaml`:

  ```yaml
  flutter:
    config:
      enable-swift-package-manager: true
  ```

- **Android:** `minSdk` 26, and the app's Android build on AGP 9 with `android.newDsl=false` in
  `android/gradle.properties` (Flutter's documented opt-out for AGP 9). The native SDK comes from
  Maven Central (`com.funnel-base:funnelbase-android`) and needs Kotlin 2.2 or newer, which AGP
  9.1's built-in Kotlin already is.

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:funnelbase_flutter/funnelbase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Analytics.initialize(const AnalyticsConfig(
    apiKey: '<ingest key>',
    endpoint: 'https://ingest.example.com',
    ios: IosOptions(appGroup: 'group.com.example.app'),
  ));
  runApp(MaterialApp(navigatorObservers: [AnalyticsNavigatorObserver()], home: const Home()));
}

Analytics.track('instrument_viewed', {'symbol': 'AAPL'});
Analytics.identify(userId, {'username': name, 'plan_renews_on': AnalyticsDay(2026, 11, 3)});
Analytics.reset(); // at sign-out
```

An ingest key is issued for one platform, so an app that ships on both passes the key for the
platform it is running on.

On iOS, add one line to the app's `AppDelegate`, so a tap that launched the app is not lost:

```swift
import funnelbase_flutter_ios
// in application(_:didFinishLaunchingWithOptions:), before `return super.application(...)`:
AnalyticsFlutter.didFinishLaunching()
```

## Push

Rendering a push and reporting its receipt are native, because they happen when no Dart runs:

- **Android:** add `com.funnel-base:funnelbase-android-fcm` to the app's Android project for
  Firebase, or hand a token from another gateway over with
  `Analytics.push.setToken(token, kind: TokenKinds.opaque)`.
- **iOS:** a notification service extension subclassing `AnalyticsNotificationService` from the
  `FunnelbaseNotificationService` product of funnelbase-ios, sharing an app group with the app.

`Analytics.push.requestPermission()` asks for the permission, and `Analytics.push.taps` is a stream
of tapped notifications with the open already reported.

## More

- [The Flutter SDK in depth](https://github.com/Funnelbase/funnelbase-flutter/blob/main/docs/sdk-flutter.md):
  screens, starting before Dart, push, taps, building.
- [The event contract](https://github.com/Funnelbase/funnelbase-flutter/blob/main/docs/event-contract.md):
  what the SDKs send and why.
- [The demo app](https://github.com/Funnelbase/funnelbase-flutter/tree/main/demo-flutter).

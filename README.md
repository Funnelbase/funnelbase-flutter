# Funnelbase for Flutter

The Flutter SDK for [Funnelbase](https://funnel-base.com): product analytics, push notifications and
notification topics for Flutter apps on Android and iOS. It is a plugin over the native Funnelbase
SDKs — [funnelbase-android](https://github.com/Funnelbase/funnelbase-android) and
[funnelbase-ios](https://github.com/Funnelbase/funnelbase-ios) — so a Flutter app sends exactly what
a native one does.

| Package | |
|---|---|
| [`funnelbase_flutter`](packages/funnelbase_flutter) | What an app depends on and imports |
| [`funnelbase_flutter_platform_interface`](packages/funnelbase_flutter_platform_interface) | The contract between the app-facing package and the platforms |
| [`funnelbase_flutter_android`](packages/funnelbase_flutter_android) | The Android implementation |
| [`funnelbase_flutter_ios`](packages/funnelbase_flutter_ios) | The iOS implementation |
| [`demo-flutter`](demo-flutter) | A trading demo app, screen for screen like the native demos |

## Install

```bash
flutter pub add funnelbase_flutter
```

iOS needs Flutter's Swift Package Manager integration (`flutter: config:
enable-swift-package-manager: true` in the app's `pubspec.yaml`) and iOS 16; Android needs
`minSdk` 26, AGP 9 with `android.newDsl=false`, and Kotlin 2.2 or newer (AGP 9.1's built-in
Kotlin is enough). The
[package README](packages/funnelbase_flutter/README.md) has the quick start.

```dart
await Analytics.initialize(const AnalyticsConfig(apiKey: '<ingest key>', endpoint: 'https://ingest.example.com'));
Analytics.track('instrument_viewed', {'symbol': 'AAPL'});
Analytics.identify(userId, {'plan': 'pro'});
```

## Docs

- [docs/sdk-flutter.md](docs/sdk-flutter.md) — how the plugin works: packages, screens, starting
  before Dart, push and taps, building, the demo.
- [docs/event-contract.md](docs/event-contract.md) — what the SDKs send and what the server relies
  on it for.
- [docs/demo-app.md](docs/demo-app.md) — the demo's taxonomy, identity and data.

## Working in this repository

The four packages and the demo are one [pub workspace](https://dart.dev/tools/pub/workspaces):
each package depends on its siblings by version, and inside the workspace those versions resolve to
`packages/`.

```bash
flutter pub get                                   # at the root
(cd packages/funnelbase_flutter && flutter test)  # any package, or demo-flutter
```

Run `flutter pub get` at the root, where the workspace switches on Swift Package Manager. On macOS,
`flutter pub get` inside one of the packages stops with "only Swift Package Manager compatible"
unless it is switched on for the machine (`flutter config --enable-swift-package-manager`).

The native SDKs come from their registries: the Android SDK from Maven Central (or `mavenLocal()`
for an unreleased version), the iOS SDK from its git tags, or from a local checkout with
`FUNNELBASE_IOS_PATH=/path/to/funnelbase-ios`. [RELEASING.md](RELEASING.md) says how a version is
published.

## License

[Apache 2.0](LICENSE).

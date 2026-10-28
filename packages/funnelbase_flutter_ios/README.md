# funnelbase_flutter_ios

The iOS implementation of [`funnelbase_flutter`](https://pub.dev/packages/funnelbase_flutter), over
the native Funnelbase iOS SDK ([funnelbase-ios](https://github.com/Funnelbase/funnelbase-ios), a
Swift package). Apps depend on `funnelbase_flutter`, which selects this package; nothing imports it
directly.

- **SwiftPM only.** `ios/funnelbase_flutter_ios/Package.swift` depends on funnelbase-ios by version,
  so the app needs Flutter's Swift Package Manager integration (`flutter: config:
  enable-swift-package-manager: true` in its pubspec) and an iOS 16 deployment target. Set
  `FUNNELBASE_IOS_PATH` to a checkout of funnelbase-ios to build against that instead.
- **The channel is Pigeon's.** `pigeons/messages.dart` defines it; after a change run
  `dart run pigeon --input pigeons/messages.dart` and commit the generated files.

Why it starts the SDK before Dart, how taps reach Dart and what the app delegate needs:
[docs/sdk-flutter.md](https://github.com/Funnelbase/funnelbase-flutter/blob/main/docs/sdk-flutter.md).

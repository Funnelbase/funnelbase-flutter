# The Flutter SDK and its demo

`funnelbase_flutter` is a Flutter plugin over the two native Funnelbase SDKs, and the only client
that is not a copy of the [event contract](event-contract.md). Every call a Flutter app makes goes
to [funnelbase-android](https://github.com/Funnelbase/funnelbase-android) or
[funnelbase-ios](https://github.com/Funnelbase/funnelbase-ios) on the device, which own the queue,
the session, the identity, the upload, push and topics exactly as they do for a native app.
`demo-flutter` is the trading demo, ported screen for screen from the native demos, so a Flutter
client can be read beside the other two in one dashboard.

It is built on a few choices:

- **It wraps the native SDKs** rather than rewriting them in Dart. The contract is the expensive
  part to get right and keep right, and a wrapper adds no copy of it.
- **Federated packages**, one per role, and **Pigeon** for every channel — generated and typed,
  never a hand-written method channel.
- **Push stays native.** Rendering a push and reporting its receipt happen when no Dart is running.
- **Android and iOS only**, and anything else fails loudly.

## The packages

| Package | What it is |
|---|---|
| `funnelbase_flutter` | What an app depends on and imports: `Analytics`, `AnalyticsDay`, `AnalyticsNavigatorObserver`. Encodes property values, refuses what the server would refuse, and names the two platform packages as its defaults |
| `funnelbase_flutter_platform_interface` | The contract between them: the shared types and `AnalyticsPlatform`, whose default instance refuses every call |
| `funnelbase_flutter_android` | `AnalyticsPlatform` over the Android SDK: Pigeon's Kotlin side, the process-start initialiser, taps from the launch intent, the notification permission |
| `funnelbase_flutter_ios` | `AnalyticsPlatform` over the iOS SDK: Pigeon's Swift side, initialisation in `register(with:)`, the notification-center delegate, the APNs token |

Federated is Flutter's own structure for a plugin with an implementation per platform, and what
lets a platform be added — or replaced — without touching the others. Each platform package keeps
its own Pigeon definition (`pigeons/messages.dart`) because the two configs differ — an Android
channel and icon, an iOS app group — and checks the generated code in, as Flutter's own packages
do. A change to a Pigeon file is followed by `dart run pigeon --input pigeons/messages.dart` in that
package. A topic's description crosses as `topicDescription`, because Pigeon refuses a Swift field
named `description`.

Two conversions happen on the native side. iOS gives every number and boolean from the channel as
an `NSNumber`, and Swift's `as? Bool` accepts one holding 0 or 1, so the plugin gives each its own
type before the iOS SDK sees it — otherwise a Dart `1` would be sent as `true`. Android's session
timeout is whole minutes, so a fractional `sessionTimeoutMinutes` is rounded there, never below 1.

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Analytics.initialize(const AnalyticsConfig(
    apiKey: key,
    endpoint: 'https://ingest.example.com',
    ios: IosOptions(appGroup: 'group.com.example.app'),
  ));
  runApp(MaterialApp(navigatorObservers: [AnalyticsNavigatorObserver()], ...));
}

Analytics.track('instrument_viewed', {'symbol': 'AAPL'});
Analytics.identify(userId, {'username': name, 'plan_renews_on': AnalyticsDay(2026, 11, 3)});
```

The surface mirrors the native SDKs method for method — `initialize`, `track`, `screen`,
`identify`, `flush`, `reset`, `push`, `topics` — and `AnalyticsConfig` carries their fields and
defaults, with what only one platform reads under `android:` and `ios:`.

**What it costs to keep in step.** The contract lives in the native SDKs, so a change to the wire
format changes nothing here. A new *method* on the native SDKs does: it gets its Dart counterpart
in `funnelbase_flutter`, a line in the platform interface, and a method in both Pigeon files and
both implementations, in the same change.

**What the dashboard sees.** The native SDK sends the events, so `sdk_name` is `android` or `ios`
and a Flutter app's traffic is indistinguishable from a native one's. That is the point — one
product, one person — and an `app_version` is what tells builds apart.

## Values

The channel carries strings, numbers and booleans, so `funnelbase_flutter` encodes a property map
once, in Dart, with the native SDKs' own rules: null is dropped, an `AnalyticsDay` is `YYYY-MM-DD`,
a `DateTime` is ISO 8601 in UTC with `Z` to the millisecond and no fraction when there is none —
character for character what the Android and iOS SDKs write — an enum is its name, and anything
else is its string form. Dart has no day type, which is why `AnalyticsDay` exists, as it does on
iOS.

## Screens

A Flutter app is one Activity and one view controller, so the native automatic screen view would
report the host's name on every foreground and bury the real screens. The Android package therefore
always initialises with `autoTrackScreenViews = false` (iOS has none), and screens are reported from
Dart: `AnalyticsNavigatorObserver` reports a screen view when a page route is pushed, replaced or
uncovered by a pop, and `Analytics.screen` covers what a route change cannot see — a tab, a page of
a pager. Dialogs and sheets are not screens, and an unnamed route is skipped rather than reported as
`null`.

`screenNameExtractor` keeps screen names apart from route names: a route is an address, a screen
name is a dashboard dimension, and sharing one string means a routing refactor renames a chart's
series. A route that reports its own screens — a tab shell — is mapped to null, so nothing is
counted twice. The observer is a `RouteObserver`, so the same object is what a shell subscribes to
for "uncovered again".

## Before Dart runs

The native SDKs are initialised at process start, and two things depend on it: a push that starts
the process (Android's messaging service renders it, and an uninitialised SDK drops it) and a tap
that starts the app (the open is reported natively, before the app sees it). In a Flutter app the
first Dart runs much later, if at all — a push wakes a process with no Flutter engine.

So each platform package **remembers the config Dart last passed** and initialises the native SDK
with it at the next process start, before any Dart:

- **Android:** a `ContentProvider` in the plugin's manifest (`AnalyticsFlutterInitProvider`). The
  system creates content providers before `Application.onCreate`, so the SDK is ready before the
  messaging service or the tap activity runs, and before the first Activity starts — which is also
  what lets the lifecycle tracker see it.
- **iOS:** `AnalyticsFlutter.didFinishLaunching()`, one line the app's `AppDelegate` calls in
  `application(_:didFinishLaunchingWithOptions:)` before `super`. It has to be the app's line:
  under the scene lifecycle Flutter's current template uses (`FlutterImplicitEngineDelegate`),
  plugins are registered when the engine starts, which can be after launching finishes — and a tap
  that launched the app is delivered to whatever notification-center delegate exists by then. So the
  hook starts the SDK from the stored config and installs a delegate of the plugin's own: our taps
  are reported there and held process-wide until the plugin attaches, our pushes in the foreground
  are shown with banner, sound and list, and everything else goes to the delegate that was there
  before, or to the `FlutterAppDelegate`, which hands it to every plugin. An app without the line
  still starts the SDK in `register(with:)` and still gets taps through `FlutterAppDelegate`'s
  forwarding, except, possibly, the one that launched it.

  ```swift
  import funnelbase_flutter_ios
  // in application(_:didFinishLaunchingWithOptions:), before `return super.application(...)`:
  AnalyticsFlutter.didFinishLaunching()
  ```

Dart's `Analytics.initialize` then finds the SDK running. With the same config it does nothing;
with a different one — a rotated key, a new endpoint — it stores the new one and logs that it takes
effect at the next launch, because the native SDKs initialise once per process. On the very first
launch nothing is stored yet and Dart's call initialises the SDK; on Android that is after the first
Activity started, so that one process sees no "came to the foreground" refresh of the push token.

The consequence to know about: an app that stops calling `initialize` — a build with no key — still
initialises at the next launch from what an earlier build stored. Clearing the app's data clears it.

## Push

Rendering and the receipt never pass through Dart, because they happen when no Dart is running.

- **Android:** the app's own Android project adds `com.funnel-base:funnelbase-android-fcm`, whose one
  messaging service renders Funnelbase's data messages and registers the token. Its token is
  fetched with `AnalyticsMessagingService.registerCurrentToken`, which needs the SDK initialised;
  the plugin's Kotlin hook `AnalyticsFlutter.doOnInitialized { }` runs it then, whichever path
  initialised it — the demo's `MainApplication` is the example. An app on another gateway hands its
  token over from Dart with `Analytics.push.setToken(token, kind: TokenKinds.opaque)`.
- **iOS:** a notification service extension subclassing `AnalyticsNotificationService` (the
  `FunnelbaseNotificationService` product of funnelbase-ios), with an app group shared with the
  app — funnelbase-ios's docs/sdk-ios.md says why both are needed. With
  `IosOptions(registerApnsToken: true)` the plugin registers Apple's device token as kind `apns`
  whenever iOS issues one, and asks for it at startup when notifications are already allowed. It is
  off by default because an install has one registration: an app on Firebase registers Firebase's
  token instead, and registering both would race.

`Analytics.push.requestPermission()` asks — Android 13's runtime permission, iOS's authorization —
and re-registers the token with the answer, because the token's `status` *is* the permission.

**Taps.** `Analytics.push.taps` is a stream of every tapped notification of ours, with the open
already reported. On Android the SDK's tap activity reports the open and starts the app's launcher
with the push attached, and the plugin reads it from the launch intent or `onNewIntent`, removing
it so a rotation does not deliver it twice; on iOS the hook's delegate (or, without the hook,
`FlutterAppDelegate`'s forwarding) calls `Analytics.push.handle(response:)`, and one response is
reported once whichever path hears it. Either way a tap is held natively until Dart is listening,
and the stream holds taps until its first listener, so the tap that launched the app reaches the
app however late it subscribes. Routing is the app's: `PushTap.link` is the tapped button's link,
else the message's.

An app — or `firebase_messaging` — that sets its own notification-center delegate after the hook
keeps working as long as it forwards what it does not handle to the delegate it replaced, which
`firebase_messaging` does.

**`firebase_messaging` beside it** is not needed and not used by the demo. On Android it receives
through a receiver of its own and the SDK's service ignores pushes that are not Funnelbase's, so the
two should coexist; that, and its iOS delegate swizzling, have not been checked on a device yet.

## Platforms

Android and iOS only. `funnelbase_flutter` names no default for any other platform, so the platform
interface's default instance stays in place and every call throws a `MissingPluginException` saying
so. An app that also builds for the web or a desktop guards its calls there; the failure is meant to
be seen in testing rather than discovered as a gap on a dashboard.

## Building

**iOS** is Swift Package Manager only — there is no podspec. A Flutter app enables it in its
`pubspec.yaml` and targets iOS 16, the SDK's floor:

```yaml
flutter:
  config:
    enable-swift-package-manager: true
```

The plugin's `Package.swift` depends on `https://github.com/Funnelbase/funnelbase-ios.git` by
version. With `FUNNELBASE_IOS_PATH` set to a checkout of funnelbase-ios in the shell that runs the
build, it depends on that directory instead — how an unreleased version is built, and how someone
works on both repositories at once.

**Android** takes `com.funnel-base:funnelbase-android` from Maven Central. The native SDK is built
with AGP 9 and its built-in Kotlin, so the app's Android build runs AGP 9 too, and because
Flutter's Gradle plugin reads only AGP's old DSL, `android/gradle.properties` sets
`android.newDsl=false` (Flutter's documented opt-out) and the app module applies no `kotlin-android`.
The SDK is compiled for Kotlin 2.2 consumers (funnelbase-android's catalog says how), so AGP 9.1's
built-in Kotlin reads it and the app needs no Kotlin plugin of its own.
The plugin also lists `mavenLocal()`, after Maven Central, so a version not released yet resolves
from `./gradlew publishToMavenLocal` in funnelbase-android.

**In this repository** the four packages and the demo are one pub workspace: each package depends
on its siblings by version, as it does once published, and inside the workspace those versions
resolve to `packages/`. Run `flutter pub get` at the root.

## The demo app

`demo-flutter` is the native demos screen for screen — the same thirteen screen names, one custom
event (`instrument_viewed` with `symbol`), the traits `username`, `plan` and, on the sign-in
screen's Pro plan switch, `plan_renews_on` as an `AnalyticsDay`, and the same SHA-256 user id,
pinned by a test to the same literal, because one person has to be one person on all three
clients. [demo-app.md](demo-app.md) describes the taxonomy, identity and the data. Its ids are
`com.analytics.demo.trading.flutter` on both platforms, so it installs beside the native demos.

**Configuration.** Create an app in the Funnelbase dashboard (Manage → Apps), enable the Android
and iOS platforms and generate a key for each; the plaintext is shown once. Declare
`instrument_viewed` with a required string `symbol` under Data → Event catalog. The key is a
credential, so it is not in the repository: `config.json` (gitignored) is a copy of
`config.example.json` with an ingest key per platform — a key is issued for one platform and
refused for the other — passed as `--dart-define-from-file`. With no key the app runs and
initialises nothing. The endpoints default to the emulator's `10.0.2.2:8080` and the simulator's
`localhost:8080`, a backend on the same machine; a physical device wants the host's LAN address.

```bash
flutter pub get                          # at the repository root
cd demo-flutter
cp config.example.json config.json       # then fill in the two keys
flutter run --dart-define-from-file=config.json           # -d <device>
```

**Screens.** `AnalyticsNavigatorObserver` reports the pushed routes through a route → screen-name
map (`Routes.screenFor`), which returns null for the tab shell and the sign-up pager: the shell
reports its tab when it first shows, on a tab change and when a pop uncovers it, and the pager
reports a page once it has settled, never mid-drag.

**Push.** The Notifications screen shows the permission, the token (an opaque one of your own when
there is no Firebase), "Choose topics", and three simulate buttons. Simulating is native by nature
— rendering never passes through Dart — so the demo has a small channel of its own,
`trade_demo/native`: on Android it hands the data map to `Analytics.push.handleMessage`, so the
notification, its buttons, `$push_received` and the tap are all the SDK's; on iOS it posts a local
notification with the same payload. The same channel opens the system's notification settings. Taps
are listened to from startup and routed by `lib/push/push_routing.dart`.

- **Android:** `MainApplication` runs `AnalyticsFlutter.doOnInitialized {
  AnalyticsMessagingService.registerCurrentToken(it) }`; `funnelbase-android-fcm` is always linked
  and the Google services plugin applied only when `android/app/google-services.json` exists; the
  manifest declares `POST_NOTIFICATIONS`; debug builds allow cleartext to `10.0.2.2`, `localhost`
  and `127.0.0.1` only.
- **iOS:** `AppDelegate` calls `AnalyticsFlutter.didFinishLaunching()` and registers the demo's
  channel in `didInitializeImplicitFlutterEngine`, where the scene lifecycle registers plugins. A
  `NotificationService` extension subclasses `AnalyticsNotificationService` through a package
  reference to funnelbase-ios, and shares `group.com.analytics.demo.trading.flutter` with the app;
  `IosOptions(registerApnsToken: true)` registers Apple's token, since the demo talks to Apple
  directly. No team is committed: `ios/Flutter/Signing.example.xcconfig` is copied to the gitignored
  `Signing.xcconfig` for a device build, and a simulator needs none. The extension's package
  reference is to the released funnelbase-ios; to build against a local checkout, open
  `ios/Runner.xcworkspace` and drag the checkout in as a local package, which overrides it.

**Persistence** is a small JSON file in the app's support directory through `path_provider`, not
`shared_preferences`: the latter's Android side applies the `kotlin-android` plugin, which AGP 9's
built-in Kotlin refuses. `crypto` (the user id) and `intl` (money in en-US whatever the device's
locale) are the other dependencies.

**On a device.** `integration_test/device_walk_test.dart` walks the sign-up, an instrument and
the tabs through the real plugin and the real native SDK, as `walk-<platform>`; it exists because an
iOS simulator cannot be tapped from a script. What landed is read back on the dashboard's Sessions
page, filtered to that person.

```bash
flutter test integration_test --dart-define-from-file=config.json -d <device>
```

## Tests

- `flutter test` in each of the four packages: the value encoding, the refusals, the navigator
  observer, the unsupported platform; and in each platform package the message mapping, the topic
  errors and tap buffering against a fake host API.
- `flutter test` in `demo-flutter`: ports of the native demo's tests, and a widget test that walks
  the sign-up and the tabs against a fake platform and asserts the exact screen-view sequence.
- `integration_test/` in `demo-flutter`, by hand on a device or simulator, as above.
- CI (`.github/workflows/ci.yml`) runs `flutter analyze` and `flutter test` for all five on Linux.
  The native halves are tested in the native SDKs' own repositories.

## Left out

- **Flutter web and desktop.**
- **A podspec.** CocoaPods apps wait until one is asked for.
- **`handleMessage` from Dart**, for an app that receives pushes in Dart. Rendering belongs to the
  native side, where it works with the app dead.
- **A go_router integration.** `AnalyticsNavigatorObserver` goes in a `GoRouter`'s `observers`, and
  a shell route's tabs report themselves.

# funnelbase-flutter

The Funnelbase Flutter SDK: a federated plugin over the native SDKs, never a copy of them —
`funnelbase_flutter` (what apps import), `funnelbase_flutter_platform_interface`,
`funnelbase_flutter_android` (over `com.funnel-base:funnelbase-android` from Maven Central) and
`funnelbase_flutter_ios` (over the `Funnelbase` Swift package from funnelbase-ios), plus
`demo-flutter`, the trading app screen for screen with the native demos. One pub workspace;
published to pub.dev under the verified publisher funnel-base.com. Public repository, Apache 2.0.

Read before changing an area: [docs/sdk-flutter.md](docs/sdk-flutter.md) (the design, how the
native SDKs are linked, push, what was left out), [docs/event-contract.md](docs/event-contract.md),
[docs/demo-app.md](docs/demo-app.md), [RELEASING.md](RELEASING.md).

## Rules

- **No copy of the contract here.** Events, identity, sessions and the queue are the native SDKs'.
  Values are encoded once in Dart (`AnalyticsDay`, moments in UTC) and handed over. A wire change
  needs nothing here; a new or changed public method on the native SDKs gets its Dart counterpart,
  a line in the platform interface and both Pigeon files in the same change, after the native
  versions are released.
- **Every channel is Pigeon's.** Edit `pigeons/messages.dart` in the platform package, then
  `dart run pigeon --input pigeons/messages.dart` there, and commit the generated files. Never
  edit a `*.g.*` file by hand.
- **Push stays native.** Rendering and the receipt run where no Dart does; taps are held until Dart
  listens.
- **Android and iOS only.** Other platforms fail loudly (`MissingPluginException`), never a silent
  no-op.
- **Stored names stay.** SharedPreferences `"analytics_flutter"`, the UserDefaults key
  `"analytics_flutter.config"` and the provider authority `analytics-flutter-init` are on users'
  devices; renaming them forgets their config.
- **Packages depend on each other by version** (`^0.1.0`), resolved to `packages/` by the
  workspace, so each publishes as it is. Raise the native SDK versions (the Maven coordinates in
  `funnelbase_flutter_android`, the `from:` in `funnelbase_flutter_ios`'s `Package.swift`) only to
  released versions; `mavenLocal()` and `FUNNELBASE_IOS_PATH` are for building against unreleased
  ones.
- **No secrets in the repo.** `demo-flutter/config.json` (ingest keys), `google-services.json`,
  `GoogleService-Info.plist` and `ios/Flutter/Signing.xcconfig` are gitignored.

## Checks

```bash
flutter pub get                       # at the root: the whole workspace
# then in each of packages/* and demo-flutter:
flutter analyze && flutter test
flutter pub publish --dry-run         # packages only: must report 0 warnings
# the demo against the native SDKs:
(cd demo-flutter && flutter build apk --debug)
(cd demo-flutter && flutter build ios --simulator --debug)
```

## Working here

- Every change on its own branch (`feature/`, `fix/`, `change-request/`, `refactor/`, `chore/`,
  `docs/` + a slug) cut from `origin/main`, through a pull request. Nothing is committed until
  the maintainer approves opening the PR, and nothing merged until they approve that separately.
- Ask before pushing anything to GitHub: this repository is public.
- **A release is irreversible.** A version on pub.dev can never be deleted or reused. A tag
  `<package>-v<version>` publishes that package from GitHub Actions; order: platform interface,
  then the two platform packages, then `funnelbase_flutter`. Never tag without being asked
  (RELEASING.md).
- Commits are authored as `Funnelbase <349443583+Funnelbase@users.noreply.github.com>`.

# Releasing

The four packages are published to [pub.dev](https://pub.dev) under the Funnelbase verified
publisher, each with its own version and tag.

## Order

A package can be published only once everything it depends on is published, so a release goes:

1. **The native SDKs it names**, if their versions are new: `com.funnel-base:funnelbase-android`
   (and `-fcm`) on Maven Central, the version in
   `packages/funnelbase_flutter_android/android/build.gradle.kts` (`funnelbaseAndroidVersion`) and
   the demo's `android/app/build.gradle.kts`; and a funnelbase-ios tag, the version in
   `packages/funnelbase_flutter_ios/ios/funnelbase_flutter_ios/Package.swift` (`from:`) and the
   demo's Xcode package reference.
2. `funnelbase_flutter_platform_interface`
3. `funnelbase_flutter_android` and `funnelbase_flutter_ios`
4. `funnelbase_flutter`

## A release

1. Raise `version:` in the package's `pubspec.yaml`, add its entry to the package's `CHANGELOG.md`,
   and raise the constraint (`^x.y.z`) in every sibling that needs the new version.
2. `flutter pub get` at the root, then `dart pub publish --dry-run` in the package: it must report
   no warnings.
3. Merge to `main`, then push a tag named `<package>-v<version>`, for example
   `funnelbase_flutter_platform_interface-v0.1.0`. The `publish` workflow publishes that package from
   the tag; it refuses a tag whose version is not the one in the pubspec.

Releases are not undoable: pub.dev keeps every published version (a version can be retracted for 7
days, never deleted).

## The first version of each package, by hand

pub.dev's automated publishing is switched on from a package's admin page, which exists only once
the package has been published. So the first version of each package is published from a
maintainer's machine, in the order above:

```bash
dart pub login                       # as a member of the Funnelbase publisher
cd packages/funnelbase_flutter_platform_interface
dart pub publish                     # then each of the others, in order
```

Then, for each package, on pub.dev → the package → Admin:

1. **Transfer it to the Funnelbase publisher** (the verified publisher for `funnel-base.com`).
2. **Automated publishing → Enable publishing from GitHub Actions**, repository
   `Funnelbase/funnelbase-flutter`, tag pattern `<package>-v{{version}}`, for example
   `funnelbase_flutter-v{{version}}`, and require the `pub.dev` environment.

From then on a tag is a release. The workflow authenticates with GitHub's OIDC token, so the
repository holds **no pub.dev secret**. It runs in a GitHub environment named `pub.dev`; adding
required reviewers to that environment (Settings → Environments) makes each publish wait for a
maintainer's approval.

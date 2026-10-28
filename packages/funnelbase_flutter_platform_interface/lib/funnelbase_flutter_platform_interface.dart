/// The contract between `funnelbase_flutter`, which apps call, and the packages that implement it on
/// one platform each: `funnelbase_flutter_android` over `sdk-android` and `funnelbase_flutter_ios`
/// over `sdk-ios` (docs/sdk-flutter.md).
///
/// Apps never import this package. It holds what both sides have to agree on: the types that cross
/// it, and [AnalyticsPlatform], the one object a platform package replaces.
library;

export 'src/analytics_platform.dart';
export 'src/types.dart';

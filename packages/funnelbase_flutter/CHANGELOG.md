## 0.2.0

- Over funnelbase-android 0.5.0 and funnelbase-ios 0.3.0 (through funnelbase_flutter_android and
  funnelbase_flutter_ios 0.2.0): a push token registration or a topic choice counts as sent only once
  the server accepts a batch carrying it, and one refused for good (such as `403 plan_limit` while a
  free workspace is over its plan) is sent again at the next launch or return to the front. The Dart
  API is unchanged.

## 0.1.0

- First version: the Dart API over the native Funnelbase SDKs, funnelbase-android 0.4.0 and
  funnelbase-ios 0.2.0.

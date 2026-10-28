import 'analytics_day.dart';

/// Converts an app's property map to what crosses the channel: strings, numbers and booleans.
///
/// The same rules as the native SDKs' own conversion, applied here because a date has no type the
/// channel carries: null is dropped, a day is `YYYY-MM-DD`, a moment is ISO 8601 in UTC with `Z`
/// to the millisecond, and anything else is its string form. Done once, in Dart, so the platform
/// packages pass a map through without a rule of their own.
Map<String, Object> encodeProperties(Map<String, Object?> properties) {
  final encoded = <String, Object>{};
  properties.forEach((key, value) {
    switch (value) {
      case null:
        // The backend discards nulls anyway, and sending them wastes bytes on a mobile connection.
        break;
      case String() || bool() || num():
        encoded[key] = value;
      case AnalyticsDay():
        encoded[key] = value.toString();
      case DateTime():
        encoded[key] = isoMoment(value);
      case Enum():
        encoded[key] = value.name;
      default:
        // Better than silently dropping a property the caller expected to see in the dashboard.
        encoded[key] = value.toString();
    }
  });
  return encoded;
}

/// ISO 8601 in UTC with `Z`, to the millisecond, with no fraction when there is none — character for
/// character what Android's `Instant.truncatedTo(MILLIS).toString()` and iOS's `WireJson.moment`
/// write, so all three clients send the same text for the same instant.
String isoMoment(DateTime moment) {
  final utc = moment.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  final whole = '${utc.year.toString().padLeft(4, '0')}-${two(utc.month)}-${two(utc.day)}'
      'T${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}';
  return utc.millisecond == 0 ? '${whole}Z' : '$whole.${utc.millisecond.toString().padLeft(3, '0')}Z';
}

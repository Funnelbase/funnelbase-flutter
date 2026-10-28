/// Every custom event this app sends, in one place.
///
/// Unlike screen views these are not free: ingestion rejects a custom event the app's catalog does
/// not declare, so each name here needs a definition under Data → Event catalog in the dashboard
/// before the app runs against a fresh app (docs/demo-app.md).
///
/// Screen views carry `screen_name` and nothing else. What was looked at, rather than where the
/// person is, belongs here, as its own event.
abstract final class Events {
  /// An instrument's detail page was shown.
  static const instrumentViewed = 'instrument_viewed';

  /// Ticker of the instrument, on [instrumentViewed].
  static const propertySymbol = 'symbol';
}

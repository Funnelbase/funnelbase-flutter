import 'package:flutter/foundation.dart';

/// A calendar day with no time and no zone — a plan's renewal day, a birthday — read in whichever
/// zone asks. Sent as `YYYY-MM-DD`, what a property or trait declared `date` in the catalog accepts
/// (docs/event-contract.md, "Dates"). The mirror of `java.time.LocalDate` on Android and
/// `AnalyticsDay` on iOS.
///
/// A [DateTime] is the other kind of date: an exact moment, sent in UTC with `Z`. Use this type
/// when the value is a day, so it does not shift by the device's offset on the way.
@immutable
class AnalyticsDay {
  /// The day as given. Nothing is normalised: `AnalyticsDay(2026, 2, 30)` is sent as written and
  /// refused by ingestion, the same as a wrong type would be.
  const AnalyticsDay(this.year, this.month, this.day);

  /// The day [moment] falls on where it is: local time for a local [DateTime], UTC for a UTC one.
  AnalyticsDay.of(DateTime moment) : this(moment.year, moment.month, moment.day);

  final int year;
  final int month;
  final int day;

  /// `YYYY-MM-DD`.
  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is AnalyticsDay && other.year == year && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);
}

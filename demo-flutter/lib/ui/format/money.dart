import 'package:intl/intl.dart';

/// Every number the person sees passes through here.
///
/// Fixed to `en-US`/USD rather than the device locale: the instruments are priced in dollars, and
/// formatting them with the phone's locale would render a dollar amount with European grouping —
/// the digits right and the currency a lie. The same rule as demo-android's `Money.kt`.
abstract final class Money {
  static const _locale = 'en_US';

  static final _usd = NumberFormat.currency(locale: _locale, symbol: r'$', decimalDigits: 2);
  static final _integer = NumberFormat.decimalPattern(_locale);

  /// `$1,234.56`.
  static String usd(double value) => _usd.format(value);

  /// `+$1,234.56` / `-$1,234.56` — always signed, because a change without a sign is ambiguous.
  static String signedUsd(double value) => '${value >= 0 ? '+' : '-'}${usd(value.abs())}';

  /// `+1.24%` / `-1.24%`.
  static String signedPercent(double value) => '${value >= 0 ? '+' : '-'}${value.abs().toStringAsFixed(2)}%';

  /// `1,250` — quantities are whole shares, so no decimals.
  static String quantity(int value) => _integer.format(value);

  /// `12.4M`, `1.02B` — full digits would dominate a row that is mostly prices.
  static String compact(double value) {
    final size = value.abs();
    if (size >= 1e12) return '${(value / 1e12).toStringAsFixed(2)}T';
    if (size >= 1e9) return '${(value / 1e9).toStringAsFixed(2)}B';
    if (size >= 1e6) return '${(value / 1e6).toStringAsFixed(1)}M';
    if (size >= 1e3) return '${(value / 1e3).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }

  static String compactUsd(double value) => '\$${compact(value)}';

  /// `3m ago`, `4h ago`, `2d ago`.
  static String relativeTime(int minutesAgo) {
    if (minutesAgo < 60) return '${minutesAgo}m ago';
    if (minutesAgo < 60 * 24) return '${minutesAgo ~/ 60}h ago';
    return '${minutesAgo ~/ (60 * 24)}d ago';
  }
}

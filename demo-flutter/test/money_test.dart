import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:trade_demo/ui/format/money.dart';

void main() {
  /// The point of pinning the locale rather than taking the device's: with tr-TR as the default, a
  /// device-locale formatter would render `$1.234,56` — a dollar amount with Turkish grouping.
  test('formats as en-US regardless of the default locale', () {
    final original = Intl.defaultLocale;
    try {
      Intl.defaultLocale = 'tr_TR';
      expect(Money.usd(1234.56), r'$1,234.56');
      expect(Money.quantity(1250), '1,250');
    } finally {
      Intl.defaultLocale = original;
    }
  });

  test('changes always carry a sign', () {
    expect(Money.signedUsd(12.5), r'+$12.50');
    expect(Money.signedUsd(-12.5), r'-$12.50');
    // Zero reads as up, matching ChangeText treating >= 0 as a rise.
    expect(Money.signedUsd(0), r'+$0.00');
    expect(Money.signedPercent(1.2449), '+1.24%');
    expect(Money.signedPercent(-1.2449), '-1.24%');
  });

  test('compact notation switches at each magnitude', () {
    expect(Money.compact(7800000), '7.8M');
    expect(Money.compact(1530000000), '1.53B');
    expect(Money.compact(1530000000000), '1.53T');
    expect(Money.compact(950), '950');
  });

  test('relative time collapses into the right unit', () {
    expect(Money.relativeTime(11), '11m ago');
    expect(Money.relativeTime(125), '2h ago');
    expect(Money.relativeTime(60 * 24 * 3 + 5), '3d ago');
  });
}

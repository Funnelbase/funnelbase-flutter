import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:trade_demo/data/market_data.dart';
import 'package:trade_demo/data/orders.dart';

/// Invariants of the generated data, ported from demo-android's `MarketDataTest`.
///
/// The prices are random by design, so these assert the *shape* rather than any value — which is
/// what caught the two bugs these were written after: an `abs()` in the rounding helper that turned
/// the whole market green, and news ages that were not monotonic.
void main() {
  MarketData generate(int seed) => MarketData.generate(Random(seed));

  test('fifty instruments, all distinct', () {
    final instruments = generate(1).instruments;
    expect(instruments, hasLength(50));
    expect(instruments.map((i) => i.symbol).toSet(), hasLength(50));
  });

  test('changes go both ways', () {
    // Across 50 instruments a fair coin gives all-one-direction odds of about 1 in 5.6e14. If this
    // fails, the sign is being lost somewhere, not drawn unluckily.
    final changes = generate(7).instruments.map((i) => i.changePercent);
    expect(changes.any((c) => c < 0), isTrue, reason: 'no instrument fell — is the sign being stripped?');
    expect(changes.any((c) => c > 0), isTrue, reason: 'no instrument rose');
  });

  test("the day's range contains the day", () {
    for (final i in generate(3).instruments) {
      expect(i.dayLow <= i.price && i.price <= i.dayHigh, isTrue, reason: '${i.symbol}: price outside range');
      expect(i.dayLow <= i.open && i.open <= i.dayHigh, isTrue, reason: '${i.symbol}: open outside range');
      expect(i.dayLow <= i.previousClose && i.previousClose <= i.dayHigh, isTrue,
          reason: '${i.symbol}: previous close outside range');
    }
  });

  test('change percent agrees with previous close', () {
    for (final i in generate(5).instruments) {
      final implied = (i.price - i.previousClose) / i.previousClose * 100;
      expect((implied - i.changePercent).abs(), lessThan(0.01), reason: i.symbol);
    }
  });

  test('order cost is quantity times price', () {
    for (final o in generate(9).orders) {
      expect(o.cost, closeTo(o.quantity * o.price, 1e-9));
    }
  });

  test('every order status is represented, so no chip is ever empty', () {
    expect(generate(11).orders.map((o) => o.status).toSet(), OrderStatus.values.toSet());
  });

  test('portfolio total is invested plus cash, and day change is summed from holdings', () {
    final portfolio = generate(13).portfolio;
    expect(portfolio.totalValue, closeTo(portfolio.investedValue + portfolio.cashUsd, 1e-9));
    final summed = portfolio.holdings.fold<double>(0, (s, h) => s + h.quantity * h.instrument.changeAbsolute);
    expect(portfolio.dayChange, closeTo(summed, 1e-9));
  });

  test('orders and holdings reference instruments from the same generated set', () {
    // Why MarketData exists at all: three screens showing three prices for AAPL.
    final data = generate(17);
    final symbols = data.instruments.map((i) => i.symbol).toSet();
    expect(data.orders.every((o) => symbols.contains(o.symbol)), isTrue);
    expect(data.portfolio.holdings.every((h) => symbols.contains(h.instrument.symbol)), isTrue);
    expect(data.news.every((a) => symbols.any((s) => a.headline.startsWith('$s:'))), isTrue);
  });

  test('news is ordered most recent first', () {
    final ages = generate(19).news.map((a) => a.minutesAgo).toList();
    expect(ages, [...ages]..sort());
  });

  test('default favourites are non-empty so the dashboard card has content', () {
    expect(generate(23).defaultFavourites, isNotEmpty);
  });
}

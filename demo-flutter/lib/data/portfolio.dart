import 'dart:math';

import 'instruments.dart';
import 'random_range.dart';

class Holding {
  const Holding(this.instrument, this.quantity);

  final Instrument instrument;
  final int quantity;

  double get marketValue => quantity * instrument.price;
  double get dayChange => quantity * instrument.changeAbsolute;
}

/// The signed-in person's positions. Day change is summed from the holdings rather than generated,
/// so the dashboard's percentage is the one the Markets screen implies.
class Portfolio {
  const Portfolio({required this.holdings, required this.cashUsd});

  final List<Holding> holdings;
  final double cashUsd;

  double get investedValue => holdings.fold(0, (sum, h) => sum + h.marketValue);
  double get totalValue => investedValue + cashUsd;
  double get dayChange => holdings.fold(0, (sum, h) => sum + h.dayChange);

  /// Against yesterday's close of the same positions; cash does not move, so it is excluded.
  double get dayChangePercent {
    final previous = investedValue - dayChange;
    return previous <= 0 ? 0 : dayChange / previous * 100;
  }

  bool get isUp => dayChange >= 0;
}

abstract final class Portfolios {
  static Portfolio generate(Random random, List<Instrument> instruments) {
    final held = ([...instruments]..shuffle(random)).take(random.nextIntIn(5, 9));
    return Portfolio(
      holdings: [for (final i in held) Holding(i, random.pick(_quantities))],
      cashUsd: (random.nextDoubleIn(1500, 25000) * 100).roundToDouble() / 100,
    );
  }

  static const _quantities = [4, 8, 12, 15, 20, 30, 45, 60, 80, 120];
}

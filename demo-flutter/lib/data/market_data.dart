import 'dart:math';

import 'instruments.dart';
import 'news.dart';
import 'orders.dart';
import 'portfolio.dart';

/// Everything the app displays, generated once per process.
///
/// One object rather than one generator per screen: the portfolio, the orders and the news all
/// reference instruments, and regenerating per screen would show three different prices for AAPL
/// depending on the tab. Deliberately unseeded and unpersisted — a fresh set every launch.
class MarketData {
  MarketData._({required this.instruments, required this.portfolio, required this.orders, required this.news})
      : _bySymbol = {for (final i in instruments) i.symbol: i};

  final List<Instrument> instruments;
  final Portfolio portfolio;
  final List<Order> orders;
  final List<NewsArticle> news;
  final Map<String, Instrument> _bySymbol;

  Instrument? instrument(String symbol) => _bySymbol[symbol];

  /// The symbols favourited by default on a first run, so the dashboard is never empty.
  Set<String> get defaultFavourites => instruments.take(4).map((i) => i.symbol).toSet();

  /// Built on first use rather than in `main` — not much work, but not work for the first frame.
  static final MarketData current = generate(Random());

  static MarketData generate(Random random) {
    final instruments = Instruments.generate(random);
    return MarketData._(
      instruments: instruments,
      portfolio: Portfolios.generate(random, instruments),
      orders: Orders.generate(random, instruments),
      news: News.generate(random, instruments),
    );
  }
}

import 'dart:math';

import 'lorem.dart';
import 'random_range.dart';

/// One tradable instrument, priced.
///
/// [changePercent] is the day's move and [price] is already the post-move price, so
/// [previousClose] is derived rather than stored — one of the two would otherwise be free to drift
/// out of agreement with the other.
class Instrument {
  const Instrument({
    required this.symbol,
    required this.name,
    required this.sector,
    required this.price,
    required this.changePercent,
    required this.dayHigh,
    required this.dayLow,
    required this.open,
    required this.volume,
    required this.marketCapUsd,
    required this.about,
  });

  final String symbol;
  final String name;
  final String sector;
  final double price;
  final double changePercent;
  final double dayHigh;
  final double dayLow;
  final double open;
  final int volume;
  final double marketCapUsd;
  final String about;

  double get previousClose => price / (1 + changePercent / 100);
  double get changeAbsolute => price - previousClose;
  bool get isUp => changePercent >= 0;
}

/// The instrument universe: 50 S&P 500 constituents, priced randomly at every launch.
///
/// Random per launch is the deliberate choice — the app demonstrates the analytics SDK, not a
/// market data feed, and re-rolling every run makes it obvious nothing here is real. The *band*
/// each price is drawn from is per ticker though, so a share of Berkshire never costs less than a
/// share of Ford.
abstract final class Instruments {
  static const _universe = [
    _Ticker('AAPL', 'Apple Inc.', 'Technology', 180, 240),
    _Ticker('MSFT', 'Microsoft Corporation', 'Technology', 380, 470),
    _Ticker('NVDA', 'NVIDIA Corporation', 'Technology', 95, 145),
    _Ticker('AMZN', 'Amazon.com, Inc.', 'Consumer Discretionary', 170, 230),
    _Ticker('GOOGL', 'Alphabet Inc.', 'Communication Services', 140, 200),
    _Ticker('META', 'Meta Platforms, Inc.', 'Communication Services', 440, 620),
    _Ticker('TSLA', 'Tesla, Inc.', 'Consumer Discretionary', 180, 400),
    _Ticker('BRK.B', 'Berkshire Hathaway Inc.', 'Financials', 400, 490),
    _Ticker('JPM', 'JPMorgan Chase & Co.', 'Financials', 190, 260),
    _Ticker('V', 'Visa Inc.', 'Financials', 260, 320),
    _Ticker('UNH', 'UnitedHealth Group Inc.', 'Health Care', 450, 600),
    _Ticker('XOM', 'Exxon Mobil Corporation', 'Energy', 100, 125),
    _Ticker('JNJ', 'Johnson & Johnson', 'Health Care', 140, 170),
    _Ticker('MA', 'Mastercard Incorporated', 'Financials', 420, 540),
    _Ticker('PG', 'Procter & Gamble Co.', 'Consumer Staples', 150, 180),
    _Ticker('HD', 'The Home Depot, Inc.', 'Consumer Discretionary', 320, 420),
    _Ticker('COST', 'Costco Wholesale Corporation', 'Consumer Staples', 700, 990),
    _Ticker('ABBV', 'AbbVie Inc.', 'Health Care', 160, 205),
    _Ticker('MRK', 'Merck & Co., Inc.', 'Health Care', 95, 135),
    _Ticker('AVGO', 'Broadcom Inc.', 'Technology', 130, 250),
    _Ticker('LLY', 'Eli Lilly and Company', 'Health Care', 700, 960),
    _Ticker('PEP', 'PepsiCo, Inc.', 'Consumer Staples', 140, 180),
    _Ticker('KO', 'The Coca-Cola Company', 'Consumer Staples', 58, 74),
    _Ticker('WMT', 'Walmart Inc.', 'Consumer Staples', 60, 100),
    _Ticker('BAC', 'Bank of America Corporation', 'Financials', 34, 48),
    _Ticker('CVX', 'Chevron Corporation', 'Energy', 135, 170),
    _Ticker('ADBE', 'Adobe Inc.', 'Technology', 400, 580),
    _Ticker('CRM', 'Salesforce, Inc.', 'Technology', 230, 360),
    _Ticker('NFLX', 'Netflix, Inc.', 'Communication Services', 600, 950),
    _Ticker('AMD', 'Advanced Micro Devices, Inc.', 'Technology', 110, 210),
    _Ticker('INTC', 'Intel Corporation', 'Technology', 19, 45),
    _Ticker('CSCO', 'Cisco Systems, Inc.', 'Technology', 46, 62),
    _Ticker('ACN', 'Accenture plc', 'Technology', 300, 390),
    _Ticker('MCD', "McDonald's Corporation", 'Consumer Discretionary', 250, 320),
    _Ticker('TMO', 'Thermo Fisher Scientific Inc.', 'Health Care', 480, 620),
    _Ticker('ABT', 'Abbott Laboratories', 'Health Care', 100, 130),
    _Ticker('DIS', 'The Walt Disney Company', 'Communication Services', 84, 120),
    _Ticker('VZ', 'Verizon Communications Inc.', 'Communication Services', 38, 46),
    _Ticker('INTU', 'Intuit Inc.', 'Technology', 550, 720),
    _Ticker('QCOM', 'QUALCOMM Incorporated', 'Technology', 145, 220),
    _Ticker('TXN', 'Texas Instruments Incorporated', 'Technology', 160, 210),
    _Ticker('NKE', 'NIKE, Inc.', 'Consumer Discretionary', 60, 100),
    _Ticker('PFE', 'Pfizer Inc.', 'Health Care', 23, 32),
    _Ticker('CAT', 'Caterpillar Inc.', 'Industrials', 300, 420),
    _Ticker('GE', 'GE Aerospace', 'Industrials', 150, 210),
    _Ticker('BA', 'The Boeing Company', 'Industrials', 130, 200),
    _Ticker('UPS', 'United Parcel Service, Inc.', 'Industrials', 95, 145),
    _Ticker('HON', 'Honeywell International Inc.', 'Industrials', 190, 230),
    _Ticker('GS', 'The Goldman Sachs Group, Inc.', 'Financials', 420, 610),
    _Ticker('F', 'Ford Motor Company', 'Consumer Discretionary', 9, 14),
  ];

  /// Every instrument, priced for this launch, in the order shown on the Markets screen.
  static List<Instrument> generate(Random random) => [for (final t in _universe) t.priced(random)];

  // No abs() here. It was tempting, since every price is positive — but changePercent goes through
  // the same helper, and stripping its sign made every instrument in the list green.
  static double round2(double value) => (value * 100).roundToDouble() / 100;
}

class _Ticker {
  const _Ticker(this.symbol, this.name, this.sector, this.low, this.high);

  final String symbol;
  final String name;
  final String sector;
  final double low;
  final double high;

  Instrument priced(Random random) {
    final price = Instruments.round2(random.nextDoubleIn(low, high));
    // ±5%, as a day's move. Bounded rather than normal: a list where one row shows -40% reads as a
    // bug rather than as a market.
    final changePercent = Instruments.round2(random.nextDoubleIn(-5, 5));
    final previousClose = price / (1 + changePercent / 100);

    // The day's range must contain both ends of the day, or the detail screen shows a high below
    // the current price.
    final spread = price * random.nextDoubleIn(0.005, 0.03);
    final dayHigh = Instruments.round2(max(price, previousClose) + spread);
    final dayLow = Instruments.round2(min(price, previousClose) - spread);
    final open = Instruments.round2(random.nextDoubleIn(dayLow, dayHigh));

    return Instrument(
      symbol: symbol,
      name: name,
      sector: sector,
      price: price,
      changePercent: changePercent,
      dayHigh: dayHigh,
      dayLow: dayLow,
      open: open,
      volume: random.nextIntIn(2000000, 90000000),
      // Shares outstanding, 400M to 9B: past what nextInt can draw, so scaled from a double.
      marketCapUsd: price * random.nextDoubleIn(4e8, 9e9).roundToDouble(),
      about: '$name operates in the ${sector.toLowerCase()} sector. ${Lorem.paragraph(random, 4)}',
    );
  }
}

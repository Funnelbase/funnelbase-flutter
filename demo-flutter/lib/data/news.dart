import 'dart:math';

import 'instruments.dart';
import 'lorem.dart';
import 'random_range.dart';

class NewsArticle {
  const NewsArticle({
    required this.id,
    required this.headline,
    required this.summary,
    required this.source,
    required this.minutesAgo,
  });

  final String id;
  final String headline;
  final String summary;
  final String source;
  final int minutesAgo;
}

/// The news feed. Headlines are prefixed with a real ticker from this launch so the feed looks like
/// it belongs to this app, while the body stays obviously synthetic.
abstract final class News {
  static const _sources = ['Market Wire', 'Global Desk', 'Trading Floor', 'The Ticker Report'];

  static List<NewsArticle> generate(Random random, List<Instrument> instruments, {int count = 20}) {
    // Accumulated, not `index * random(...)`: multiplying is not monotonic — article 1 could draw
    // 69 and article 2 draw 2×9=18 — and the feed would show "1h ago" above "12m ago".
    var minutesAgo = 0;
    return List.generate(count, (index) {
      final instrument = random.pick(instruments);
      minutesAgo += random.nextIntIn(9, 70);
      return NewsArticle(
        id: 'news-$index',
        headline: '${instrument.symbol}: ${Lorem.headline(random)}',
        summary: Lorem.paragraph(random, random.nextIntIn(2, 4)),
        source: random.pick(_sources),
        minutesAgo: minutesAgo,
      );
    });
  }
}

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../format/money.dart';
import '../theme.dart';

/// The fourth tab: the generated news feed, most recent first.
class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final news = AppScope.of(context).market.news;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('News')),
      body: ListView.separated(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: news.length,
        separatorBuilder: (_, _) => const Divider(),
        itemBuilder: (_, index) {
          final article = news[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(article.headline, style: text.titleSmall),
                const SizedBox(height: 6),
                Text(article.summary, style: text.bodyMedium?.copyWith(color: TradeColors.textSecondary)),
                const SizedBox(height: 8),
                Text(
                  '${article.source} · ${Money.relativeTime(article.minutesAgo)}',
                  style: text.labelSmall?.copyWith(color: TradeColors.textSecondary),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

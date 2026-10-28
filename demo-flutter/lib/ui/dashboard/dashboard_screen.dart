import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../data/instruments.dart';
import '../../data/news.dart';
import '../common/components.dart';
import '../format/money.dart';
import '../nav/routes.dart';
import '../theme.dart';

/// The first tab. Its screen view is the tab shell's to report.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onSeeAllNews});

  final VoidCallback onSeeAllNews;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final market = state.market;
    final favourites = market.instruments.where((i) => state.isFavourite(i.symbol)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dashboard'),
            if (state.username != null)
              Text(
                'Signed in as ${state.username}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: TradeColors.textSecondary),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none),
            onPressed: () => Navigator.pushNamed(context, Routes.push),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () {
              state.signOut();
              // The signed-in screens must not remain behind the welcome page.
              Navigator.pushNamedAndRemoveUntil(context, Routes.welcome, (_) => false);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          _PortfolioValueCard(state),
          const SizedBox(height: 16),
          _FavouritesCard(favourites),
          const SizedBox(height: 16),
          _RecentNewsCard(market.news.take(3).toList(), onSeeAll: onSeeAllNews),
        ],
      ),
    );
  }
}

class _PortfolioValueCard extends StatelessWidget {
  const _PortfolioValueCard(this.state);

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final portfolio = state.market.portfolio;
    final text = Theme.of(context).textTheme;
    return SectionCard(children: [
      Text('Portfolio value', style: text.labelLarge?.copyWith(color: TradeColors.textSecondary)),
      const SizedBox(height: 6),
      Text(
        Money.usd(portfolio.totalValue),
        style: numericStyle.copyWith(fontSize: 32, fontWeight: FontWeight.bold, color: TradeColors.textPrimary),
      ),
      const SizedBox(height: 8),
      ChangeText(portfolio.dayChangePercent, absolute: portfolio.dayChange),
      Text('Today', style: text.bodySmall?.copyWith(color: TradeColors.textSecondary)),
      const SizedBox(height: 16),
      const Divider(),
      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _LabelledAmount('Invested', Money.usd(portfolio.investedValue)),
          _LabelledAmount('Cash', Money.usd(portfolio.cashUsd)),
          _LabelledAmount('Positions', '${portfolio.holdings.length}'),
        ],
      ),
    ]);
  }
}

class _LabelledAmount extends StatelessWidget {
  const _LabelledAmount(this.label, this.value);

  final String label;
  final String value;

  // Scaled down rather than overflowing when a six-figure portfolio meets a narrow phone.
  @override
  Widget build(BuildContext context) => Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: TradeColors.textSecondary)),
              Text(value, style: numericStyle.copyWith(color: TradeColors.textPrimary)),
            ],
          ),
        ),
      );
}

class _FavouritesCard extends StatelessWidget {
  const _FavouritesCard(this.favourites);

  final List<Instrument> favourites;

  @override
  Widget build(BuildContext context) {
    return SectionCard(children: [
      const SectionHeader('Favourite instruments'),
      const SizedBox(height: 4),
      if (favourites.isEmpty)
        const Hint('Nothing favourited yet. Tap the star on any instrument in Markets.', top: 12),
      for (final instrument in favourites)
        InkWell(
          onTap: () => Navigator.pushNamed(context, Routes.instrument(instrument.symbol)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(child: InstrumentTitle(instrument)),
                InstrumentPrice(instrument),
              ],
            ),
          ),
        ),
    ]);
  }
}

class _RecentNewsCard extends StatelessWidget {
  const _RecentNewsCard(this.articles, {required this.onSeeAll});

  final List<NewsArticle> articles;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SectionCard(children: [
      SectionHeader('Recent news', action: TextButton(onPressed: onSeeAll, child: const Text('See all'))),
      for (final article in articles)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(article.headline, style: text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(
                '${article.source} · ${Money.relativeTime(article.minutesAgo)}',
                style: text.bodySmall?.copyWith(color: TradeColors.textSecondary),
              ),
            ],
          ),
        ),
    ]);
  }
}

/// Symbol over company name, the left half of every instrument row.
class InstrumentTitle extends StatelessWidget {
  const InstrumentTitle(this.instrument, {super.key});

  final Instrument instrument;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(instrument.symbol, style: Theme.of(context).textTheme.titleSmall),
          Text(
            instrument.name,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: TradeColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
}

/// Price over the day's move, the right half of every instrument row.
class InstrumentPrice extends StatelessWidget {
  const InstrumentPrice(this.instrument, {super.key});

  final Instrument instrument;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(Money.usd(instrument.price), style: numericStyle.copyWith(color: TradeColors.textPrimary)),
          ChangeText(instrument.changePercent),
        ],
      );
}

import 'package:funnelbase_flutter/funnelbase_flutter.dart';
import 'package:flutter/material.dart';

import '../../analytics/events.dart';
import '../../app_state.dart';
import '../common/components.dart';
import '../format/money.dart';
import '../nav/nav_scope.dart';
import '../theme.dart';

/// One instrument. The screen view is the navigator observer's (`instrument_detail`); which
/// instrument it is is a product fact, not navigation, so it is its own event, `instrument_viewed`,
/// sent on the same rule: on arriving, and again on being uncovered — never on a rebuild.
class InstrumentScreen extends StatefulWidget {
  const InstrumentScreen({super.key, required this.symbol});

  final String symbol;

  @override
  State<InstrumentScreen> createState() => _InstrumentScreenState();
}

class _InstrumentScreenState extends State<InstrumentScreen> with RouteAware {
  AnalyticsNavigatorObserver? _observer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final observer = NavScope.of(context).observer;
    final route = ModalRoute.of(context);
    if (observer == _observer || route == null) return;
    _observer?.unsubscribe(this);
    _observer = observer..subscribe(this, route);
  }

  @override
  void dispose() {
    _observer?.unsubscribe(this);
    super.dispose();
  }

  void _viewed() {
    // A bad deep link shows a screen, but no instrument was viewed.
    if (AppScope.of(context).market.instrument(widget.symbol) == null) return;
    Analytics.track(Events.instrumentViewed, {Events.propertySymbol: widget.symbol});
  }

  @override
  void didPush() => _viewed();

  @override
  void didPopNext() => _viewed();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final instrument = state.market.instrument(widget.symbol);

    // Reachable only in principle — every way in comes from the same instrument set — but a crash
    // on a bad deep link is a worse answer than a back button.
    if (instrument == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('No instrument ${widget.symbol}', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
            ],
          ),
        ),
      );
    }

    final favourite = state.isFavourite(instrument.symbol);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(instrument.symbol),
        actions: [
          IconButton(
            tooltip: favourite ? 'Remove from favourites' : 'Add to favourites',
            icon: Icon(
              favourite ? Icons.star : Icons.star_border,
              color: favourite ? TradeColors.accent : TradeColors.textSecondary,
            ),
            onPressed: () => state.toggleFavourite(instrument.symbol),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Text(instrument.name, style: text.titleMedium),
          const SizedBox(height: 4),
          Align(alignment: Alignment.centerLeft, child: Pill(instrument.sector, color: TradeColors.accent)),
          const SizedBox(height: 16),
          Text(
            Money.usd(instrument.price),
            style: numericStyle.copyWith(fontSize: 34, fontWeight: FontWeight.bold, color: TradeColors.textPrimary),
          ),
          const SizedBox(height: 6),
          ChangeText(instrument.changePercent, absolute: instrument.changeAbsolute),
          const SizedBox(height: 16),
          SectionCard(children: [
            Text('Today', style: text.titleMedium),
            const SizedBox(height: 12),
            StatRow('Open', Money.usd(instrument.open)),
            StatRow('Day high', Money.usd(instrument.dayHigh)),
            StatRow('Day low', Money.usd(instrument.dayLow)),
            StatRow('Previous close', Money.usd(instrument.previousClose)),
            StatRow('Volume', Money.compact(instrument.volume.toDouble())),
            StatRow('Market cap', Money.compactUsd(instrument.marketCapUsd)),
          ]),
          const SizedBox(height: 16),
          SectionCard(children: [
            Text('About the company', style: text.titleMedium),
            const SizedBox(height: 8),
            Text(instrument.about, style: text.bodyMedium?.copyWith(color: TradeColors.textSecondary)),
          ]),
          const SizedBox(height: 16),
          // Deliberately inert: wiring these up would mean order placement, which this demo does not
          // have, and a disabled button says so where a silent one would not.
          const Padding(
            padding: EdgeInsets.only(bottom: 24),
            child: Row(
              children: [
                Expanded(child: FilledButton(onPressed: null, child: Text('Buy'))),
                SizedBox(width: 12),
                Expanded(child: OutlinedButton(onPressed: null, child: Text('Sell'))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

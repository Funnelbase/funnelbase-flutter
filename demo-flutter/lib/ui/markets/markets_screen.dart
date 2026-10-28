import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../dashboard/dashboard_screen.dart';
import '../nav/routes.dart';
import '../theme.dart';

/// The second tab: every instrument, with a star to favourite it.
class MarketsScreen extends StatelessWidget {
  const MarketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final instruments = state.market.instruments;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Markets'),
            Text(
              '${instruments.length} instruments · S&P 500',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: TradeColors.textSecondary),
            ),
          ],
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: instruments.length,
        separatorBuilder: (_, _) => const Divider(),
        itemBuilder: (context, index) {
          final instrument = instruments[index];
          final favourite = state.isFavourite(instrument.symbol);
          return InkWell(
            onTap: () => Navigator.pushNamed(context, Routes.instrument(instrument.symbol)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 16, 10),
              child: Row(
                children: [
                  IconButton(
                    // The label says what the tap does, not what the icon looks like.
                    tooltip: favourite
                        ? 'Remove ${instrument.symbol} from favourites'
                        : 'Add ${instrument.symbol} to favourites',
                    icon: Icon(
                      favourite ? Icons.star : Icons.star_border,
                      color: favourite ? TradeColors.accent : TradeColors.textSecondary,
                    ),
                    onPressed: () => state.toggleFavourite(instrument.symbol),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: InstrumentTitle(instrument)),
                  InstrumentPrice(instrument),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../format/money.dart';
import '../theme.dart';

/// A price move. The glyph is not decoration: green-up/red-down is a hue distinction roughly one
/// man in twelve cannot make, so direction is always carried by ▲/▼ as well.
class ChangeText extends StatelessWidget {
  const ChangeText(this.changePercent, {super.key, this.absolute});

  final double changePercent;
  final double? absolute;

  @override
  Widget build(BuildContext context) {
    final up = changePercent >= 0;
    final amount = absolute;
    return Text(
      '${up ? '▲' : '▼'} ${amount != null ? '${Money.signedUsd(amount)}  ' : ''}${Money.signedPercent(changePercent)}',
      style: numericStyle.copyWith(color: up ? TradeColors.up : TradeColors.down),
    );
  }
}

/// A card. One corner radius and one border colour for the whole app.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: TradeColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TradeColors.outline),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}

/// A section heading with an optional trailing action, such as "See all".
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          ?action,
        ],
      );
}

/// A small filled pill — order status, sector, side.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
      );
}

/// A `Label  Value` row whose value is monospaced, so a stack of them has a straight right edge.
class StatRow extends StatelessWidget {
  const StatRow(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: TradeColors.textSecondary)),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                style: numericStyle.copyWith(color: TradeColors.textPrimary),
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
}

/// Secondary text, the colour every hint and caption in the app uses.
class Hint extends StatelessWidget {
  const Hint(this.text, {super.key, this.top = 4, this.color = TradeColors.textSecondary});

  final String text;
  final double top;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: top),
        child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
      );
}

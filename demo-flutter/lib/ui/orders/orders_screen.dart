import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../data/orders.dart';
import '../common/components.dart';
import '../format/money.dart';
import '../theme.dart';

/// The third tab. The status chips filter within the screen: they are not navigation, so they
/// report nothing — only screen and tab changes are screen views.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  var _selected = OrderStatus.pending;

  @override
  Widget build(BuildContext context) {
    final orders = AppScope.of(context).market.orders;
    final visible = orders.where((o) => o.status == _selected).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              children: [
                for (final status in OrderStatus.values)
                  FilterChip(
                    selected: _selected == status,
                    showCheckmark: false,
                    selectedColor: TradeColors.accentMuted,
                    label: Text('${status.label} (${orders.where((o) => o.status == status).length})'),
                    onSelected: (_) => setState(() => _selected = status),
                  ),
              ],
            ),
          ),
          if (visible.isEmpty)
            Padding(padding: const EdgeInsets.all(24), child: Hint('No ${_selected.label.toLowerCase()} orders.'))
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: visible.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (_, index) => _OrderRow(visible[index]),
              ),
            ),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow(this.order);

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(order.symbol, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(width: 8),
              Pill(order.side.label.toUpperCase(), color: order.side == OrderSide.buy ? TradeColors.up : TradeColors.down),
              const Spacer(),
              Pill(order.status.label, color: _statusColor(order.status)),
            ],
          ),
          Text(
            '${order.companyName} · ${order.id} · ${Money.relativeTime(order.placedMinutesAgo)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: TradeColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          StatRow('Quantity', Money.quantity(order.quantity)),
          StatRow('Price', Money.usd(order.price)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Cost', style: TextStyle(color: TradeColors.textSecondary)),
              // The one figure someone checks against quantity × price, so it gets the emphasis.
              Text(Money.usd(order.cost), style: numericStyle.copyWith(color: TradeColors.accent)),
            ],
          ),
        ],
      ),
    );
  }

  static Color _statusColor(OrderStatus status) => switch (status) {
        OrderStatus.pending => TradeColors.pending,
        OrderStatus.filled => TradeColors.filled,
        OrderStatus.cancelled => TradeColors.cancelled,
      };
}

import 'dart:math';

import 'instruments.dart';
import 'random_range.dart';

enum OrderStatus {
  pending('Pending'),
  filled('Filled'),
  cancelled('Cancelled');

  const OrderStatus(this.label);
  final String label;
}

enum OrderSide {
  buy('Buy'),
  sell('Sell');

  const OrderSide(this.label);
  final String label;
}

/// One order. [cost] is computed, not stored, so quantity × price and the displayed total can never
/// disagree — exactly what a reader checks with a calculator on a demo screen.
class Order {
  const Order({
    required this.id,
    required this.symbol,
    required this.companyName,
    required this.side,
    required this.status,
    required this.quantity,
    required this.price,
    required this.placedMinutesAgo,
  });

  final String id;
  final String symbol;
  final String companyName;
  final OrderSide side;
  final OrderStatus status;
  final int quantity;
  final double price;
  final int placedMinutesAgo;

  double get cost => quantity * price;
}

abstract final class Orders {
  /// Sample orders across all three statuses, priced off this launch's instruments so an order for
  /// AAPL sits in the range AAPL does on the Markets screen. Filled orders sit slightly off the
  /// current price — one that filled at exactly the current price would be a coincidence per row.
  static List<Order> generate(Random random, List<Instrument> instruments) {
    final statuses = [
      ...List.filled(7, OrderStatus.pending),
      ...List.filled(8, OrderStatus.filled),
      ...List.filled(5, OrderStatus.cancelled),
    ];

    final orders = <Order>[];
    for (var index = 0; index < statuses.length; index++) {
      final status = statuses[index];
      final instrument = random.pick(instruments);
      final drift = switch (status) {
        OrderStatus.filled => random.nextDoubleIn(-0.04, 0.04),
        // A resting limit order sits away from the market, which is why it is resting.
        OrderStatus.pending => random.nextDoubleIn(-0.08, 0.08),
        OrderStatus.cancelled => random.nextDoubleIn(-0.12, 0.12),
      };
      orders.add(Order(
        id: 'ORD-${random.nextIntIn(10000, 99999).toString().padLeft(5, '0')}',
        symbol: instrument.symbol,
        companyName: instrument.name,
        side: random.nextBool() ? OrderSide.buy : OrderSide.sell,
        status: status,
        quantity: random.pick(_quantities),
        price: (instrument.price * (1 + drift) * 100).roundToDouble() / 100,
        placedMinutesAgo: (index + 1) * random.nextIntIn(7, 90),
      ));
    }
    return orders..sort((a, b) => a.placedMinutesAgo.compareTo(b.placedMinutesAgo));
  }

  // Round lots, the way someone actually types an order.
  static const _quantities = [5, 10, 15, 20, 25, 40, 50, 75, 100, 120, 150, 200, 250, 500];
}

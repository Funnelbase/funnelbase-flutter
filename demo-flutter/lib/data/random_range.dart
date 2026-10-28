import 'dart:math';

/// Kotlin's `Random` ranges, which the generators were written against: [from] inclusive, [until]
/// exclusive.
extension RandomRange on Random {
  int nextIntIn(int from, int until) => from + nextInt(until - from);

  double nextDoubleIn(double from, double until) => from + nextDouble() * (until - from);

  T pick<T>(List<T> items) => items[nextInt(items.length)];
}

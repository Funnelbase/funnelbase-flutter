import 'package:flutter_test/flutter_test.dart';
import 'package:trade_demo/identity/user_id.dart';

/// The determinism these assert is the whole reason the demo can have accounts without an auth
/// backend — and the reason "ada" is one person across the three demos and the simulated history.
void main() {
  test('same username always yields the same id', () {
    expect(UserId.forUsername('ada'), UserId.forUsername('ada'));
  });

  test('id is stable across runs and across the demos', () {
    // Pinned to the literal demo-android's UserIdTest pins: comparing two live calls would still
    // pass if the algorithm changed, and changing it invalidates every user_id already stored.
    expect(UserId.forUsername('ada'), 'u_fdee430d40bd57de');
  });

  test('case and surrounding whitespace do not make a different person', () {
    final expected = UserId.forUsername('ada');
    expect(UserId.forUsername('  ADA  '), expected);
    expect(UserId.forUsername('Ada'), expected);
  });

  test('different usernames yield different ids', () {
    expect(UserId.forUsername('ada'), isNot(UserId.forUsername('grace')));
  });

  test('id is prefixed and 16 hex characters wide', () {
    final id = UserId.forUsername('grace');
    expect(id, hasLength(18));
    expect(id, matches(RegExp(r'^u_[0-9a-f]{16}$')));
  });
}

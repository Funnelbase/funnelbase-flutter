import 'dart:math';

import 'random_range.dart';

/// Lorem ipsum, generated rather than pasted: real punctuation and capitalisation, so filler reads
/// as prose at a glance instead of as an obvious block of test data.
abstract final class Lorem {
  static final _words = ('lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor '
          'incididunt ut labore et dolore magna aliqua enim ad minim veniam quis nostrud '
          'exercitation ullamco laboris nisi aliquip ex ea commodo consequat duis aute irure '
          'in reprehenderit voluptate velit esse cillum eu fugiat nulla pariatur excepteur '
          'sint occaecat cupidatat non proident sunt culpa qui officia deserunt mollit anim '
          'id est laborum perspiciatis unde omnis iste natus error accusantium doloremque')
      .split(' ');

  /// One sentence, capitalised and full-stopped.
  static String sentence(Random random, [int? wordCount]) {
    final count = wordCount ?? random.nextIntIn(8, 16);
    final text = List.generate(count, (_) => random.pick(_words)).join(' ');
    return '${text[0].toUpperCase()}${text.substring(1)}.';
  }

  /// A paragraph of [sentences] sentences.
  static String paragraph(Random random, [int? sentences]) =>
      List.generate(sentences ?? random.nextIntIn(3, 6), (_) => sentence(random)).join(' ');

  /// A headline: title-cased, no full stop, and short — a sixteen-word headline wraps to three
  /// lines in a list row and stops looking like one.
  static String headline(Random random, [int? wordCount]) => List.generate(
        wordCount ?? random.nextIntIn(4, 8),
        (_) {
          final word = random.pick(_words);
          return '${word[0].toUpperCase()}${word.substring(1)}';
        },
      ).join(' ');
}

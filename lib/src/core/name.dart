/// An identifier typed by the user, normalised into the casings generators
/// need (`OrderDetail`, `orderDetail`, `order_detail`, `order-detail`).
///
/// Accepts any input casing: `order detail`, `OrderDetail`, `order_detail`,
/// `order-detail` all produce the same [Name].
final class Name {
  Name(String raw) : words = _split(raw) {
    if (words.isEmpty) {
      throw FormatException('Empty name', raw);
    }
    if (RegExp(r'^[0-9]').hasMatch(words.first)) {
      throw FormatException('A name cannot start with a digit', raw);
    }
  }

  Name._(this.words);

  final List<String> words;

  String get snake => words.join('_');
  String get kebab => words.join('-');
  String get pascal => words.map(_capitalize).join();
  String get camel => words.first + words.skip(1).map(_capitalize).join();
  String get title => words.map(_capitalize).join(' ');

  /// Drops trailing [suffix] words (`OrdersScreen` minus `Screen` is
  /// `Orders`), so users may type the class name or the short name.
  Name withoutSuffix(String suffix) {
    final tail = _split(suffix);
    if (tail.isEmpty || words.length <= tail.length) return this;
    final start = words.length - tail.length;
    for (var i = 0; i < tail.length; i++) {
      if (words[start + i] != tail[i]) return this;
    }
    return Name._(words.sublist(0, start));
  }

  /// Naive English singular of the last word (`orders` → `order`,
  /// `categories` → `category`). Good enough for a default the user confirms.
  Name get singular {
    final last = words.last;
    final String single;
    if (last.endsWith('ies') && last.length > 3) {
      single = '${last.substring(0, last.length - 3)}y';
    } else if (last.endsWith('sses') || last.endsWith('xes')) {
      single = last.substring(0, last.length - 2);
    } else if (last.endsWith('s') &&
        !last.endsWith('ss') &&
        !last.endsWith('us') &&
        last.length > 1) {
      single = last.substring(0, last.length - 1);
    } else {
      single = last;
    }
    return Name._([...words.take(words.length - 1), single]);
  }

  @override
  bool operator ==(Object other) => other is Name && other.snake == snake;

  @override
  int get hashCode => snake.hashCode;

  @override
  String toString() => snake;

  static String _capitalize(String word) =>
      word.isEmpty ? word : word[0].toUpperCase() + word.substring(1);

  static List<String> _split(String raw) {
    final spaced = raw
        .trim()
        .replaceAllMapped(
          RegExp(r'([A-Z]+)([A-Z][a-z])'),
          (m) => '${m[1]} ${m[2]}',
        )
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (m) => '${m[1]} ${m[2]}',
        );
    return spaced
        .split(RegExp(r'[^A-Za-z0-9]+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w.toLowerCase())
        .toList();
  }
}

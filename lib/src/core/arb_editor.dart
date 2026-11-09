import 'dart:convert';

/// A gen-l10n placeholder found in a message (`{name}`, `{count, plural, …}`).
final class ArbPlaceholder {
  const ArbPlaceholder(this.name, this.type);

  final String name;

  /// `String`, or `num` for plural arguments.
  final String type;
}

/// Edits ARB (JSON) files at the text level, so existing formatting and key
/// order are untouched and the diff is only the added lines.
abstract final class ArbEditor {
  /// Decoded content, or `null` when [source] is not a JSON object.
  static Map<String, dynamic>? decode(String source) {
    try {
      final value = jsonDecode(source);
      return value is Map<String, dynamic> ? value : null;
    } on FormatException {
      return null;
    }
  }

  /// `@@locale`, else the suffix of `app_fr.arb` / `intl_pt_BR.arb`.
  static String? locale(String path, String source) {
    final declared = decode(source)?['@@locale'];
    if (declared is String) return declared;
    final match =
        RegExp(r'_([a-z]{2,3}(?:_[A-Za-z]{2,4})*)\.arb$').firstMatch(path);
    return match?[1];
  }

  /// Top-level ICU arguments of [message]. Braces nested inside plural or
  /// select branches (`=0{none}`) are message text, not placeholders.
  static List<ArbPlaceholder> placeholders(String message) {
    final found = <String, ArbPlaceholder>{};
    var depth = 0;
    for (var i = 0; i < message.length; i++) {
      final c = message[i];
      if (c == '{') {
        if (depth == 0) {
          final match = RegExp(r'\{\s*([A-Za-z_]\w*)\s*(?:,\s*(\w+))?')
              .matchAsPrefix(message, i);
          if (match != null) {
            final name = match[1]!;
            found.putIfAbsent(
              name,
              () =>
                  ArbPlaceholder(name, match[2] == 'plural' ? 'num' : 'String'),
            );
          }
        }
        depth++;
      } else if (c == '}' && depth > 0) {
        depth--;
      }
    }
    return found.values.toList();
  }

  /// Adds `"key": "message"` (and its `@key` metadata when given) at the end
  /// of the ARB object. Returns `null` when [source] is not a JSON object.
  static String? addEntry(
    String source,
    String key,
    String message, {
    Map<String, Object?>? metadata,
  }) {
    if (decode(source) == null) return null;
    final close = source.lastIndexOf('}');
    final indent =
        RegExp(r'^([ \t]+)"', multiLine: true).firstMatch(source)?[1] ?? '  ';
    final encoder = JsonEncoder.withIndent(indent);
    String nested(Object? value) =>
        encoder.convert(value).replaceAll('\n', '\n$indent');

    final entries = [
      '$indent${jsonEncode(key)}: ${jsonEncode(message)}',
      if (metadata != null && metadata.isNotEmpty)
        '$indent${jsonEncode('@$key')}: ${nested(metadata)}',
    ].join(',\n');

    final head = source.substring(0, close).trimRight();
    final separator = head.endsWith('{') ? '\n' : ',\n';
    return '$head$separator$entries\n${source.substring(close)}';
  }

  /// Sets [key] (and replaces its metadata) by re-encoding the whole file.
  /// Used with `--force` on an existing key; key order is preserved.
  static String? replaceEntry(
    String source,
    String key,
    String message, {
    Map<String, Object?>? metadata,
  }) {
    final map = decode(source);
    if (map == null) return null;
    map[key] = message;
    if (metadata != null && metadata.isNotEmpty) map['@$key'] = metadata;
    final indent =
        RegExp(r'^([ \t]+)"', multiLine: true).firstMatch(source)?[1] ?? '  ';
    return '${JsonEncoder.withIndent(indent).convert(map)}\n';
  }
}

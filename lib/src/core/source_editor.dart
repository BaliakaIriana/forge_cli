/// Text-level edits of Dart sources: imports, anchors, class bodies.
///
/// Deliberately not an AST rewriter: edits are line-based and anchored on
/// `// forge:<name>` comments, so diffs stay small and predictable.
abstract final class SourceEditor {
  static String anchorComment(String anchor) => '// forge:$anchor';

  static bool hasAnchor(String source, String anchor) =>
      source.contains(anchorComment(anchor));

  /// Adds `import '<uri>';` after the last import (or before the first
  /// `part`/declaration). No-op if already imported.
  static String addImport(String source, String uri) {
    final directive = "import '$uri';";
    if (RegExp("import\\s+'${RegExp.escape(uri)}'").hasMatch(source)) {
      return source;
    }
    final lines = source.split('\n');
    final lastImport =
        lines.lastIndexWhere((l) => l.trimLeft().startsWith('import '));
    if (lastImport >= 0) {
      // Multi-line import (`show`/`as` on the next lines) ends with `;`.
      var end = lastImport;
      while (end < lines.length - 1 && !lines[end].trimRight().endsWith(';')) {
        end++;
      }
      lines.insert(end + 1, directive);
      return lines.join('\n');
    }
    final firstCode = lines.indexWhere((l) {
      final t = l.trim();
      return t.isNotEmpty && !t.startsWith('//') && !t.startsWith('library');
    });
    final at = firstCode < 0 ? lines.length : firstCode;
    lines.insertAll(at, [directive, '']);
    return lines.join('\n');
  }

  static String addImports(String source, Iterable<String> uris) =>
      uris.fold(source, addImport);

  /// Inserts [snippet] above the anchor line, using the anchor indentation.
  /// Returns `null` when the anchor is missing; unchanged source when the
  /// snippet is already present.
  static String? insertAtAnchor(String source, String anchor, String snippet) {
    final lines = source.split('\n');
    final comment = anchorComment(anchor);
    final index = lines.indexWhere((l) => l.trim() == comment);
    if (index < 0) return null;
    if (_containsSnippet(source, snippet)) return source;
    final indent = RegExp(r'^\s*').firstMatch(lines[index])![0]!;
    final block =
        snippet.trimRight().split('\n').map((l) => l.isEmpty ? l : '$indent$l');
    lines.insertAll(index, block);
    return lines.join('\n');
  }

  /// Inserts [snippet] before the closing brace of class [className].
  /// Returns `null` if the class cannot be found.
  static String? insertInClass(
    String source,
    String className,
    String snippet,
  ) {
    final match = RegExp('class\\s+$className\\b[^{]*\\{').firstMatch(source);
    if (match == null) return null;
    if (_containsSnippet(source, snippet)) return source;
    final close = findClosing(source, match.end - 1);
    if (close == null) return null;
    final block = snippet
        .trimRight()
        .split('\n')
        .map((l) => l.isEmpty ? l : '  $l')
        .join('\n');
    final before = source.substring(0, close).trimRight();
    return '$before\n\n$block\n${source.substring(close)}';
  }

  /// Inserts anchor comments right before the end of the block opened at
  /// [openIndex] (a `{` or `[`), indented one level deeper than the closer.
  static String insertAnchorsBeforeClose(
    String source,
    int openIndex,
    List<String> anchors, {
    String indentUnit = '  ',
  }) {
    final close = findClosing(source, openIndex);
    if (close == null) return source;
    final lineStart = source.lastIndexOf('\n', close - 1) + 1;
    final closerIndent =
        RegExp(r'^[ \t]*').firstMatch(source.substring(lineStart))![0]!;
    final closerAlone = source.substring(lineStart, close).trim().isEmpty;
    final indent = '$closerIndent$indentUnit';
    final block = anchors.map((a) => '$indent${anchorComment(a)}').join('\n');
    if (closerAlone) {
      return '${source.substring(0, lineStart)}$block\n'
          '${source.substring(lineStart)}';
    }
    return '${source.substring(0, close)}\n$block\n$closerIndent'
        '${source.substring(close)}';
  }

  /// Index of the bracket closing the one at [openIndex], skipping strings
  /// and comments. Supports `{}`, `[]` and `()`.
  static int? findClosing(String source, int openIndex) {
    const pairs = {'{': '}', '[': ']', '(': ')'};
    final open = source[openIndex];
    final close = pairs[open];
    if (close == null) return null;
    var depth = 0;
    var i = openIndex;
    while (i < source.length) {
      final c = source[i];
      if (source.startsWith('//', i)) {
        final end = source.indexOf('\n', i);
        if (end < 0) return null;
        i = end + 1;
        continue;
      }
      if (source.startsWith('/*', i)) {
        final end = source.indexOf('*/', i + 2);
        if (end < 0) return null;
        i = end + 2;
        continue;
      }
      if (c == "'" || c == '"') {
        i = _skipString(source, i);
        continue;
      }
      if (c == open) depth++;
      if (c == close) {
        depth--;
        if (depth == 0) return i;
      }
      i++;
    }
    return null;
  }

  static int _skipString(String source, int start) {
    final quote = source[start];
    final triple = source.startsWith(quote * 3, start);
    final raw = start > 0 && source[start - 1] == 'r';
    final delimiter = triple ? quote * 3 : quote;
    var i = start + delimiter.length;
    while (i < source.length) {
      if (!raw && source[i] == r'\') {
        i += 2;
        continue;
      }
      if (source.startsWith(delimiter, i)) return i + delimiter.length;
      if (!triple && source[i] == '\n') return i;
      i++;
    }
    return source.length;
  }

  static bool _containsSnippet(String source, String snippet) {
    String squash(String s) => s.replaceAll(RegExp(r'\s+'), '');
    return squash(source).contains(squash(snippet));
  }
}

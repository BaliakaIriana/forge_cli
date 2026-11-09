import '../config/forge_config.dart';
import '../config/stack.dart';
import '../core/project.dart';

/// What every template needs: the stack and how to import project files.
final class TemplateContext {
  const TemplateContext(this.project, this.config);

  final Project project;
  final ForgeConfig config;

  StackConfig get stack => config.stack;

  bool get injectable => stack.di == DependencyInjection.injectable;
  bool get freezed => stack.dataClass == DataClass.freezed;

  /// Dart 3.12+ `{required this._field}` (private named parameters).
  bool get privateNamedParameters {
    final (major, minor) = project.minSdk;
    return major > 3 || (major == 3 && minor >= 12);
  }

  /// injectable import limited to [names]: the package also exports
  /// classes such as `Order` that would clash with domain entities.
  static String injectableImport(List<String> names) =>
      'package:injectable/injectable.dart show ${names.join(', ')}';

  String uri(String projectPath) => project.importUri(projectPath);

  /// Sorted, de-duplicated import block (dart:, package:, then relative),
  /// followed by a blank line. Entries may carry `show`/`hide` combinators.
  /// Empty when there is nothing to import.
  String imports(Iterable<String> uris) {
    final unique = uris.toSet().toList()
      ..sort((a, b) {
        int rank(String u) => u.startsWith('dart:')
            ? 0
            : u.startsWith('package:')
                ? 1
                : 2;
        final byRank = rank(a).compareTo(rank(b));
        return byRank != 0 ? byRank : a.compareTo(b);
      });
    if (unique.isEmpty) return '';
    String directive(String entry) {
      // `uri show X` / `uri hide X` combinators follow the quoted URI.
      final space = entry.indexOf(' ');
      return space < 0
          ? "import '$entry';"
          : "import '${entry.substring(0, space)}'${entry.substring(space)};";
    }

    return '${unique.map(directive).join('\n')}\n\n';
  }

  /// injectable annotation line (with trailing newline), or empty.
  String annotation(String value) => injectable ? '$value\n' : '';
}

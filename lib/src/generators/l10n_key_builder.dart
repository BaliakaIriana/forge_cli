import 'package:yaml/yaml.dart';

import '../core/arb_editor.dart';
import '../core/file_store.dart';
import '../core/generation_plan.dart';

/// gen-l10n settings from `l10n.yaml` (Flutter defaults when absent).
final class L10nSettings {
  const L10nSettings({
    required this.arbDir,
    required this.templateFile,
    required this.outputClass,
  });

  factory L10nSettings.read(FileStore store) {
    final yaml = loadYaml(store.read('l10n.yaml') ?? '');
    String value(String key, String fallback) =>
        yaml is YamlMap ? yaml[key]?.toString() ?? fallback : fallback;
    return L10nSettings(
      arbDir: value('arb-dir', 'lib/l10n').replaceAll(RegExp(r'/$'), ''),
      templateFile: value('template-arb-file', 'app_en.arb'),
      outputClass: value('output-class', 'AppLocalizations'),
    );
  }

  final String arbDir;
  final String templateFile;
  final String outputClass;

  String get templatePath => '$arbDir/$templateFile';
}

/// One ARB file of the project.
final class ArbFile {
  const ArbFile(this.path, this.locale, {required this.isTemplate});

  final String path;
  final String locale;
  final bool isTemplate;
}

/// Adds a translation key to every ARB file (`forge g l10n-key`).
final class L10nKeyBuilder {
  L10nKeyBuilder(this._store) : settings = L10nSettings.read(_store);

  final FileStore _store;
  final L10nSettings settings;

  /// ARB files, template first. Empty when the project has no ARB.
  List<ArbFile> arbFiles() {
    final files = [
      for (final path in _store.listFiles(settings.arbDir, '.arb'))
        ArbFile(
          path,
          ArbEditor.locale(path, _store.read(path) ?? '') ?? path,
          isTemplate: path == settings.templatePath,
        ),
    ];
    return files..sort((a, b) => a.isTemplate ? -1 : (b.isTemplate ? 1 : 0));
  }

  /// [messages] maps a locale to its text; the template locale is required,
  /// other locales fall back to it (reported as untranslated).
  void add(
    GenerationPlan plan, {
    required String key,
    required Map<String, String> messages,
    String? description,
    bool force = false,
  }) {
    final files = arbFiles();
    final template = files.where((f) => f.isTemplate).firstOrNull;
    if (template == null) {
      plan.note('No template ARB file at ${settings.templatePath} '
          '(see l10n.yaml); nothing generated.');
      return;
    }
    final templateMessage = messages[template.locale]!;
    final placeholders = ArbEditor.placeholders(templateMessage);
    final expected = placeholders.map((p) => p.name).toSet();
    final metadata = <String, Object?>{
      if (description != null && description.isNotEmpty)
        'description': description,
      if (placeholders.isNotEmpty)
        'placeholders': {
          for (final p in placeholders) p.name: {'type': p.type},
        },
    };

    for (final file in files) {
      final source = plan.read(file.path)!;
      final exists = ArbEditor.decode(source)?.containsKey(key) ?? false;
      if (exists && !force) {
        plan.note('$key already exists in ${file.path} (use --force to '
            'replace it).');
        continue;
      }
      final message = messages[file.locale];
      if (message == null) {
        plan.note('$key: no ${file.locale} text, template text copied into '
            '${file.path}. Translate it.');
      } else if (!file.isTemplate) {
        final names =
            ArbEditor.placeholders(message).map((p) => p.name).toSet();
        if (!names.containsAll(expected) || !expected.containsAll(names)) {
          plan.note('$key: ${file.locale} placeholders $names differ from '
              'the template $expected.');
        }
      }
      final text = message ?? templateMessage;
      final meta = file.isTemplate ? metadata : null;
      plan.edit(
        file.path,
        reason: exists ? 'replace $key' : 'add $key',
        snippet: '"$key": "$text"',
        transform: (s) => exists
            ? ArbEditor.replaceEntry(s, key, text, metadata: meta)
            : ArbEditor.addEntry(s, key, text, metadata: meta),
      );
    }
  }
}

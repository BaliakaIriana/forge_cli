import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../config/forge_config.dart';
import 'file_store.dart';

/// The Flutter project forge runs in.
final class Project {
  Project({required this.store, required this.packageName, this.config});

  final FileStore store;
  final String packageName;

  /// `null` until `forge init` has run.
  final ForgeConfig? config;

  Project withConfig(ForgeConfig config) =>
      Project(store: store, packageName: packageName, config: config);

  /// `package:` URI of a project-relative file under `lib/`.
  String importUri(String path) {
    if (!path.startsWith('lib/')) {
      throw ArgumentError('Not under lib/: $path');
    }
    return 'package:$packageName/${path.substring(4)}';
  }

  /// Dependencies declared in pubspec.yaml (both sections).
  Set<String> get declaredPackages {
    final yaml = loadYaml(store.read('pubspec.yaml') ?? '');
    if (yaml is! YamlMap) return const {};
    return {
      for (final section in ['dependencies', 'dev_dependencies'])
        if (yaml[section] case final YamlMap deps)
          ...deps.keys.map((k) => k.toString()),
    };
  }

  /// Lower bound of `environment.sdk` in pubspec.yaml, as (major, minor).
  (int, int) get minSdk {
    final yaml = loadYaml(store.read('pubspec.yaml') ?? '');
    final sdk = yaml is YamlMap && yaml['environment'] is YamlMap
        ? (yaml['environment'] as YamlMap)['sdk']?.toString()
        : null;
    final match = RegExp(r'(\d+)\.(\d+)').firstMatch(sdk ?? '');
    if (match == null) return (3, 0);
    return (int.parse(match[1]!), int.parse(match[2]!));
  }

  /// Walks up from [start] to the nearest directory with a pubspec.yaml.
  static Project? locate(Directory start) {
    Directory? dir = start.absolute;
    while (dir != null) {
      final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
      if (pubspec.existsSync()) {
        final yaml = loadYaml(pubspec.readAsStringSync());
        final name = yaml is YamlMap ? yaml['name']?.toString() : null;
        if (name == null) return null;
        final store = DiskFileStore(dir.path);
        final configSource = store.read(ForgeConfig.fileName);
        return Project(
          store: store,
          packageName: name,
          config: configSource == null ? null : ForgeConfig.parse(configSource),
        );
      }
      final parent = dir.parent;
      dir = parent.path == dir.path ? null : parent;
    }
    return null;
  }
}

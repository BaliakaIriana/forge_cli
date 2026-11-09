import '../core/project.dart';
import 'forge_config.dart';
import 'layout.dart';
import 'stack.dart';

/// Best guess of a project's setup, used as defaults by `forge init`.
final class Detection {
  const Detection({
    required this.stack,
    required this.preset,
    required this.layout,
    required this.core,
    required this.screenSuffix,
    required this.foundCore,
  });

  final StackConfig stack;
  final LayoutPreset preset;
  final LayoutConfig layout;
  final CorePaths core;
  final String screenSuffix;

  /// Core paths actually found in the sources (others are defaults).
  final Set<String> foundCore;
}

/// Reads pubspec.yaml and `lib/` to pre-fill `forge init` answers.
final class ProjectDetector {
  const ProjectDetector(this.project);

  final Project project;

  Detection detect() {
    final packages = project.declaredPackages;
    final sources = _sources();
    final stack = _stack(packages, sources);
    final preset = _preset();
    final layout = _layoutTweaks(preset, sources.keys);
    final (core, found) = _core(sources, preset);
    return Detection(
      stack: stack,
      preset: preset,
      layout: layout,
      core: core,
      screenSuffix: _screenSuffix(sources.keys, preset),
      foundCore: found,
    );
  }

  Map<String, String> _sources() => {
        for (final path in project.store.dartFiles('lib'))
          if (!RegExp(r'\.(g|freezed|gr|config)\.dart$').hasMatch(path))
            path: project.store.read(path) ?? '',
      };

  StackConfig _stack(Set<String> packages, Map<String, String> sources) {
    final riverpod = packages.any((p) => p.contains('riverpod'));
    return StackConfig(
      state: riverpod && !packages.contains('flutter_bloc')
          ? StateManagement.riverpod
          : StateManagement.bloc,
      di: riverpod && !packages.contains('flutter_bloc')
          ? DependencyInjection.riverpod
          : packages.contains('injectable')
              ? DependencyInjection.injectable
              : DependencyInjection.getIt,
      router: packages.contains('auto_route')
          ? Routing.autoRoute
          : Routing.goRouter,
      network: packages.contains('retrofit')
          ? Network.retrofit
          : packages.contains('dio')
              ? Network.dio
              : Network.none,
      dataClass: packages.contains('freezed_annotation')
          ? DataClass.freezed
          : DataClass.equatable,
      functional: packages.contains('dartz') && !packages.contains('fpdart')
          ? FunctionalLib.dartz
          : FunctionalLib.fpdart,
      jsonFieldCase: _jsonCase(sources.values),
    );
  }

  /// Majority vote over `@JsonKey(name: '...')` and `fieldRename:` usages.
  JsonFieldCase _jsonCase(Iterable<String> sources) {
    final votes = <JsonFieldCase, int>{};
    void vote(JsonFieldCase c) => votes[c] = (votes[c] ?? 0) + 1;
    for (final source in sources) {
      for (final m
          in RegExp(r'fieldRename:\s*FieldRename\.(\w+)').allMatches(source)) {
        final match = JsonFieldCase.values
            .where((c) => c.fieldRename == 'FieldRename.${m[1]}');
        if (match.isNotEmpty) vote(match.first);
      }
      for (final m
          in RegExp(r"@JsonKey\(\s*name:\s*'([^']+)'").allMatches(source)) {
        final key = m[1]!;
        if (key.contains('_')) {
          vote(key == key.toUpperCase()
              ? JsonFieldCase.screamingSnake
              : JsonFieldCase.snake);
        } else if (key.contains('-')) {
          vote(JsonFieldCase.kebab);
        } else if (RegExp('^[A-Z]').hasMatch(key)) {
          vote(JsonFieldCase.pascal);
        }
      }
    }
    if (votes.isEmpty) return JsonFieldCase.none;
    return (votes.entries.toList()..sort((a, b) => b.value - a.value))
        .first
        .key;
  }

  LayoutPreset _preset() {
    final store = project.store;
    if (store.subdirectories('lib/src/features').isNotEmpty) {
      return LayoutPreset.featureFirst;
    }
    final src = store.subdirectories('lib/src');
    if (src.contains('domain') && src.contains('presentation')) {
      return LayoutPreset.layerFirst;
    }
    final flat =
        src.any((d) => store.subdirectories('lib/src/$d').contains('domain'));
    return flat ? LayoutPreset.featureFirstFlat : LayoutPreset.featureFirst;
  }

  /// Adjusts folder names to what the project already uses.
  LayoutConfig _layoutTweaks(LayoutPreset preset, Iterable<String> files) {
    var layout = preset.layout;
    if (preset == LayoutPreset.layerFirst) return layout;
    int count(String segment) => files.where((f) => f.contains(segment)).length;
    String swap(Layer layer, String from, String to) =>
        layout.paths[layer]!.replaceAll(from, to);

    final overrides = <Layer, String>{};
    if (count('/presentation/blocs/') > count('/presentation/providers/')) {
      overrides[Layer.state] = swap(Layer.state, 'providers', 'blocs');
    }
    if (count('/data/datasources/') > count('/data/data_sources/')) {
      overrides[Layer.dataSource] =
          swap(Layer.dataSource, 'data_sources', 'datasources');
    } else if (count('/data/data_sources/') > count('/data/datasources/')) {
      overrides[Layer.dataSource] =
          swap(Layer.dataSource, 'datasources', 'data_sources');
    }
    if (count('/presentation/pages/') > count('/presentation/screens/')) {
      overrides[Layer.screen] = swap(Layer.screen, 'screens', 'pages');
    } else if (count('/presentation/screens/') >
        count('/presentation/pages/')) {
      overrides[Layer.screen] = swap(Layer.screen, 'pages', 'screens');
    }
    if (count('/domain/use_cases/') > count('/domain/usecases/')) {
      overrides[Layer.useCase] = swap(Layer.useCase, 'usecases', 'use_cases');
    }
    return layout = layout.merge(overrides);
  }

  String _screenSuffix(Iterable<String> files, LayoutPreset preset) {
    final screens = files.where((f) => f.endsWith('_screen.dart')).length;
    final pages = files.where((f) => f.endsWith('_page.dart')).length;
    if (screens == pages) return preset.screenSuffix;
    return screens > pages ? 'Screen' : 'Page';
  }

  (CorePaths, Set<String>) _core(
      Map<String, String> sources, LayoutPreset preset) {
    String? find(RegExp pattern) {
      for (final entry in sources.entries) {
        if (pattern.hasMatch(entry.value)) return entry.key;
      }
      return null;
    }

    final base = preset == LayoutPreset.featureFirstFlat
        ? const CorePaths(
            typedefs: 'lib/core/utils/typedefs.dart',
            taskRunner: 'lib/core/utils/task_runner.dart',
            failure: 'lib/core/utils/failure.dart',
            di: 'lib/core/di/injection.dart',
            router: 'lib/core/navigation/app_router.dart',
            routes: 'lib/core/navigation/app_routes.dart',
            dioProvider: 'lib/core/network/dio_provider.dart',
          )
        : CorePaths.defaults;

    final found = <String, String?>{
      'typedefs': find(RegExp(r'typedef\s+FutureEither\s*<')),
      'task_runner': find(RegExp(r'FutureEither<\w+>\s+runTask<')),
      'failure': find(RegExp(r'class\s+Failure\b')),
      'di': find(
          RegExp(r'configureDependencies\s*\([^)]*\)\s*(async\s*)?(\{|=>)')),
      'router': find(RegExp(r'GoRouter\(|extends\s+RootStackRouter')),
      'routes': find(RegExp(r'class\s+AppRoutes\b')),
      'dio_provider': find(RegExp(r'Dio\s+dio\s*\(\s*Ref\b')),
    };
    final core = CorePaths(
      typedefs: found['typedefs'] ?? base.typedefs,
      taskRunner: found['task_runner'] ?? base.taskRunner,
      failure: found['failure'] ?? base.failure,
      di: found['di'] ?? base.di,
      router: found['router'] ?? base.router,
      routes: found['routes'] ?? base.routes,
      dioProvider: found['dio_provider'] ?? base.dioProvider,
    );
    return (
      core,
      {
        for (final e in found.entries)
          if (e.value != null) e.key
      },
    );
  }
}

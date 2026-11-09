import 'package:yaml/yaml.dart';

import 'layout.dart';
import 'stack.dart';

/// Project files generated code imports or wires into.
final class CorePaths {
  const CorePaths({
    required this.typedefs,
    required this.taskRunner,
    required this.failure,
    required this.di,
    required this.router,
    this.routes,
    this.dioProvider,
  });

  /// Declares `FutureEither<T>`.
  final String typedefs;

  /// Declares `runTask(...)`, turning exceptions into `Left(Failure)`.
  final String taskRunner;

  /// Declares the `Failure` hierarchy.
  final String failure;

  /// Declares `getIt` (get_it / injectable). Unused with Riverpod DI.
  final String di;

  /// The router configuration (`GoRouter` or `RootStackRouter`).
  final String router;

  /// Optional route-path constants class (`AppRoutes`), go_router only.
  final String? routes;

  /// Declares `dioProvider` (Riverpod DI only).
  final String? dioProvider;

  static const defaults = CorePaths(
    typedefs: 'lib/src/utils/typedefs.dart',
    taskRunner: 'lib/src/utils/task_runner.dart',
    failure: 'lib/src/utils/failure.dart',
    di: 'lib/src/di/injection.dart',
    router: 'lib/src/routing/app_router.dart',
    routes: 'lib/src/routing/app_routes.dart',
    dioProvider: 'lib/src/di/dio_provider.dart',
  );

  CorePaths copyWith({
    String? typedefs,
    String? taskRunner,
    String? failure,
    String? di,
    String? router,
    String? routes,
    String? dioProvider,
  }) =>
      CorePaths(
        typedefs: typedefs ?? this.typedefs,
        taskRunner: taskRunner ?? this.taskRunner,
        failure: failure ?? this.failure,
        di: di ?? this.di,
        router: router ?? this.router,
        routes: routes ?? this.routes,
        dioProvider: dioProvider ?? this.dioProvider,
      );
}

/// Class-name suffixes.
final class NamingConfig {
  const NamingConfig({
    this.screenSuffix = 'Screen',
    this.useCaseSuffix = 'UseCase',
    this.dataSourceSuffix = 'RemoteDataSource',
  });

  final String screenSuffix;
  final String useCaseSuffix;
  final String dataSourceSuffix;
}

/// Content of `forge.yaml`.
final class ForgeConfig {
  const ForgeConfig({
    required this.stack,
    required this.layout,
    required this.core,
    this.naming = const NamingConfig(),
  });

  static const fileName = 'forge.yaml';
  static const schemaVersion = 1;

  final StackConfig stack;
  final LayoutConfig layout;
  final CorePaths core;
  final NamingConfig naming;

  factory ForgeConfig.parse(String source) {
    final root = loadYaml(source);
    if (root is! YamlMap) {
      throw const FormatException('forge.yaml must be a map');
    }
    final stack = _map(root, 'stack');
    final layout = _map(root, 'layout');
    final core = _map(root, 'core');
    final naming = _map(root, 'naming');
    const defaultStack = StackConfig();
    final defaultLayout = LayoutPreset.featureFirst.layout;

    return ForgeConfig(
      stack: StackConfig(
        state: parseOption(
            StateManagement.values, stack['state'], defaultStack.state),
        di: parseOption(
            DependencyInjection.values, stack['di'], defaultStack.di),
        router:
            parseOption(Routing.values, stack['router'], defaultStack.router),
        network:
            parseOption(Network.values, stack['network'], defaultStack.network),
        dataClass: parseOption(
            DataClass.values, stack['data_class'], defaultStack.dataClass),
        functional: parseOption(
            FunctionalLib.values, stack['functional'], defaultStack.functional),
        jsonFieldCase: parseOption(JsonFieldCase.values,
            stack['json_field_case'], defaultStack.jsonFieldCase),
      ),
      layout: LayoutConfig({
        for (final layer in Layer.values)
          layer: layout[layer.key]?.toString() ?? defaultLayout.paths[layer]!,
      }),
      core: CorePaths(
        typedefs: _string(core, 'typedefs', CorePaths.defaults.typedefs),
        taskRunner: _string(core, 'task_runner', CorePaths.defaults.taskRunner),
        failure: _string(core, 'failure', CorePaths.defaults.failure),
        di: _string(core, 'di', CorePaths.defaults.di),
        router: _string(core, 'router', CorePaths.defaults.router),
        routes: core['routes']?.toString(),
        dioProvider: core['dio_provider']?.toString(),
      ),
      naming: NamingConfig(
        screenSuffix: _string(naming, 'screen_suffix', 'Screen'),
        useCaseSuffix: _string(naming, 'usecase_suffix', 'UseCase'),
        dataSourceSuffix:
            _string(naming, 'data_source_suffix', 'RemoteDataSource'),
      ),
    );
  }

  /// Serialises to YAML, with comments documenting each key.
  String toYaml() {
    String opt<T extends StackOption>(String key, T value, List<T> all) =>
        '  $key: ${value.id} # ${all.map((v) => v.id).join(' | ')}';
    String? nullable(String? value) => value == null ? null : "'$value'";

    final buffer = StringBuffer()
      ..writeln(
          '# forge_cli configuration — https://github.com/baliaka-andria/forge_cli')
      ..writeln(
          '# Generated by `forge init`; edit freely, then run `forge g ...`.')
      ..writeln('version: $schemaVersion')
      ..writeln()
      ..writeln('stack:')
      ..writeln(opt('state', stack.state, StateManagement.values))
      ..writeln(opt('di', stack.di, DependencyInjection.values))
      ..writeln(opt('router', stack.router, Routing.values))
      ..writeln(opt('network', stack.network, Network.values))
      ..writeln(opt('data_class', stack.dataClass, DataClass.values))
      ..writeln(opt('functional', stack.functional, FunctionalLib.values))
      ..writeln(
          opt('json_field_case', stack.jsonFieldCase, JsonFieldCase.values))
      ..writeln()
      ..writeln('# Where generated files go. `{feature}` is the snake_case')
      ..writeln('# feature name; paths are relative to the project root.')
      ..writeln('layout:');
    for (final layer in Layer.values) {
      buffer.writeln("  ${layer.key}: '${layout.paths[layer]}'");
    }
    buffer
      ..writeln()
      ..writeln('# Existing project files the generated code imports or is')
      ..writeln('# wired into (anchors `// forge:...` mark insertion points).')
      ..writeln('core:')
      ..writeln("  typedefs: '${core.typedefs}' # FutureEither<T>")
      ..writeln("  task_runner: '${core.taskRunner}' # runTask()")
      ..writeln("  failure: '${core.failure}' # Failure")
      ..writeln("  di: '${core.di}' # getIt")
      ..writeln("  router: '${core.router}'")
      ..writeln(
          '  routes: ${nullable(core.routes)} # AppRoutes, go_router only')
      ..writeln(
          '  dio_provider: ${nullable(core.dioProvider)} # Riverpod DI only')
      ..writeln()
      ..writeln('naming:')
      ..writeln('  screen_suffix: ${naming.screenSuffix}')
      ..writeln('  usecase_suffix: ${naming.useCaseSuffix}')
      ..writeln('  data_source_suffix: ${naming.dataSourceSuffix}');
    return buffer.toString();
  }

  static YamlMap _map(YamlMap root, String key) {
    final value = root[key];
    return value is YamlMap ? value : YamlMap();
  }

  static String _string(YamlMap map, String key, String fallback) =>
      map[key]?.toString() ?? fallback;
}

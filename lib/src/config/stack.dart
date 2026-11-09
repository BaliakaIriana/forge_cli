/// A stack choice persisted in `forge.yaml` under its [id].
abstract interface class StackOption {
  String get id;
  String get label;
}

/// Parses [raw] into one of [values] by id, or returns [fallback].
T parseOption<T extends StackOption>(List<T> values, Object? raw, T fallback) {
  if (raw == null) return fallback;
  for (final value in values) {
    if (value.id == raw.toString()) return value;
  }
  throw FormatException(
    'Unknown value "$raw". Expected one of: '
    '${values.map((v) => v.id).join(', ')}',
  );
}

enum StateManagement implements StackOption {
  bloc('bloc', 'flutter_bloc (Bloc, 3 files: bloc/event/state)'),
  riverpod('riverpod', 'Riverpod with code generation (@riverpod)');

  const StateManagement(this.id, this.label);
  @override
  final String id;
  @override
  final String label;
}

enum DependencyInjection implements StackOption {
  getIt('get_it', 'get_it, registrations written in the DI file'),
  injectable('injectable', 'injectable (get_it + annotations)'),
  riverpod('riverpod', 'Riverpod providers');

  const DependencyInjection(this.id, this.label);
  @override
  final String id;
  @override
  final String label;
}

enum Routing implements StackOption {
  goRouter('go_router', 'go_router'),
  autoRoute('auto_route', 'auto_route');

  const Routing(this.id, this.label);
  @override
  final String id;
  @override
  final String label;
}

enum Network implements StackOption {
  retrofit('retrofit', 'Dio + Retrofit (@RestApi clients)'),
  dio('dio', 'Dio, hand-written data sources'),
  none(
    'none',
    'No client: data source interface + implementation, inject your own '
        'dependencies (Supabase, Firebase, local DB...)',
  );

  const Network(this.id, this.label);
  @override
  final String id;
  @override
  final String label;

  bool get usesDio => this != none;

  /// Data sources split into an interface and an `Impl` class (a Retrofit
  /// client is its own implementation).
  bool get handWritten => this != retrofit;
}

enum DataClass implements StackOption {
  equatable('equatable', 'equatable + json_serializable'),
  freezed('freezed', 'freezed (+ json_serializable)');

  const DataClass(this.id, this.label);
  @override
  final String id;
  @override
  final String label;
}

enum FunctionalLib implements StackOption {
  fpdart('fpdart', 'fpdart (Either<Failure, T>)'),
  dartz('dartz', 'dartz (Either<Failure, T>)');

  const FunctionalLib(this.id, this.label);
  @override
  final String id;
  @override
  final String label;

  String get import => 'package:$id/$id.dart';
}

/// JSON key casing applied to models through `fieldRename`.
enum JsonFieldCase implements StackOption {
  none('none', 'Same as the Dart field (camelCase)', null),
  snake('snake', 'snake_case', 'FieldRename.snake'),
  pascal('pascal', 'PascalCase', 'FieldRename.pascal'),
  kebab('kebab', 'kebab-case', 'FieldRename.kebab'),
  screamingSnake(
      'screaming_snake', 'SCREAMING_SNAKE_CASE', 'FieldRename.screamingSnake');

  const JsonFieldCase(this.id, this.label, this.fieldRename);
  @override
  final String id;
  @override
  final String label;
  final String? fieldRename;
}

/// The libraries chosen for the project.
final class StackConfig {
  const StackConfig({
    this.state = StateManagement.bloc,
    this.di = DependencyInjection.getIt,
    this.router = Routing.goRouter,
    this.network = Network.retrofit,
    this.dataClass = DataClass.equatable,
    this.functional = FunctionalLib.fpdart,
    this.jsonFieldCase = JsonFieldCase.none,
  });

  final StateManagement state;
  final DependencyInjection di;
  final Routing router;
  final Network network;
  final DataClass dataClass;
  final FunctionalLib functional;
  final JsonFieldCase jsonFieldCase;

  bool get isRiverpod => state == StateManagement.riverpod;

  /// Riverpod state implies Riverpod DI: the generated notifiers read their
  /// use cases from providers, not from get_it.
  List<String> validate() => [
        if (state == StateManagement.riverpod &&
            di != DependencyInjection.riverpod)
          'state: riverpod requires di: riverpod',
        if (state == StateManagement.bloc && di == DependencyInjection.riverpod)
          'di: riverpod requires state: riverpod',
      ];

  /// Packages the generated code imports, split by pubspec section.
  ({List<String> dependencies, List<String> devDependencies}) get packages {
    final deps = <String>{
      if (network.usesDio) 'dio',
      functional.id,
      'json_annotation',
      if (network == Network.retrofit) 'retrofit',
      if (dataClass == DataClass.equatable) 'equatable',
      if (dataClass == DataClass.freezed) 'freezed_annotation',
      if (state == StateManagement.bloc) 'flutter_bloc',
      if (isRiverpod) ...['flutter_riverpod', 'riverpod_annotation'],
      if (di != DependencyInjection.riverpod) 'get_it',
      if (di == DependencyInjection.injectable) 'injectable',
      router.id,
    };
    final dev = <String>{
      'build_runner',
      'json_serializable',
      if (network == Network.retrofit) 'retrofit_generator',
      if (dataClass == DataClass.freezed) 'freezed',
      if (isRiverpod) 'riverpod_generator',
      if (di == DependencyInjection.injectable) 'injectable_generator',
      if (router == Routing.autoRoute) 'auto_route_generator',
    };
    return (dependencies: deps.toList(), devDependencies: dev.toList());
  }
}

import '../config/forge_config.dart';
import '../config/layout.dart';
import 'name.dart';

/// A generated class and the project-relative file declaring it.
final class Artifact {
  const Artifact(this.className, this.path);

  final String className;
  final String path;

  /// `camelCase` instance/provider name derived from the class name.
  String get instanceName =>
      className[0].toLowerCase() + className.substring(1);
}

/// Files of a state holder: one Bloc (bloc + event + state) or one Riverpod
/// notifier.
final class StateArtifacts {
  const StateArtifacts({
    required this.name,
    required this.holder,
    this.eventPath,
    this.statePath,
  });

  final Name name;

  /// `OrdersBloc` in `orders/orders_bloc.dart`, or `OrdersController`.
  final Artifact holder;
  final String? eventPath;
  final String? statePath;

  String get eventClass => '${name.pascal}Event';
  String get stateClass => '${name.pascal}State';
  String get statusEnum => '${name.pascal}Status';
  String get requestedEvent => '${name.pascal}Requested';

  /// Riverpod: `ordersControllerProvider`.
  String get providerName => '${holder.instanceName}Provider';
}

/// Single source of truth for class names and file paths (DRY): every
/// generator and wiring step asks here instead of building strings itself.
final class Artifacts {
  const Artifacts(this.config);

  final ForgeConfig config;

  String _dir(Layer layer, Name feature) => config.layout.dir(layer, feature);

  Artifact entity(Name feature, Name entity) => Artifact(
        entity.pascal,
        '${_dir(Layer.entity, feature)}/${entity.snake}.dart',
      );

  Artifact model(Name feature, Name entity) => Artifact(
        '${entity.pascal}Model',
        '${_dir(Layer.model, feature)}/${entity.snake}_model.dart',
      );

  Artifact repository(Name feature) => Artifact(
        '${feature.pascal}Repository',
        '${_dir(Layer.repository, feature)}/${feature.snake}_repository.dart',
      );

  Artifact repositoryImpl(Name feature) => Artifact(
        '${feature.pascal}RepositoryImpl',
        '${_dir(Layer.repositoryImpl, feature)}/'
            '${feature.snake}_repository_impl.dart',
      );

  Name dataSourceName(String raw) => Name(raw)
      .withoutSuffix(config.naming.dataSourceSuffix)
      .withoutSuffix('DataSource');

  /// The data source contract (`OrdersRemoteDataSource`).
  Artifact dataSource(Name feature, Name name) {
    final cls = '${name.pascal}${config.naming.dataSourceSuffix}';
    return Artifact(
        cls, '${_dir(Layer.dataSource, feature)}/${Name(cls).snake}.dart');
  }

  /// Concrete class of hand-written data sources (Dio, none); the Retrofit
  /// client is its own implementation.
  String dataSourceImplClass(Name feature, Name name) =>
      config.stack.network.handWritten
          ? '${dataSource(feature, name).className}Impl'
          : dataSource(feature, name).className;

  Name useCaseName(String raw) => Name(raw)
      .withoutSuffix(config.naming.useCaseSuffix)
      .withoutSuffix('UseCase');

  Artifact useCase(Name feature, Name name) {
    final suffix = Name(config.naming.useCaseSuffix);
    return Artifact(
      '${name.pascal}${suffix.pascal}',
      '${_dir(Layer.useCase, feature)}/${name.snake}_${suffix.words.join()}.dart',
    );
  }

  Name stateName(String raw) => Name(raw)
      .withoutSuffix('Bloc')
      .withoutSuffix('Cubit')
      .withoutSuffix('Controller')
      .withoutSuffix('Notifier');

  StateArtifacts state(Name feature, Name name) {
    final dir = _dir(Layer.state, feature);
    if (config.stack.isRiverpod) {
      return StateArtifacts(
        name: name,
        holder: Artifact(
          '${name.pascal}Controller',
          '$dir/${name.snake}_controller.dart',
        ),
      );
    }
    final base = '$dir/${name.snake}/${name.snake}';
    return StateArtifacts(
      name: name,
      holder: Artifact('${name.pascal}Bloc', '${base}_bloc.dart'),
      eventPath: '${base}_event.dart',
      statePath: '${base}_state.dart',
    );
  }

  Name screenName(String raw) => Name(raw)
      .withoutSuffix(config.naming.screenSuffix)
      .withoutSuffix('Screen')
      .withoutSuffix('Page');

  Artifact screen(Name feature, Name name) {
    final suffix = Name(config.naming.screenSuffix);
    return Artifact(
      '${name.pascal}${suffix.pascal}',
      '${_dir(Layer.screen, feature)}/${name.snake}_${suffix.snake}.dart',
    );
  }

  Artifact widget(Name feature, Name name) => Artifact(
      name.pascal, '${_dir(Layer.widget, feature)}/${name.snake}.dart');

  /// Riverpod DI: per-feature file holding the provider chain.
  String dependencies(Name feature) =>
      '${_dir(Layer.dependencies, feature)}/${feature.snake}_dependencies.dart';
}

/// An entity/model field, parsed from `name:Type` (`?` suffix = nullable).
final class Field {
  const Field(this.name, this.type);

  final Name name;
  final String type;

  bool get nullable => type.endsWith('?');

  static List<Field> parseAll(String? spec) {
    if (spec == null || spec.trim().isEmpty) return const [];
    return spec.split(',').where((s) => s.trim().isNotEmpty).map((part) {
      final pieces = part.split(':');
      if (pieces.length != 2 || pieces[1].trim().isEmpty) {
        throw FormatException('Field must be name:Type', part.trim());
      }
      return Field(Name(pieces[0]), pieces[1].trim());
    }).toList();
  }
}

/// How a remote payload maps to the domain result.
enum ResultShape { list, single, none }

/// One repository operation, carried through every layer of a feature:
/// data source method → repository method → use case.
final class Operation {
  const Operation({
    required this.name,
    required this.returnType,
    this.http = 'GET',
    this.path = '/',
    this.shape = ResultShape.none,
    this.modelClass,
  });

  final Name name;

  /// Domain type wrapped in `FutureEither` (`List<Order>`, `void`).
  final String returnType;
  final String http;
  final String path;
  final ResultShape shape;
  final String? modelClass;

  String get remoteReturnType => switch (shape) {
        ResultShape.list => 'List<$modelClass>',
        ResultShape.single => modelClass!,
        ResultShape.none => 'void',
      };
}

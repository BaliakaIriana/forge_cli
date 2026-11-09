import '../core/artifacts.dart';
import '../core/generation_plan.dart';
import '../core/name.dart';
import '../core/source_editor.dart';
import '../templates/data_templates.dart';
import '../templates/domain_templates.dart';
import '../templates/presentation_templates.dart';
import '../templates/template_context.dart';
import '../wiring/di_wiring.dart';
import '../wiring/route_wiring.dart';

/// Builds each artifact into a [GenerationPlan], wiring DI and routes.
///
/// CLI generators only parse arguments and call these methods; the feature
/// generator composes them (one implementation per artifact, DRY).
final class ArtifactBuilder {
  ArtifactBuilder(this.ctx)
      : artifacts = Artifacts(ctx.config),
        _domain = DomainTemplates(ctx),
        _data = DataTemplates(ctx),
        _presentation = PresentationTemplates(ctx),
        _di = DiWiring(ctx),
        _routes = RouteWiring(ctx);

  final TemplateContext ctx;
  final Artifacts artifacts;
  final DomainTemplates _domain;
  final DataTemplates _data;
  final PresentationTemplates _presentation;
  final DiWiring _di;
  final RouteWiring _routes;

  static final defaultFields = [Field(Name('id'), 'String')];

  // ------------------------------------------------------------- Domain --

  Artifact entity(
    GenerationPlan plan,
    Name feature,
    Name name, {
    List<Field>? fields,
  }) {
    final entity = artifacts.entity(feature, name);
    plan.create(entity.path, _domain.entity(entity, fields ?? defaultFields));
    return entity;
  }

  Artifact repository(
    GenerationPlan plan,
    Name feature, {
    List<Operation> operations = const [],
  }) {
    final contract = artifacts.repository(feature);
    final impl = artifacts.repositoryImpl(feature);
    final dataSource = artifacts.dataSource(feature, feature);
    final hasDataSource = plan.exists(dataSource.path);
    final types =
        operations.expand((o) => _typeImports(plan, feature, o.returnType));

    plan
      ..create(
        contract.path,
        _domain.repository(contract, operations, imports: types),
      )
      ..create(
        impl.path,
        _data.repositoryImpl(
          impl,
          contract,
          operations,
          dataSource: hasDataSource ? dataSource : null,
          imports: types,
        ),
      );
    _di.register(
      plan,
      Registration(
        kind: RegistrationKind.repository,
        contract: contract,
        implementation: impl,
        dependencies: [if (hasDataSource) Dependency(dataSource)],
        dependenciesFile: artifacts.dependencies(feature),
      ),
    );
    return contract;
  }

  /// Creates the use case and, when the repository lacks the matching
  /// method, adds it (stub in the implementation) so the code compiles.
  Artifact useCase(
    GenerationPlan plan,
    Name feature,
    Name name, {
    String returnType = 'void',
  }) {
    final useCase = artifacts.useCase(feature, name);
    final repository = artifacts.repository(feature);
    final operation = Operation(name: name, returnType: returnType);
    final types = _typeImports(plan, feature, returnType);

    if (!plan.exists(repository.path)) {
      this.repository(plan, feature, operations: [operation]);
    } else {
      _ensureRepositoryMethod(plan, feature, operation, types);
    }
    plan.create(
      useCase.path,
      _domain.useCase(useCase, repository, operation, imports: types),
    );
    _di.register(
      plan,
      Registration(
        kind: RegistrationKind.useCase,
        contract: useCase,
        implementation: useCase,
        dependencies: [Dependency(repository)],
        dependenciesFile: artifacts.dependencies(feature),
      ),
    );
    return useCase;
  }

  void _ensureRepositoryMethod(
    GenerationPlan plan,
    Name feature,
    Operation operation,
    List<String> types,
  ) {
    final contract = artifacts.repository(feature);
    final impl = artifacts.repositoryImpl(feature);
    final method = '${operation.name.camel}(';
    final signature = DomainTemplates.signature(operation);
    final typedefs = ctx.uri(ctx.config.core.typedefs);

    if (!(plan.read(contract.path)?.contains(method) ?? true)) {
      plan.edit(
        contract.path,
        reason: 'add ${operation.name.camel}',
        snippet: '$signature;',
        transform: (source) {
          final edited = SourceEditor.insertInClass(
              source, contract.className, '$signature;');
          return edited == null
              ? null
              : SourceEditor.addImports(edited, [typedefs, ...types]);
        },
      );
    }
    if (!(plan.read(impl.path)?.contains(method) ?? true)) {
      final stub = '@override\n$signature {\n'
          "  throw UnimplementedError('${operation.name.camel}');\n}";
      plan.edit(
        impl.path,
        reason: 'stub ${operation.name.camel}',
        snippet: stub,
        transform: (source) {
          final edited =
              SourceEditor.insertInClass(source, impl.className, stub);
          return edited == null
              ? null
              : SourceEditor.addImports(edited, [typedefs, ...types]);
        },
      );
    }
  }

  // --------------------------------------------------------------- Data --

  Artifact model(
    GenerationPlan plan,
    Name feature,
    Name name, {
    List<Field>? fields,
  }) {
    final model = artifacts.model(feature, name);
    final entity = artifacts.entity(feature, name);
    plan.create(
      model.path,
      _data.model(
        model,
        fields ?? defaultFields,
        entity: plan.exists(entity.path) ? entity : null,
      ),
    );
    return model;
  }

  Artifact dataSource(
    GenerationPlan plan,
    Name feature,
    Name name, {
    List<Operation> operations = const [],
  }) {
    final contract = artifacts.dataSource(feature, name);
    final implClass = artifacts.dataSourceImplClass(feature, name);
    final models = operations
        .map((o) => o.modelClass)
        .whereType<String>()
        .expand((m) => _typeImports(plan, feature, m));
    plan.create(
      contract.path,
      _data.dataSource(contract, implClass, operations, imports: models),
    );
    _di.register(
      plan,
      Registration(
        kind: RegistrationKind.dataSource,
        contract: contract,
        implementation: Artifact(implClass, contract.path),
        dependencies: [
          if (ctx.stack.network.usesDio) Dependency.dio,
        ],
        dependenciesFile: artifacts.dependencies(feature),
      ),
    );
    return contract;
  }

  // ------------------------------------------------------- Presentation --

  StateArtifacts state(
    GenerationPlan plan,
    Name feature,
    Name name, {
    List<Name> useCases = const [],
  }) {
    final state = artifacts.state(feature, name);
    final injected = <InjectedUseCase>[];
    for (final useCaseName in useCases) {
      final artifact = artifacts.useCase(feature, useCaseName);
      final source = plan.read(artifact.path);
      if (source == null) {
        plan.note('Use case ${artifact.className} not found at '
            '${artifact.path}; not injected.');
        continue;
      }
      final call = RegExp(r'FutureEither(?:<(.+)>|Void)\s+call\(([^)]*)\)')
          .firstMatch(source);
      injected.add(
        InjectedUseCase(
          artifact: artifact,
          paramName: useCaseName.camel,
          returnType: call == null ? null : (call.group(1) ?? 'void'),
          callable: call != null && call.group(2)!.trim().isEmpty,
          providerFile: artifacts.dependencies(feature),
        ),
      );
    }
    final types = injected
        .map((u) => u.returnType)
        .whereType<String>()
        .expand((t) => _typeImports(plan, feature, t))
        .toList();

    if (ctx.stack.isRiverpod) {
      plan.create(
        state.holder.path,
        _presentation.controller(state, injected, typeImports: types),
      );
      return state;
    }
    _presentation
        .bloc(state, injected, typeImports: types)
        .forEach(plan.create);
    _di.register(
      plan,
      Registration(
        kind: RegistrationKind.stateHolder,
        contract: state.holder,
        implementation: state.holder,
        dependencies: [
          for (final u in injected) Dependency(u.artifact, named: u.paramName),
        ],
      ),
    );
    return state;
  }

  Artifact screen(
    GenerationPlan plan,
    Name feature,
    Name name, {
    Name? stateName,
    String? routePath,
  }) {
    final screen = artifacts.screen(feature, name);
    final state = artifacts.state(feature, stateName ?? name);
    final hasState = plan.exists(state.holder.path);
    if (stateName != null && !hasState) {
      plan.note('State ${state.holder.className} not found; '
          'screen generated without it.');
    }
    plan.create(
      screen.path,
      _presentation.screen(
        screen,
        name.title,
        state: hasState ? state : null,
        hasData: hasState && _stateHasData(plan, state),
      ),
    );
    if (routePath != null) {
      _routes.addRoute(
        plan,
        RouteSpec(name: name, screen: screen, path: routePath),
      );
    }
    return screen;
  }

  Artifact widget(
    GenerationPlan plan,
    Name feature,
    Name name, {
    bool stateful = false,
  }) {
    final widget = artifacts.widget(feature, name);
    plan.create(widget.path, _presentation.widget(widget, stateful: stateful));
    return widget;
  }

  // ------------------------------------------------------------ Feature --

  /// `nest g resource`-like: the whole vertical slice, wired.
  void feature(
    GenerationPlan plan,
    Name feature, {
    Name? entityName,
    List<Field>? fields,
    bool withScreen = true,
  }) {
    final name = entityName ?? feature.singular;
    final entityArtifact = entity(plan, feature, name, fields: fields);
    final modelArtifact = model(plan, feature, name, fields: fields);
    final operation = Operation(
      name: Name('get ${feature.snake}'),
      returnType: 'List<${entityArtifact.className}>',
      path: '/${feature.kebab}',
      shape: ResultShape.list,
      modelClass: modelArtifact.className,
    );
    dataSource(plan, feature, feature, operations: [operation]);
    repository(plan, feature, operations: [operation]);
    useCase(plan, feature, operation.name, returnType: operation.returnType);
    state(plan, feature, feature, useCases: [operation.name]);
    if (withScreen) {
      screen(plan, feature, feature,
          stateName: feature, routePath: '/${feature.kebab}');
    }
  }

  // ------------------------------------------------------------ helpers --

  bool _stateHasData(GenerationPlan plan, StateArtifacts state) {
    if (ctx.stack.isRiverpod) {
      final source = plan.read(state.holder.path) ?? '';
      return !source.contains('Future<void> build');
    }
    final source = plan.read(state.statePath!) ?? '';
    return RegExp(r'\bdata\b').hasMatch(source);
  }

  /// Imports for the feature's entities/models named in [type]
  /// (`List<Order>` → the `Order` entity file), when they exist.
  List<String> _typeImports(GenerationPlan plan, Name feature, String type) {
    final uris = <String>[];
    for (final match in RegExp(r'\b[A-Z]\w*').allMatches(type)) {
      final identifier = match[0]!;
      if (const {'List', 'Map', 'Set', 'String', 'DateTime', 'Object'}
          .contains(identifier)) {
        continue;
      }
      final name = Name(identifier);
      final candidates = [
        artifacts.entity(feature, name),
        if (identifier.endsWith('Model'))
          artifacts.model(feature, name.withoutSuffix('Model')),
      ];
      for (final candidate in candidates) {
        if (candidate.className == identifier && plan.exists(candidate.path)) {
          uris.add(ctx.uri(candidate.path));
        }
      }
    }
    return uris;
  }
}

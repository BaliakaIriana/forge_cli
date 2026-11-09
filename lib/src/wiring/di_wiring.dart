import '../config/stack.dart';
import '../core/artifacts.dart';
import '../core/generation_plan.dart';
import '../core/source_editor.dart';
import '../templates/core_templates.dart';
import '../templates/template_context.dart';

enum RegistrationKind { dataSource, repository, useCase, stateHolder }

/// A constructor dependency of a registered class.
final class Dependency {
  const Dependency(this.artifact, {this.named});

  /// The `Dio` client, provided by the project core.
  static const dio = Dependency(Artifact('Dio', ''));

  final Artifact artifact;

  /// Named constructor parameter, or `null` for positional.
  final String? named;

  bool get isDio => identical(this, dio) || artifact.className == 'Dio';
}

/// A class to register in the DI container.
final class Registration {
  const Registration({
    required this.kind,
    required this.contract,
    required this.implementation,
    this.dependencies = const [],
    this.dependenciesFile,
  });

  final RegistrationKind kind;

  /// Type resolved by consumers (interface for repositories).
  final Artifact contract;

  /// Concrete class instantiated (may equal [contract]).
  final Artifact implementation;
  final List<Dependency> dependencies;

  /// Riverpod: feature provider file receiving the provider.
  final String? dependenciesFile;

  /// Generated implementations without dependency have a const
  /// constructor (Blocs never do).
  bool get isConst =>
      dependencies.isEmpty && kind != RegistrationKind.stateHolder;
}

/// Wires generated classes into the project's DI (Strategy pattern: one
/// implementation per [DependencyInjection]).
abstract interface class DiWiring {
  void register(GenerationPlan plan, Registration registration);

  factory DiWiring(TemplateContext ctx) => switch (ctx.stack.di) {
        DependencyInjection.getIt => GetItWiring(ctx),
        // Annotations are emitted by the templates; build_runner wires them.
        DependencyInjection.injectable => const _NoWiring(),
        DependencyInjection.riverpod => RiverpodWiring(ctx),
      };
}

final class _NoWiring implements DiWiring {
  const _NoWiring();

  @override
  void register(GenerationPlan plan, Registration registration) {}
}

/// Inserts `getIt.register...` calls above the `// forge:di:*` anchors.
final class GetItWiring implements DiWiring {
  const GetItWiring(this.ctx);

  final TemplateContext ctx;

  @override
  void register(GenerationPlan plan, Registration r) {
    final args = r.dependencies
        .map((d) => d.named == null ? 'getIt()' : '${d.named}: getIt()')
        .join(', ');
    final instance =
        '${r.isConst ? 'const ' : ''}${r.implementation.className}';
    final factory = r.kind == RegistrationKind.stateHolder;
    final method = factory ? 'registerFactory' : 'registerLazySingleton';
    final snippet = 'getIt.$method<${r.contract.className}>(\n'
        '  () => $instance($args),\n);';
    final anchor = switch (r.kind) {
      RegistrationKind.dataSource => Anchors.diDataSources,
      RegistrationKind.repository => Anchors.diRepositories,
      RegistrationKind.useCase => Anchors.diUseCases,
      RegistrationKind.stateHolder => Anchors.diBlocs,
    };
    final imports = {
      ctx.uri(r.contract.path),
      ctx.uri(r.implementation.path),
    };
    plan.edit(
      ctx.config.core.di,
      reason: 'register ${r.contract.className}',
      snippet: snippet,
      transform: (source) {
        final inserted = SourceEditor.insertAtAnchor(source, anchor, snippet);
        return inserted == null
            ? null
            : SourceEditor.addImports(inserted, imports);
      },
    );
  }
}

/// Appends `@Riverpod` provider functions to the feature dependencies file.
final class RiverpodWiring implements DiWiring {
  const RiverpodWiring(this.ctx);

  final TemplateContext ctx;

  @override
  void register(GenerationPlan plan, Registration r) {
    if (r.kind == RegistrationKind.stateHolder) return;
    final file = r.dependenciesFile!;
    if (!plan.exists(file)) {
      plan.create(file, CoreTemplates(ctx).dependencies(file));
    }
    final args = r.dependencies.map((d) {
      final provider =
          d.isDio ? 'dioProvider' : '${d.artifact.instanceName}Provider';
      final value = 'ref.watch($provider)';
      return d.named == null ? value : '${d.named}: $value';
    }).join(', ');
    final snippet = '@Riverpod(keepAlive: true)\n'
        '${r.contract.className} ${r.contract.instanceName}(Ref ref) =>\n'
        '    ${r.isConst ? 'const ' : ''}${r.implementation.className}($args);\n\n';
    final imports = {
      ctx.uri(r.contract.path),
      ctx.uri(r.implementation.path),
      if (r.dependencies.any((d) => d.isDio) &&
          ctx.config.core.dioProvider != null)
        ctx.uri(ctx.config.core.dioProvider!),
    };
    plan.edit(
      file,
      reason: 'provide ${r.contract.className}',
      snippet: snippet,
      transform: (source) {
        final inserted =
            SourceEditor.insertAtAnchor(source, Anchors.providers, snippet);
        return inserted == null
            ? null
            : SourceEditor.addImports(inserted, imports);
      },
    );
  }
}

import '../core/artifacts.dart';
import 'template_context.dart';

/// Entities, repository contracts and use cases. The domain layer imports
/// nothing from data or presentation.
final class DomainTemplates {
  const DomainTemplates(this.ctx);

  final TemplateContext ctx;

  String entity(Artifact entity, List<Field> fields) {
    final cls = entity.className;
    if (ctx.freezed) {
      final file = entity.path.split('/').last.replaceAll('.dart', '');
      final params = fields
          .map((f) => f.nullable
              ? '${f.type} ${f.name.camel},'
              : 'required ${f.type} ${f.name.camel},')
          .join('\n    ');
      return '''
${ctx.imports([
            'package:freezed_annotation/freezed_annotation.dart'
          ])}part '$file.freezed.dart';

@freezed
abstract class $cls with _\$$cls {
  const factory $cls({
    $params
  }) = _$cls;
}
''';
    }
    return '''
${ctx.imports([
          'package:equatable/equatable.dart'
        ])}class $cls extends Equatable {
  const $cls(${_namedParams(fields)});

${fields.map((f) => '  final ${f.type} ${f.name.camel};').join('\n')}

  @override
  List<Object?> get props => [${fields.map((f) => f.name.camel).join(', ')}];
}
''';
  }

  String repository(
    Artifact repository,
    List<Operation> operations, {
    Iterable<String> imports = const [],
  }) {
    final body = operations.map((o) => '  ${signature(o)};').join('\n\n');
    return '''
${ctx.imports([
          if (operations.isNotEmpty) ctx.uri(ctx.config.core.typedefs),
          ...imports
        ])}abstract interface class ${repository.className} {
$body
}
''';
  }

  String useCase(
    Artifact useCase,
    Artifact repository,
    Operation operation, {
    Iterable<String> imports = const [],
  }) =>
      '''
${ctx.imports([
            ctx.uri(ctx.config.core.typedefs),
            ctx.uri(repository.path),
            if (ctx.injectable)
              TemplateContext.injectableImport(['lazySingleton']),
            ...imports,
          ])}${ctx.annotation('@lazySingleton')}class ${useCase.className} {
  const ${useCase.className}(this._repository);

  final ${repository.className} _repository;

  FutureEither<${operation.returnType}> call() => _repository.${operation.name.camel}();
}
''';

  /// `FutureEither<T> name()` — shared by interface, impl and use case.
  static String signature(Operation o) =>
      'FutureEither<${o.returnType}> ${o.name.camel}()';

  static String _namedParams(List<Field> fields) {
    if (fields.isEmpty) return '';
    final params = fields
        .map((f) => f.nullable
            ? 'this.${f.name.camel},'
            : 'required this.${f.name.camel},')
        .join('\n    ');
    return '{\n    $params\n  }';
  }
}

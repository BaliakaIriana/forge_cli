import '../config/stack.dart';
import '../core/artifacts.dart';
import 'domain_templates.dart';
import 'template_context.dart';

/// Models (DTOs), remote data sources and repository implementations.
final class DataTemplates {
  const DataTemplates(this.ctx);

  final TemplateContext ctx;

  String model(Artifact model, List<Field> fields, {Artifact? entity}) {
    final cls = model.className;
    final file = model.path.split('/').last.replaceAll('.dart', '');
    final rename = ctx.stack.jsonFieldCase.fieldRename;
    final jsonAnnotation = rename == null
        ? '@JsonSerializable()'
        : '@JsonSerializable(fieldRename: $rename)';
    final toEntity = entity == null
        ? ''
        : '\n  ${entity.className} toEntity() => ${entity.className}('
            '${fields.map((f) => '${f.name.camel}: ${f.name.camel}').join(', ')});\n';
    final imports = [
      if (entity != null) ctx.uri(entity.path),
      if (ctx.freezed)
        'package:freezed_annotation/freezed_annotation.dart'
      else
        'package:json_annotation/json_annotation.dart',
    ];

    if (ctx.freezed) {
      final params = fields
          .map((f) => f.nullable
              ? '${f.type} ${f.name.camel},'
              : 'required ${f.type} ${f.name.camel},')
          .join('\n    ');
      return '''
${ctx.imports(imports)}part '$file.freezed.dart';
part '$file.g.dart';

@freezed
abstract class $cls with _\$$cls {
  const $cls._();
${rename == null ? '' : '\n  // ignore: invalid_annotation_target\n  $jsonAnnotation'}
  const factory $cls({
    $params
  }) = _$cls;

  factory $cls.fromJson(Map<String, dynamic> json) => _\$${cls}FromJson(json);
$toEntity}
''';
    }

    final params = fields
        .map((f) => f.nullable
            ? 'this.${f.name.camel},'
            : 'required this.${f.name.camel},')
        .join('\n    ');
    return '''
${ctx.imports(imports)}part '$file.g.dart';

$jsonAnnotation
class $cls {
  const $cls(${fields.isEmpty ? '' : '{\n    $params\n  }'});

  factory $cls.fromJson(Map<String, dynamic> json) => _\$${cls}FromJson(json);

${fields.map((f) => '  final ${f.type} ${f.name.camel};').join('\n')}

  Map<String, dynamic> toJson() => _\$${cls}ToJson(this);
$toEntity}
''';
  }

  /// Retrofit client, interface + Dio implementation, or interface +
  /// client-free implementation (`network: none`).
  String dataSource(
    Artifact dataSource,
    String implClass,
    List<Operation> operations, {
    Iterable<String> imports = const [],
  }) =>
      switch (ctx.stack.network) {
        Network.retrofit => _retrofit(dataSource, operations, imports),
        Network.dio => _dio(dataSource, implClass, operations, imports),
        Network.none => _none(dataSource, implClass, operations, imports),
      };

  /// No client: the implementation declares no dependency. Inject the one
  /// you need through its constructor, then in the DI registration.
  String _none(
    Artifact ds,
    String implClass,
    List<Operation> operations,
    Iterable<String> imports,
  ) {
    final cls = ds.className;
    final signatures = operations
        .map((o) => '  Future<${o.remoteReturnType}> ${o.name.camel}();');
    final bodies = operations.map((o) => '''
  @override
  Future<${o.remoteReturnType}> ${o.name.camel}() {
    // TODO: implement with the client injected in the constructor.
    throw UnimplementedError('${o.name.camel}');
  }''');
    return '''
${ctx.imports([
          if (ctx.injectable)
            TemplateContext.injectableImport(['LazySingleton']),
          ...imports,
        ])}abstract interface class $cls {
${signatures.join('\n\n')}
}

/// Add the client this data source needs (Supabase, Firebase, local
/// database...) as a constructor parameter; DI injects it.
${ctx.annotation('@LazySingleton(as: $cls)')}class $implClass implements $cls {
  const $implClass();
${bodies.isEmpty ? '' : '\n${bodies.join('\n\n')}\n'}}
''';
  }

  String _retrofit(
    Artifact ds,
    List<Operation> operations,
    Iterable<String> imports,
  ) {
    final cls = ds.className;
    final file = ds.path.split('/').last.replaceAll('.dart', '');
    final factory = ctx.injectable
        ? '  @factoryMethod\n  factory $cls(Dio dio) = _$cls;'
        : '  factory $cls(Dio dio, {String? baseUrl}) = _$cls;';
    final methods = operations
        .map((o) => "  @${o.http}('${o.path}')\n"
            '  Future<${o.remoteReturnType}> ${o.name.camel}();')
        .join('\n\n');
    return '''
${ctx.imports([
          'package:dio/dio.dart hide Headers',
          'package:retrofit/retrofit.dart',
          if (ctx.injectable)
            TemplateContext.injectableImport(
                ['factoryMethod', 'lazySingleton']),
          ...imports,
        ])}part '$file.g.dart';

${ctx.annotation('@lazySingleton')}@RestApi()
abstract class $cls {
$factory
${methods.isEmpty ? '' : '\n$methods\n'}}
''';
  }

  String _dio(
    Artifact ds,
    String implClass,
    List<Operation> operations,
    Iterable<String> imports,
  ) {
    final cls = ds.className;
    final signatures = operations
        .map((o) => '  Future<${o.remoteReturnType}> ${o.name.camel}();');
    final bodies = operations.map((o) {
      final call = switch (o.shape) {
        ResultShape.list => '''
    final response = await _dio.${o.http.toLowerCase()}<List<dynamic>>('${o.path}');
    return (response.data ?? const [])
        .map((json) => ${o.modelClass}.fromJson(json as Map<String, dynamic>))
        .toList();''',
        ResultShape.single => '''
    final response = await _dio.${o.http.toLowerCase()}<Map<String, dynamic>>('${o.path}');
    return ${o.modelClass}.fromJson(response.data!);''',
        ResultShape.none =>
          "    await _dio.${o.http.toLowerCase()}<void>('${o.path}');",
      };
      return '''
  @override
  Future<${o.remoteReturnType}> ${o.name.camel}() async {
$call
  }''';
    });
    final unused = operations.isEmpty ? '  // ignore: unused_field\n' : '';
    return '''
${ctx.imports([
          'package:dio/dio.dart',
          if (ctx.injectable)
            TemplateContext.injectableImport(['LazySingleton']),
          ...imports,
        ])}abstract interface class $cls {
${signatures.join('\n\n')}
}

${ctx.annotation('@LazySingleton(as: $cls)')}class $implClass implements $cls {
  const $implClass(this._dio);

$unused  final Dio _dio;
${bodies.isEmpty ? '' : '\n${bodies.join('\n\n')}\n'}}
''';
  }

  String repositoryImpl(
    Artifact impl,
    Artifact contract,
    List<Operation> operations, {
    Artifact? dataSource,
    Iterable<String> imports = const [],
  }) {
    final methods = operations.map((o) {
      final remote = '_remote.${o.name.camel}()';
      final body = dataSource == null
          ? "throw UnimplementedError('${o.name.camel}');"
          : switch (o.shape) {
              ResultShape.list =>
                'runTask(() async {\n        final models = await $remote;\n'
                    '        return models.map((model) => model.toEntity()).toList();\n'
                    '      });',
              ResultShape.single =>
                'runTask(() async => (await $remote).toEntity());',
              ResultShape.none => 'runTask(() => $remote);',
            };
      final arrow = dataSource == null ? '{\n    $body\n  }' : '=> $body';
      return '''
  @override
  ${DomainTemplates.signature(o)} $arrow''';
    });
    final field = dataSource == null
        ? '  const ${impl.className}();\n'
        : '  const ${impl.className}(this._remote);\n\n'
            '${operations.isEmpty ? '  // ignore: unused_field\n' : ''}'
            '  final ${dataSource.className} _remote;\n';
    return '''
${ctx.imports([
          ctx.uri(contract.path),
          if (operations.isNotEmpty) ctx.uri(ctx.config.core.typedefs),
          if (dataSource != null && operations.isNotEmpty)
            ctx.uri(ctx.config.core.taskRunner),
          if (dataSource != null) ctx.uri(dataSource.path),
          if (ctx.injectable)
            TemplateContext.injectableImport(['LazySingleton']),
          ...imports,
        ])}${ctx.annotation('@LazySingleton(as: ${contract.className})')}class ${impl.className} implements ${contract.className} {
$field${methods.isEmpty ? '' : '\n${methods.join('\n\n')}\n'}}
''';
  }
}

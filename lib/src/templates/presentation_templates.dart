import '../config/stack.dart';
import '../core/artifacts.dart';
import 'template_context.dart';

/// A use case injected into a state holder.
final class InjectedUseCase {
  const InjectedUseCase({
    required this.artifact,
    required this.paramName,
    required this.returnType,
    required this.callable,
    this.providerFile,
  });

  final Artifact artifact;

  /// Constructor parameter name (`getOrders`).
  final String paramName;

  /// `T` of `FutureEither<T>`; `null` if unknown.
  final String? returnType;

  /// Whether `call()` takes no argument, so the generated "requested"
  /// event can invoke it.
  final bool callable;

  /// Riverpod: file declaring the use case provider.
  final String? providerFile;
}

/// Blocs, Riverpod notifiers, screens and widgets.
final class PresentationTemplates {
  const PresentationTemplates(this.ctx);

  final TemplateContext ctx;

  // ---------------------------------------------------------------- Bloc --

  /// Returns `{path: content}` for the bloc, event and state files.
  Map<String, String> bloc(
    StateArtifacts s,
    List<InjectedUseCase> useCases, {
    Iterable<String> typeImports = const [],
  }) {
    final primary = useCases.where((u) => u.callable).firstOrNull;
    final dataType = _dataType(primary);
    final bloc = s.holder.className;
    final blocFile = s.holder.path.split('/').last;
    final base = blocFile.replaceAll('.dart', '');

    // One event + handler per parameterless use case: the primary one loads
    // the state, the others run and keep the loaded data.
    final secondary =
        useCases.where((u) => u.callable && u != primary).toList();
    final events = <(String, String)>[
      (s.requestedEvent, '_onRequested'),
      for (final u in secondary)
        (_eventOf(s, u), '_on${_pascal(u.paramName)}Requested'),
    ];

    final fields = useCases.map((u) {
      final unused = u.callable
          ? ''
          : '  // TODO: call it from a dedicated event carrying its parameters.\n'
              '  // ignore: unused_field\n';
      return '$unused  final ${u.artifact.className} _${u.paramName};';
    }).join('\n');
    final header = useCases.isEmpty
        ? '  $bloc() : super(const ${s.stateClass}()) {'
        : ctx.privateNamedParameters
            ? '  $bloc({\n'
                '${useCases.map((u) => '    required this._${u.paramName},\n').join()}'
                '  }) : super(const ${s.stateClass}()) {'
            : '  $bloc({\n'
                '${useCases.map((u) => '    required ${u.artifact.className} ${u.paramName},\n').join()}'
                '  })  : ${useCases.map((u) => '_${u.paramName} = ${u.paramName}').join(',\n        ')},\n'
                '        super(const ${s.stateClass}()) {';

    final keep = dataType == null ? '' : ', data: state.data';
    String handler(
      String event,
      String method,
      InjectedUseCase u, {
      required bool loadsData,
    }) =>
        '''
  Future<void> $method(
    $event event,
    Emitter<${s.stateClass}> emit,
  ) async {
    emit(${s.stateClass}(status: ${s.statusEnum}.loading$keep));
    final result = await _${u.paramName}();
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        ${s.stateClass}(status: ${s.statusEnum}.failure$keep, failure: failure),
      ),
      (${loadsData ? 'data' : '_'}) => emit(
        ${s.stateClass}(status: ${s.statusEnum}.success${loadsData ? ', data: data' : keep}),
      ),
    );
  }''';

    final handlers = [
      if (primary == null)
        '''
  void _onRequested(${s.requestedEvent} event, Emitter<${s.stateClass}> emit) {
    // TODO: inject a use case and call it here.
    emit(const ${s.stateClass}(status: ${s.statusEnum}.success));
  }'''
      else
        handler(
          s.requestedEvent,
          '_onRequested',
          primary,
          loadsData: dataType != null,
        ),
      for (final u in secondary)
        handler(
          _eventOf(s, u),
          '_on${_pascal(u.paramName)}Requested',
          u,
          loadsData: false,
        ),
    ].join('\n\n');

    final blocSource = '''
${ctx.imports([
          if (!ctx.freezed) 'package:equatable/equatable.dart',
          if (ctx.freezed) 'package:freezed_annotation/freezed_annotation.dart',
          'package:flutter_bloc/flutter_bloc.dart',
          if (ctx.injectable) TemplateContext.injectableImport(['injectable']),
          ctx.uri(ctx.config.core.failure),
          ...useCases.map((u) => ctx.uri(u.artifact.path)),
          ...typeImports,
        ])}part '${s.eventPath!.split('/').last}';
part '${s.statePath!.split('/').last}';
${ctx.freezed ? "part '$base.freezed.dart';\n" : ''}
${ctx.annotation('@injectable')}class $bloc extends Bloc<${s.eventClass}, ${s.stateClass}> {
$header
${events.map((e) => '    on<${e.$1}>(${e.$2});').join('\n')}
  }
${fields.isEmpty ? '' : '\n$fields\n'}
$handlers
}
''';

    final eventClasses = events
        .map(
          (e) => 'final class ${e.$1} extends ${s.eventClass} {\n'
              '  const ${e.$1}();\n}',
        )
        .join('\n\n');
    final eventSource = ctx.freezed
        ? '''
part of '$blocFile';

sealed class ${s.eventClass} {
  const ${s.eventClass}();
}

$eventClasses
'''
        : '''
part of '$blocFile';

sealed class ${s.eventClass} extends Equatable {
  const ${s.eventClass}();

  @override
  List<Object?> get props => [];
}

$eventClasses
''';

    final dataField = dataType == null ? '' : '${_nullable(dataType)} data';
    final stateSource = ctx.freezed
        ? '''
part of '$blocFile';

enum ${s.statusEnum} { initial, loading, success, failure }

@freezed
abstract class ${s.stateClass} with _\$${s.stateClass} {
  const factory ${s.stateClass}({
    @Default(${s.statusEnum}.initial) ${s.statusEnum} status,
${dataType == null ? '' : '    $dataField,\n'}    Failure? failure,
  }) = _${s.stateClass};
}
'''
        : '''
part of '$blocFile';

enum ${s.statusEnum} { initial, loading, success, failure }

final class ${s.stateClass} extends Equatable {
  const ${s.stateClass}({
    this.status = ${s.statusEnum}.initial,
${dataType == null ? '' : '    this.data,\n'}    this.failure,
  });

  final ${s.statusEnum} status;
${dataType == null ? '' : '  final $dataField;\n'}  final Failure? failure;

  @override
  List<Object?> get props => [status,${dataType == null ? '' : ' data,'} failure];
}
''';

    return {
      s.holder.path: blocSource,
      s.eventPath!: eventSource,
      s.statePath!: stateSource,
    };
  }

  // ------------------------------------------------------------ Riverpod --

  String controller(
    StateArtifacts s,
    List<InjectedUseCase> useCases, {
    Iterable<String> typeImports = const [],
  }) {
    final primary = useCases.where((u) => u.callable).firstOrNull;
    final dataType = _dataType(primary) ?? 'void';
    final file = s.holder.path.split('/').last.replaceAll('.dart', '');
    final body = primary == null
        ? '''
  @override
  Future<$dataType> build() async {
    // TODO: read a use case provider and load the initial state.
  }'''
        : '''
  @override
  Future<$dataType> build() async {
    final result = await ref.watch(${primary.artifact.instanceName}Provider)();
    return result.fold((failure) => throw failure, (${dataType == 'void' ? '_' : 'data'}) ${dataType == 'void' ? '{}' : '=> data'});
  }''';
    return '''
${ctx.imports([
          'package:riverpod_annotation/riverpod_annotation.dart',
          ...useCases
              .map((u) => u.providerFile)
              .whereType<String>()
              .map(ctx.uri),
          ...typeImports,
        ])}part '$file.g.dart';

@riverpod
class ${s.holder.className} extends _\$${s.holder.className} {
$body
}
''';
  }

  // -------------------------------------------------------------- Screen --

  String screen(
    Artifact screen,
    String title, {
    StateArtifacts? state,
    bool hasData = false,
  }) {
    final cls = screen.className;
    final autoRoute = ctx.stack.router == Routing.autoRoute;
    final routePage = autoRoute ? '@RoutePage()\n' : '';
    final common = [
      'package:flutter/material.dart',
      if (autoRoute) 'package:auto_route/auto_route.dart',
    ];

    if (state == null) {
      return '''
${ctx.imports(common)}${routePage}class $cls extends StatelessWidget {
  const $cls({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('$title')),
      body: const Center(child: Text('$title')),
    );
  }
}
''';
    }

    if (ctx.stack.isRiverpod) {
      return '''
${ctx.imports([
            ...common,
            'package:flutter_riverpod/flutter_riverpod.dart',
            ctx.uri(state.holder.path),
          ])}${routePage}class $cls extends ConsumerWidget {
  const $cls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(${state.providerName});
    return Scaffold(
      appBar: AppBar(title: const Text('$title')),
      body: state.when(
        data: (${hasData ? 'data' : '_'}) => Center(child: Text(${hasData ? "'\$data'" : "'$title'"})),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('\$error')),
      ),
    );
  }
}
''';
    }

    final view = '_${cls}View';
    return '''
${ctx.imports([
          ...common,
          'package:flutter_bloc/flutter_bloc.dart',
          ctx.uri(ctx.config.core.di),
          ctx.uri(state.holder.path),
        ])}${routePage}class $cls extends StatelessWidget {
  const $cls({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<${state.holder.className}>(
      create: (_) => getIt<${state.holder.className}>()..add(const ${state.requestedEvent}()),
      child: const $view(),
    );
  }
}

class $view extends StatelessWidget {
  const $view();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('$title')),
      body: BlocBuilder<${state.holder.className}, ${state.stateClass}>(
        builder: (context, state) => switch (state.status) {
          ${state.statusEnum}.initial ||
          ${state.statusEnum}.loading =>
            const Center(child: CircularProgressIndicator()),
          ${state.statusEnum}.failure =>
            Center(child: Text('\${state.failure}')),
          ${state.statusEnum}.success =>
            Center(child: Text(${hasData ? "'\${state.data}'" : "'$title'"})),
        },
      ),
    );
  }
}
''';
  }

  String widget(Artifact widget, {bool stateful = false}) {
    final cls = widget.className;
    final imports = ctx.imports(['package:flutter/material.dart']);
    if (!stateful) {
      return '''
${imports}class $cls extends StatelessWidget {
  const $cls({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
''';
    }
    return '''
${imports}class $cls extends StatefulWidget {
  const $cls({super.key});

  @override
  State<$cls> createState() => _${cls}State();
}

class _${cls}State extends State<$cls> {
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
''';
  }

  static String _pascal(String camel) =>
      camel[0].toUpperCase() + camel.substring(1);

  static String _eventOf(StateArtifacts s, InjectedUseCase u) =>
      '${s.name.pascal}${_pascal(u.paramName)}Requested';

  static String? _dataType(InjectedUseCase? useCase) {
    final type = useCase?.returnType;
    return type == null || type == 'void' ? null : type;
  }

  static String _nullable(String type) => type.endsWith('?') ? type : '$type?';
}

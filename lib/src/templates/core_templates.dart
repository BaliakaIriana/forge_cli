import '../config/stack.dart';
import '../core/source_editor.dart';
import 'template_context.dart';

/// Anchor names, shared by templates (which emit them) and wiring (which
/// inserts code above them).
abstract final class Anchors {
  static const diDataSources = 'di:data-sources';
  static const diRepositories = 'di:repositories';
  static const diUseCases = 'di:usecases';
  static const diBlocs = 'di:blocs';
  static const di = [diDataSources, diRepositories, diUseCases, diBlocs];

  static const routes = 'routes';
  static const routePaths = 'route-paths';
  static const providers = 'providers';
}

/// Base files `forge init` can scaffold when the project lacks them.
final class CoreTemplates {
  const CoreTemplates(this.ctx);

  final TemplateContext ctx;

  String _a(String anchor) => SourceEditor.anchorComment(anchor);

  String failure() => '''
/// Base class of every expected error crossing a layer boundary.
sealed class Failure {
  const Failure(this.message, {this.error});

  final String message;
  final Object? error;

  @override
  String toString() => message;
}

/// The server answered with an error.
final class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.error, this.statusCode});

  final int? statusCode;
}

/// The server could not be reached.
final class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.error});
}

/// Local storage error.
final class CacheFailure extends Failure {
  const CacheFailure(super.message, {super.error});
}

/// Anything else.
final class UnknownFailure extends Failure {
  const UnknownFailure(super.message, {super.error});
}
''';

  String typedefs() => '''
${ctx.imports([
            ctx.stack.functional.import,
            ctx.uri(ctx.config.core.failure)
          ])}typedef FutureEither<T> = Future<Either<Failure, T>>;
typedef FutureEitherVoid = FutureEither<void>;
''';

  String taskRunner() {
    final dio = ctx.stack.network.usesDio;
    final dioCatch = dio
        ? '''
  } on DioException catch (error) {
    if (_isConnectivityError(error)) {
      return Left(NetworkFailure('No internet connection', error: error));
    }
    return Left(
      ServerFailure(
        error.message ?? 'Server error',
        error: error,
        statusCode: error.response?.statusCode,
      ),
    );'''
        : '';
    final dioHelper = dio
        ? '''

bool _isConnectivityError(DioException error) =>
    error.type == DioExceptionType.connectionError ||
    error.type == DioExceptionType.connectionTimeout ||
    error.error is SocketException;
'''
        : '';
    return '''
${ctx.imports([
          'dart:io',
          if (dio) 'package:dio/dio.dart',
          ctx.stack.functional.import,
          ctx.uri(ctx.config.core.failure),
          ctx.uri(ctx.config.core.typedefs),
        ])}/// Runs [action] and turns any exception into a [Failure], so repositories
/// return `Either` values instead of throwing.
FutureEither<T> runTask<T>(Future<T> Function() action) async {
  try {
    return Right(await action());$dioCatch
  } on SocketException catch (error) {
    return Left(NetworkFailure('No internet connection', error: error));
  } catch (error) {
    return Left(UnknownFailure(error.toString(), error: error));
  }
}
$dioHelper''';
  }

  String di() {
    final dio = ctx.stack.network.usesDio;
    if (ctx.stack.di == DependencyInjection.injectable) {
      final config = ctx.config.core.di
          .split('/')
          .last
          .replaceAll('.dart', '.config.dart');
      return '''
${ctx.imports([
            if (dio) 'package:dio/dio.dart',
            'package:get_it/get_it.dart',
            TemplateContext.injectableImport(
              dio
                  ? ['InjectableInit', 'lazySingleton', 'module']
                  : ['InjectableInit'],
            ),
            config,
          ])}final GetIt getIt = GetIt.instance;

/// Registers the app dependencies. Call once from `main()`.
@InjectableInit()
void configureDependencies() => getIt.init();
${dio ? '''
@module
abstract class NetworkModule {
  @lazySingleton
  Dio get dio => Dio();
}
''' : ''}''';
    }
    return '''
${ctx.imports([
          if (dio) 'package:dio/dio.dart',
          'package:get_it/get_it.dart',
        ])}final GetIt getIt = GetIt.instance;

/// Registers the app dependencies. Call once from `main()`.
void configureDependencies() {
${dio ? '  getIt.registerLazySingleton<Dio>(() => Dio());\n\n' : ''}  ${_a(Anchors.diDataSources)}
  ${_a(Anchors.diRepositories)}
  ${_a(Anchors.diUseCases)}
  ${_a(Anchors.diBlocs)}
}
''';
  }

  String dioProvider() {
    final file =
        ctx.config.core.dioProvider!.split('/').last.replaceAll('.dart', '');
    return '''
${ctx.imports([
          'package:dio/dio.dart',
          'package:riverpod_annotation/riverpod_annotation.dart'
        ])}part '$file.g.dart';

@Riverpod(keepAlive: true)
Dio dio(Ref ref) => Dio();
''';
  }

  String router() {
    if (ctx.stack.router == Routing.autoRoute) {
      final gr = ctx.config.core.router
          .split('/')
          .last
          .replaceAll('.dart', '.gr.dart');
      return '''
${ctx.imports([
            'package:auto_route/auto_route.dart',
            gr
          ])}@AutoRouterConfig(replaceInRouteName: 'Screen|Page,Route')
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
        ${_a(Anchors.routes)}
      ];
}
''';
    }
    return '''
${ctx.imports([
          'package:go_router/go_router.dart'
        ])}final GoRouter appRouter = GoRouter(
  routes: <RouteBase>[
    ${_a(Anchors.routes)}
  ],
);
''';
  }

  String routes() => '''
/// Route paths. Use `context.go(AppRoutes.x)`, never raw strings.
abstract final class AppRoutes {
  ${_a(Anchors.routePaths)}
}
''';

  /// Riverpod: per-feature provider chain file.
  String dependencies(String path) {
    final file = path.split('/').last.replaceAll('.dart', '');
    return '''
${ctx.imports([
          'package:riverpod_annotation/riverpod_annotation.dart'
        ])}part '$file.g.dart';

${_a(Anchors.providers)}
''';
  }
}

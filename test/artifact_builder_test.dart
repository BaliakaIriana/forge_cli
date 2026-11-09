import 'package:forge_cli/forge_cli.dart';
import 'package:forge_cli/src/core/file_store.dart';
import 'package:forge_cli/src/core/generation_plan.dart';
import 'package:forge_cli/src/core/project.dart';
import 'package:forge_cli/src/generators/artifact_builder.dart';
import 'package:forge_cli/src/generators/core_setup.dart';
import 'package:forge_cli/src/templates/template_context.dart';
import 'package:test/test.dart';

/// Builds a project in memory, runs [CoreSetup] (scaffold + anchors), and
/// returns a builder plus the plan to inspect.
(ArtifactBuilder, GenerationPlan) _setUp(StackConfig stack) {
  final store = MemoryFileStore({
    'pubspec.yaml': 'name: app\nenvironment:\n  sdk: ^3.8.0\n',
  });
  final config = ForgeConfig(
    stack: stack,
    layout: LayoutPreset.featureFirst.layout,
    core: CorePaths.defaults,
  );
  final ctx = TemplateContext(
    Project(store: store, packageName: 'app', config: config),
    config,
  );
  final plan = GenerationPlan(store);
  CoreSetup(ctx).apply(plan, scaffoldMissing: true);
  return (ArtifactBuilder(ctx), plan);
}

const _base = 'lib/src/features/orders';

void main() {
  group('feature (bloc + get_it + go_router)', () {
    final (builder, plan) = _setUp(const StackConfig());
    builder.feature(plan, Name('orders'));

    test('creates the vertical slice', () {
      expect(
        plan.changes.map((c) => c.path),
        containsAll([
          '$_base/domain/entities/order.dart',
          '$_base/domain/repositories/orders_repository.dart',
          '$_base/domain/usecases/get_orders_usecase.dart',
          '$_base/data/models/order_model.dart',
          '$_base/data/data_sources/orders_remote_data_source.dart',
          '$_base/data/repositories/orders_repository_impl.dart',
          '$_base/presentation/providers/orders/orders_bloc.dart',
          '$_base/presentation/providers/orders/orders_event.dart',
          '$_base/presentation/providers/orders/orders_state.dart',
          '$_base/presentation/screens/orders_screen.dart',
        ]),
      );
      expect(plan.notes, isEmpty);
      expect(plan.usesCodegen, isTrue);
    });

    test('registers every layer in get_it', () {
      final di = plan.read(CorePaths.defaults.di)!;
      expect(di, contains('registerLazySingleton<OrdersRemoteDataSource>'));
      expect(
          di,
          contains('registerLazySingleton<OrdersRepository>(\n'
              '    () => OrdersRepositoryImpl(getIt()),'));
      expect(di, contains('registerLazySingleton<GetOrdersUseCase>'));
      expect(di, contains('() => OrdersBloc(getOrders: getIt()),'));
      expect(di, contains("import 'package:app/src/features/orders/"));
    });

    test('adds the route and its path constant', () {
      expect(plan.read(CorePaths.defaults.routes!),
          contains("static const String orders = '/orders';"));
      expect(plan.read(CorePaths.defaults.router),
          contains('path: AppRoutes.orders,'));
    });

    test('the bloc loads the list through the use case', () {
      final bloc =
          plan.read('$_base/presentation/providers/orders/orders_bloc.dart')!;
      expect(bloc, contains('final result = await _getOrders();'));
      final state =
          plan.read('$_base/presentation/providers/orders/orders_state.dart')!;
      expect(state, contains('final List<Order>? data;'));
    });
  });

  test('a standalone use case adds the repository method and a stub', () {
    final (builder, plan) = _setUp(const StackConfig());
    builder
      ..feature(plan, Name('orders'))
      ..useCase(plan, Name('orders'), Name('get_order'), returnType: 'Order');
    expect(plan.read('$_base/domain/repositories/orders_repository.dart'),
        contains('FutureEither<Order> getOrder();'));
    expect(plan.read('$_base/data/repositories/orders_repository_impl.dart'),
        contains("throw UnimplementedError('getOrder');"));
  });

  test('riverpod stack writes a provider chain instead of get_it', () {
    final (builder, plan) = _setUp(const StackConfig(
      state: StateManagement.riverpod,
      di: DependencyInjection.riverpod,
      router: Routing.autoRoute,
    ));
    builder.feature(plan, Name('orders'));
    final deps =
        plan.read('$_base/presentation/providers/orders_dependencies.dart')!;
    expect(
        deps,
        contains('OrdersRepository ordersRepository(Ref ref) =>\n'
            '    OrdersRepositoryImpl(ref.watch(ordersRemoteDataSourceProvider));'));
    expect(deps, contains('ref.watch(dioProvider)'));
    expect(plan.read('$_base/presentation/providers/orders_controller.dart'),
        contains('ref.watch(getOrdersUseCaseProvider)()'));
    expect(plan.read(CorePaths.defaults.router),
        contains("AutoRoute(page: OrdersRoute.page, path: '/orders'),"));
    expect(plan.read('$_base/presentation/screens/orders_screen.dart'),
        contains('@RoutePage()'));
  });

  test('injectable stack annotates instead of wiring', () {
    final (builder, plan) = _setUp(const StackConfig(
      di: DependencyInjection.injectable,
    ));
    builder.feature(plan, Name('orders'));
    expect(plan.read('$_base/data/repositories/orders_repository_impl.dart'),
        contains('@LazySingleton(as: OrdersRepository)'));
    expect(plan.read('$_base/domain/usecases/get_orders_usecase.dart'),
        contains('show lazySingleton;'));
    expect(
        plan.read(CorePaths.defaults.di), isNot(contains('OrdersRepository')));
  });

  test('missing anchor turns wiring into a manual note', () {
    final store = MemoryFileStore({
      'pubspec.yaml': 'name: app\n',
      CorePaths.defaults.di: 'void configureDependencies() {}\n',
    });
    final config = ForgeConfig(
      stack: const StackConfig(),
      layout: LayoutPreset.featureFirst.layout,
      core: CorePaths.defaults,
    );
    final ctx = TemplateContext(
      Project(store: store, packageName: 'app', config: config),
      config,
    );
    final plan = GenerationPlan(store);
    ArtifactBuilder(ctx).repository(plan, Name('orders'));
    expect(
        plan.notes.single, contains('registerLazySingleton<OrdersRepository>'));
  });

  group('network: none', () {
    for (final di in [
      DependencyInjection.getIt,
      DependencyInjection.riverpod
    ]) {
      test('client-free data source, no Dio anywhere (${di.id})', () {
        final riverpod = di == DependencyInjection.riverpod;
        final (builder, plan) = _setUp(StackConfig(
          state: riverpod ? StateManagement.riverpod : StateManagement.bloc,
          di: di,
          network: Network.none,
        ));
        builder.feature(plan, Name('orders'));

        final ds = plan
            .read('$_base/data/data_sources/orders_remote_data_source.dart')!;
        expect(ds, contains('abstract interface class OrdersRemoteDataSource'));
        expect(ds, contains('const OrdersRemoteDataSourceImpl();'));
        expect(ds, contains("throw UnimplementedError('getOrders');"));
        for (final change in plan.changes) {
          expect(change.content, isNot(contains('Dio')), reason: change.path);
        }
        expect(plan.exists(CorePaths.defaults.dioProvider!), isFalse);

        if (riverpod) {
          expect(
            plan.read('$_base/presentation/providers/orders_dependencies.dart'),
            contains('const OrdersRemoteDataSourceImpl();'),
          );
        } else {
          expect(
            plan.read(CorePaths.defaults.di),
            contains('() => const OrdersRemoteDataSourceImpl(),'),
          );
        }
      });
    }
  });
}

# Wiring: DI and routes

[← Documentation](README.md)

forge never rewrites your existing files. It inserts code **above marker
comments** (anchors) and adds the imports it needs, so diffs stay small and
reviewable.

## Anchors

| File (`core:` key) | Anchor | Receives |
|---|---|---|
| `di` (get_it) | `// forge:di:data-sources` | `getIt.registerLazySingleton<XRemoteDataSource>(...)` |
| | `// forge:di:repositories` | `getIt.registerLazySingleton<XRepository>(() => XRepositoryImpl(getIt()))` |
| | `// forge:di:usecases` | `getIt.registerLazySingleton<XUseCase>(...)` |
| | `// forge:di:blocs` | `getIt.registerFactory<XBloc>(...)` |
| `router` | `// forge:routes` | `GoRoute(...)` or `AutoRoute(...)` |
| `routes` (go_router) | `// forge:route-paths` | `static const String orderDetail = '/orders/:id';` |
| `<feature>_dependencies.dart` (Riverpod DI) | `// forge:providers` | `@Riverpod(keepAlive: true)` providers |

`forge init` adds the anchors to existing files (inside
`configureDependencies()`, the top-level routes list, the `AppRoutes` class),
or creates the files with them.

Example DI file after two features (get_it):

```dart
void configureDependencies() {
  getIt.registerLazySingleton<Dio>(() => Dio());

  getIt.registerLazySingleton<OrdersRemoteDataSource>(
    () => OrdersRemoteDataSource(getIt()),
  );
  // forge:di:data-sources
  getIt.registerLazySingleton<OrdersRepository>(
    () => OrdersRepositoryImpl(getIt()),
  );
  // forge:di:repositories
  getIt.registerLazySingleton<GetOrdersUseCase>(
    () => GetOrdersUseCase(getIt()),
  );
  // forge:di:usecases
  getIt.registerFactory<OrdersBloc>(
    () => OrdersBloc(getOrders: getIt()),
  );
  // forge:di:blocs
}
```

Router (go_router):

```dart
routes: [
  GoRoute(
    path: AppRoutes.orders,
    name: 'orders',
    builder: (context, state) => const OrdersScreen(),
  ),
  // forge:routes
],
```

## Rules

- **Move an anchor** to change where code lands (e.g. inside a `ShellRoute`'s
  `routes:` to nest new screens there).
- **Missing anchor**: the file is left untouched and the snippet is printed as
  a note, ready to paste. Add the anchor back to get automatic wiring again.
- **Idempotent**: re-running a generator never duplicates a registration, a
  route, a path constant or an import.
- **Imports**: added in sorted position; an import already present (directly
  or through a barrel that provides `AppRoutes`) is not repeated.
- **injectable**: no anchor needed, registrations come from annotations and
  build_runner.
- **auto_route**: the route class name follows `replaceInRouteName` when your
  `AppRouter` uses it (`OrderDetailScreen` → `OrderDetailRoute`).

## Repository methods

`forge g usecase` also edits two files of the feature, without anchors: it
appends the method to the repository contract and an `UnimplementedError` stub
to the implementation, before the closing brace of the class, unless a method
with that name already exists.

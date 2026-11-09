# Stacks

[← Documentation](README.md)

The `stack:` section of `forge.yaml` picks the packages the generated code
targets. `forge init` pre-selects them from `pubspec.yaml`.

Whatever the stack, the generated code follows the same rules:

- Dependencies point inward: presentation → domain ← data.
- Repositories are registered against their interface and return
  `FutureEither<T>` through `runTask()`: no exception crosses the data layer.
- Use cases expose a single `call()`.
- State holders depend on use cases only, never on repositories or
  `BuildContext`.
- On Dart ≥ 3.12 (SDK lower bound of `pubspec.yaml`), constructors use private
  named parameters (`required this._getOrders`).

## `state`

| Option | Generated | Packages |
|---|---|---|
| `bloc` | `XBloc` + `XEvent` + `XState` (`part` files), status enum, one event per injected use case | `flutter_bloc` |
| `riverpod` | `@riverpod class XController` (async notifier) loading its data in `build()` | `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator` |

## `di`

| Option | How classes are registered | Packages |
|---|---|---|
| `get_it` | forge writes `getIt.register...` lines in the DI file, at the `// forge:di:*` anchors | `get_it` |
| `injectable` | Annotations on the classes (`@lazySingleton`, `@LazySingleton(as: Contract)`, `@injectable` for Blocs); build_runner writes the registrations | `get_it`, `injectable`, `injectable_generator` |
| `riverpod` | One `@Riverpod(keepAlive: true)` provider per class in `<feature>_dependencies.dart` (data source → repository → use cases) | Riverpod packages |

Repositories, data sources and use cases are lazy singletons; Blocs are
factories (a new instance per screen).

## `router`

| Option | Screen registration | Packages |
|---|---|---|
| `go_router` | `GoRoute(...)` in the router + a path constant in `AppRoutes` | `go_router` |
| `auto_route` | `@RoutePage()` on the screen + `AutoRoute(page: XRoute.page, path: ...)` in the router | `auto_route`, `auto_route_generator` |

## `network`

| Option | Data source | Packages |
|---|---|---|
| `retrofit` | `@RestApi()` abstract class, one annotated method per operation; it is its own implementation | `dio`, `retrofit`, `retrofit_generator` |
| `dio` | Interface + `XImpl(this._dio)` calling `Dio` by hand | `dio` |
| `none` | Interface + `const XImpl()` without client | none |

`init` picks `retrofit` when the pubspec declares it, else `dio` when it
declares Dio, else `none`.

### `network: none`

For apps whose data comes from something else than an HTTP client: Supabase,
Firebase, a local database, a platform channel... forge stays client-agnostic:
it generates the contract and an empty implementation, and DI does the rest.

```dart
abstract interface class OrdersRemoteDataSource {
  Future<List<OrderModel>> getOrders();
}

class OrdersRemoteDataSourceImpl implements OrdersRemoteDataSource {
  const OrdersRemoteDataSourceImpl();

  @override
  Future<List<OrderModel>> getOrders() {
    // TODO: implement with the client injected in the constructor.
    throw UnimplementedError('getOrders');
  }
}
```

No Dio anywhere: no import, no provider, no `NetworkModule`, and `runTask()`
only maps `SocketException` and generic errors to `Failure`s.

To use a client, add it as a constructor parameter, then make DI provide it.
Example with Supabase:

```dart
class OrdersRemoteDataSourceImpl implements OrdersRemoteDataSource {
  const OrdersRemoteDataSourceImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<List<OrderModel>> getOrders() async {
    final rows = await _client.from('orders').select();
    return rows.map(OrderModel.fromJson).toList();
  }
}
```

Then, depending on `di`:

- **get_it**: register the client once, and pass it in the generated line
  (drop the `const`).

  ```dart
  getIt.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);
  // forge:di:data-sources
  getIt.registerLazySingleton<OrdersRemoteDataSource>(
    () => OrdersRemoteDataSourceImpl(getIt()),
  );
  ```

- **injectable**: expose the client from a module; the constructor parameter is
  resolved by build_runner, nothing else to change.

  ```dart
  @module
  abstract class SupabaseModule {
    @lazySingleton
    SupabaseClient get client => Supabase.instance.client;
  }
  ```

- **riverpod**: declare a client provider and watch it in the generated provider
  of `<feature>_dependencies.dart` (drop the `const`).

  ```dart
  @Riverpod(keepAlive: true)
  SupabaseClient supabaseClient(Ref ref) => Supabase.instance.client;

  @Riverpod(keepAlive: true)
  OrdersRemoteDataSource ordersRemoteDataSource(Ref ref) =>
      OrdersRemoteDataSourceImpl(ref.watch(supabaseClientProvider));
  ```

Map client-specific exceptions (e.g. `PostgrestException`) to your own
`Failure`s in the `runTask()` file if needed.

## `data_class`

| Option | Entities | Models | Packages |
|---|---|---|---|
| `equatable` | `Equatable` with `props` | `@JsonSerializable()` + `fromJson` / `toJson` | `equatable`, `json_annotation`, `json_serializable` |
| `freezed` | `@freezed` | `@freezed` with `fromJson` | `freezed_annotation`, `freezed`, `json_serializable` |

## `functional`

`fpdart` or `dartz`: the `Either` used by `FutureEither<T>`, `runTask()` and
the generated imports.

## `json_field_case`

Key style of the JSON models, emitted as `fieldRename`: `none` (Dart names as
is), `snake`, `pascal`, `kebab`, `screaming_snake`. `init` detects it from
existing models.

# Configuration: `forge.yaml`

[← Documentation](README.md)

`forge init` writes `forge.yaml` at the project root. Every generator reads it.
Edit it freely; the next `forge g ...` uses the new values. Commit it.

```yaml
version: 1

stack:
  state: bloc            # bloc | riverpod
  di: get_it             # get_it | injectable | riverpod
  router: go_router      # go_router | auto_route
  network: retrofit      # retrofit | dio | none
  data_class: equatable  # equatable | freezed
  functional: fpdart     # fpdart | dartz
  json_field_case: snake # none | snake | pascal | kebab | screaming_snake

layout:
  entities: 'lib/src/features/{feature}/domain/entities'
  repositories: 'lib/src/features/{feature}/domain/repositories'
  usecases: 'lib/src/features/{feature}/domain/usecases'
  models: 'lib/src/features/{feature}/data/models'
  data_sources: 'lib/src/features/{feature}/data/data_sources'
  repositories_impl: 'lib/src/features/{feature}/data/repositories'
  state: 'lib/src/features/{feature}/presentation/providers'
  screens: 'lib/src/features/{feature}/presentation/screens'
  widgets: 'lib/src/features/{feature}/presentation/widgets'
  dependencies: 'lib/src/features/{feature}/presentation/providers'

core:
  typedefs: 'lib/src/utils/typedefs.dart'       # FutureEither<T>
  task_runner: 'lib/src/utils/task_runner.dart' # runTask()
  failure: 'lib/src/utils/failure.dart'         # Failure
  di: 'lib/src/di/injection.dart'               # getIt
  router: 'lib/src/routing/app_router.dart'
  routes: 'lib/src/routing/app_routes.dart'     # AppRoutes, go_router only
  dio_provider: 'lib/src/di/dio_provider.dart'  # Riverpod DI + Dio only

naming:
  screen_suffix: Screen
  usecase_suffix: UseCase
  data_source_suffix: RemoteDataSource
```

## `stack`

Which packages the generated code targets. Details and generated code per
option: [Stacks](stacks.md).

Valid combinations:

- `state: riverpod` requires `di: riverpod`.
- `di: riverpod` requires `state: riverpod`.
- `state: bloc` works with `di: get_it` or `di: injectable`.

An invalid combination stops every generator with
`Invalid forge.yaml: state: riverpod requires di: riverpod`.

Unknown or missing keys fall back to the defaults shown above.

## `layout`

Folder of each kind of file, relative to the project root. `{feature}` is
replaced by the snake_case feature name. Paths without `{feature}` are shared
by all features.

| Key | Contains |
|---|---|
| `entities` | Domain entities |
| `repositories` | Repository contracts (domain) |
| `usecases` | Use cases |
| `models` | JSON models / DTOs |
| `data_sources` | Remote data sources |
| `repositories_impl` | Repository implementations (data) |
| `state` | Blocs (one sub-folder per Bloc) or Riverpod controllers |
| `screens` | Screens / pages |
| `widgets` | Widgets |
| `dependencies` | Riverpod only: `<feature>_dependencies.dart`, the provider chain of the feature |

Presets offered by `forge init`:

| Preset | Shape |
|---|---|
| `feature_first` (default) | `lib/src/features/<feature>/{domain,data,presentation}/...` |
| `feature_first_flat` | `lib/src/<feature>/...`, with `datasources/` and `pages/` (screen suffix `Page`) |
| `layer_first` | `lib/src/domain/...`, `lib/src/application/...`, `lib/src/presentation/features/<feature>/...` (screen suffix `Page`) |

The existing features offered by the `--feature` prompt are the sub-folders of
the part of `screens` before `{feature}` (e.g. `lib/src/features`).

## `core`

Project files the generated code imports or edits. `init` finds them by
content (a file declaring `typedef FutureEither`, `runTask`, `class Failure`,
`getIt`, ...) or creates them.

| Key | Expected content |
|---|---|
| `typedefs` | `typedef FutureEither<T> = Future<Either<Failure, T>>;` |
| `task_runner` | `FutureEither<T> runTask<T>(Future<T> Function() action)` turning exceptions into `Failure`s |
| `failure` | `Failure` hierarchy |
| `di` | `getIt` and `configureDependencies()` (get_it / injectable) |
| `router` | `GoRouter` or `AppRouter` (auto_route) with the routes list |
| `routes` | `AppRoutes` path constants (go_router) |
| `dio_provider` | `dioProvider` (Riverpod DI with `network: retrofit` or `dio`) |

Pointing a key at your own file is fine as long as it exposes the same names.

## `naming`

| Key | Default | Example |
|---|---|---|
| `screen_suffix` | `Screen` | `OrderDetailScreen` / `OrderDetailPage` |
| `usecase_suffix` | `UseCase` | `GetOrdersUseCase` |
| `data_source_suffix` | `RemoteDataSource` | `OrdersRemoteDataSource` |

A suffix already present in a name is not repeated
(`forge g usecase get_orders_usecase` → `GetOrdersUseCase`, `forge g state orders_bloc` → `OrdersBloc`).

## Reconfiguring

```sh
forge init --force      # re-detects and rewrites forge.yaml
```

Or edit the file by hand. Already generated code is never migrated.

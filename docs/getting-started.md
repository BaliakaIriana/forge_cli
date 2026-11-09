# Getting started

[← Documentation](README.md)

## 1. Install

`forge_cli` is distributed from GitHub only. Add it as a dev dependency of your
Flutter app:

```yaml
dev_dependencies:
  forge_cli:
    git:
      url: https://github.com/BaliakaIriana/forge_cli.git
      ref: v0.2.0
```

```sh
flutter pub get          # or: fvm flutter pub get
```

Run it from any directory inside the project (forge looks for the nearest
`pubspec.yaml` upwards):

```sh
dart run forge_cli:forge --version
fvm dart run forge_cli:forge --version   # projects pinned with FVM
```

Optional, machine-wide install (then call `forge` directly):

```sh
dart pub global activate --source git https://github.com/BaliakaIriana/forge_cli.git
```

> The rest of the docs writes `forge ...` for brevity: read it as
> `dart run forge_cli:forge ...` when installed as a dev dependency.
> A shell alias helps: `alias forge="dart run forge_cli:forge"`.

## 2. Configure the project: `forge init`

```sh
forge init        # asks, with detected answers pre-selected
forge init -y     # accepts every detected answer, no prompt
forge init --dry-run
```

`init` runs once per project:

1. **Detects** the stack from `pubspec.yaml` (flutter_bloc vs riverpod, get_it /
   injectable, go_router / auto_route, retrofit / dio / neither, freezed,
   fpdart / dartz) and the JSON key case used by existing models.
2. **Asks** you to confirm each choice and the architecture layout preset.
3. **Writes** `forge.yaml` at the project root (see [Configuration](configuration.md)).
4. **Locates or scaffolds** the core files the generated code imports:
   `Failure`, `FutureEither<T>`, `runTask()`, DI file, router, `AppRoutes`.
5. **Adds anchors** (`// forge:...`) to the DI and router files
   (see [Wiring](wiring.md)).
6. **Lists missing packages** with the `flutter pub add` command to run.

Commit `forge.yaml`: it is shared by the whole team.

Any generator run on a project without `forge.yaml` starts `init` first
(interactive terminal only).

## 3. Generate a first feature

```sh
forge g feature orders --fields "id:String,reference:String,total:double,note:String?"
```

```
  create  lib/src/features/orders/domain/entities/order.dart
  create  lib/src/features/orders/data/models/order_model.dart
  create  lib/src/features/orders/data/data_sources/orders_remote_data_source.dart
  create  lib/src/features/orders/domain/repositories/orders_repository.dart
  create  lib/src/features/orders/data/repositories/orders_repository_impl.dart
  create  lib/src/features/orders/domain/usecases/get_orders_usecase.dart
  create  lib/src/features/orders/presentation/providers/orders/orders_bloc.dart
  create  lib/src/features/orders/presentation/providers/orders/orders_event.dart
  create  lib/src/features/orders/presentation/providers/orders/orders_state.dart
  create  lib/src/features/orders/presentation/screens/orders_screen.dart
  update  lib/src/di/injection.dart (register OrdersRemoteDataSource, ...)
  update  lib/src/routing/app_routes.dart (route path orders)
  update  lib/src/routing/app_router.dart (route /orders)
```

The entity name defaults to the singular of the feature (`orders` → `Order`);
override it with `--entity`.

Then run code generation (models, Retrofit, freezed, Riverpod, injectable and
auto_route need it):

```sh
dart run build_runner build --delete-conflicting-outputs
```

forge prints the exact command (with the `fvm` prefix when relevant) after
each generation that needs it.

## 4. Grow the feature

```sh
# A new use case: adds getOrder() to the repository contract + a stub in the impl
forge g usecase get_order -f orders --returns Order

# A detail screen with its own state holder, registered as a route
forge g state order_detail -f orders -u get_order
forge g screen order_detail -f orders --route /orders/:id

# A reusable widget
forge g widget order_card -f orders
```

Fill in the generated `TODO`s / `UnimplementedError`s: forge writes the
structure and the wiring, you write the business logic.

## 5. Preview before writing

Every generator accepts `--dry-run` (`-d`): it prints the plan (`create`,
`update`, `skip`) and the snippets it would insert, and writes nothing.

```sh
forge g feature invoices --dry-run
```

Existing files are never overwritten unless you pass `--force`.

## Interactive mode

Run `forge` alone for a menu, or `forge g` to pick a generator. Missing
arguments (name, feature, fields, return type...) are prompted for. In a
non-interactive shell (CI, scripts), missing arguments are errors instead.

Next: [Commands](commands.md).

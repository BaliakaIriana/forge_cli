# forge_cli

`ng generate` / `nest generate` for Flutter. `forge` scaffolds Clean Architecture
code — entities, models, data sources, repositories, use cases, Blocs or Riverpod
notifiers, screens, widgets — following your project's layout, and wires it into
dependency injection and routing.

```
$ forge g feature orders --fields "id:String,reference:String,total:double,note:String?"
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

## Documentation

Full how-to guide in [`docs/`](docs/README.md):
[getting started](docs/getting-started.md) ·
[commands](docs/commands.md) ·
[configuration](docs/configuration.md) ·
[stacks](docs/stacks.md) ·
[wiring](docs/wiring.md) ·
[localization](docs/localization.md) ·
[troubleshooting](docs/troubleshooting.md).

## Install

Add it as a dev dependency of your Flutter app, from Git:

```yaml
dev_dependencies:
  forge_cli:
    git:
      url: https://github.com/BaliakaIriana/forge_cli.git
      ref: v0.2.0
```

Then run it from anywhere inside the project:

```sh
dart run forge_cli:forge <command>      # or: fvm dart run forge_cli:forge
```

Shorter, machine-wide: `dart pub global activate --source git https://github.com/BaliakaIriana/forge_cli.git`, then `forge <command>`.

## Commands

| Command | What it does |
|---|---|
| `forge` | Interactive menu. |
| `forge init` | Detects your stack, asks to confirm each choice, writes `forge.yaml`, scaffolds the missing core files, adds anchors. `-y` accepts the detected defaults. |
| `forge g feature <name>` | Whole vertical slice (like `nest g resource`), wired into DI and routing. `--entity`, `--fields`, `--no-screen`. |
| `forge g entity <name> -f <feature>` | Domain entity. `--fields`. |
| `forge g model <name> -f <feature>` | JSON DTO with `toEntity()` when the entity exists. `--fields`. |
| `forge g data-source <name> -f <feature>` | Retrofit client (or Dio data source), registered in DI. |
| `forge g repository <feature>` | Repository contract (domain) + implementation (data), registered in DI. |
| `forge g usecase <name> -f <feature>` | Use case; adds the method to the repository contract and a stub to its implementation when missing. `--returns "List<Order>"`. |
| `forge g state <name> -f <feature>` | Bloc (bloc/event/state with `part`) or Riverpod notifier. `-u get_orders,delete_order` injects use cases: the first loads the state, each other gets its own event. Aliases: `bloc`, `provider`, `notifier`. |
| `forge g screen <name> -f <feature>` | Screen providing its state holder, registered as a route. `--route /orders/:id`, `--no-route`, `--state <name>`. |
| `forge g widget <name> -f <feature>` | Widget. `--stateful`. |
| `forge g l10n-key <key> [text]` | Translation key added to every ARB file of `l10n.yaml`'s `arb-dir`, with `@key` placeholders metadata deduced from the template text (`{name}`, `{count, plural, ...}`). `-t fr="..." -t en="..."`, `--description`. Missing locales get the template text and a warning. No `forge.yaml` needed. |

Every generator accepts `--dry-run` (`-d`, shows the plan, writes nothing) and
`--force` (overwrite existing files). Missing arguments are prompted for in a
terminal; `forge g` alone lets you pick the generator. Without a `forge.yaml`,
any generator runs `forge init` first.

Aliases: `g` = `generate`, `f`/`resource` = `feature`, `e`, `dto`, `ds`, `repo`/`r`, `uc`, `s`, `page`/`sc`, `w`, `l10n`/`i18n`/`tr`.

## Supported stacks

Chosen at `forge init` (pre-selected from `pubspec.yaml`), stored in `forge.yaml`:

| Concern | Options |
|---|---|
| State | `bloc` (flutter_bloc), `riverpod` (riverpod_generator) |
| DI | `get_it` (registrations written in the DI file), `injectable` (annotations), `riverpod` (provider chain per feature) |
| Routing | `go_router` (+ `AppRoutes` path constants), `auto_route` (`@RoutePage`) |
| Network | `retrofit` (`@RestApi`), `dio` (interface + Dio implementation), `none` (interface + implementation without client: inject your own, e.g. Supabase) |
| Data classes | `equatable` + `json_serializable`, `freezed` |
| Either | `fpdart`, `dartz` |
| JSON keys | `none`, `snake`, `pascal`, `kebab`, `screaming_snake` (`fieldRename`) |

Generated code follows the same rules everywhere: dependencies point inward
(presentation → domain ← data), repositories return `FutureEither<T>` through
`runTask`, use cases expose a single `call()`, Blocs depend on use cases only and
never on `BuildContext`, repositories are registered against their interface.
On Dart ≥ 3.12 projects, Bloc constructors use private named parameters
(`required this._getOrders`).

## Architecture layouts

Presets offered by `forge init`, then fully editable in `forge.yaml`
(`{feature}` is the snake_case feature name):

- `feature_first` — `lib/src/features/<feature>/{domain,data,presentation}` (default)
- `feature_first_flat` — `lib/src/<feature>/...`, `datasources/`, `pages/`
- `layer_first` — `lib/src/{domain,application,presentation}/...`

## Anchors

`forge` edits existing files only above marker comments, so diffs stay small and
reviewable. `forge init` adds them (or creates the files when missing):

| File (`core:` in forge.yaml) | Anchors |
|---|---|
| `di` (get_it) | `// forge:di:data-sources`, `// forge:di:repositories`, `// forge:di:usecases`, `// forge:di:blocs` — inside `configureDependencies()` |
| `router` | `// forge:routes` — inside the top-level routes list |
| `routes` (go_router) | `// forge:route-paths` — inside `AppRoutes` |
| `<feature>_dependencies.dart` (Riverpod) | `// forge:providers` |

Move an anchor to change where code lands. When an anchor is missing, the
snippet is printed for you to paste instead. Wiring is idempotent: re-running a
generator never duplicates a registration or a route.

## Core files

Generated code imports a few project files, located by `forge init`
(`core:` in `forge.yaml`) or scaffolded on request: `Failure` hierarchy,
`FutureEither<T>` typedef, `runTask()`, DI file (`getIt`), router, `AppRoutes`,
and `dioProvider` with Riverpod DI and a Dio-based network.

## After generating

Models, Retrofit clients, freezed classes, Riverpod providers, injectable and
auto_route need code generation:

```sh
dart run build_runner build --delete-conflicting-outputs
```

Exclude generated files from analysis (`analyzer: exclude: ["**/*.g.dart",
"**/*.freezed.dart", "**/*.gr.dart", "**/*.config.dart"]`): an empty Retrofit
client otherwise yields an `unused_field` warning in its `.g.dart`.

## Development

```sh
dart pub get
dart analyze
dart test
dart run bin/forge.dart --help
```

Code map: `lib/src/cli` (commands, prompts, plan execution),
`lib/src/config` (`forge.yaml`, stack and layout, detection),
`lib/src/core` (names, artifact paths, file store, generation plan, source
editor), `lib/src/templates` (one class per layer), `lib/src/wiring` (DI and
routing strategies), `lib/src/generators` (artifact builder, core setup).

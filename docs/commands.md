# Commands

[← Documentation](README.md)

```
forge                          interactive menu
forge init [-y] [--force] [--dry-run]
forge generate <generator> <name> [options]     (alias: forge g)
forge help <command>           usage of any command
forge --version
```

## Common options

Every generator accepts:

| Option | Effect |
|---|---|
| `-f, --feature <feature>` | Feature the artifact belongs to (snake_case). Prompted (with the list of existing features) when omitted in a terminal. Not used by `feature`, `repository` and `l10n-key`. |
| `-d, --dry-run` | Prints the plan and the snippets, writes nothing. |
| `--force` | Overwrites files that already exist (otherwise they are skipped). |
| `-h, --help` | Usage of the generator. |

Names are accepted in any case: `order_detail`, `order-detail`, `OrderDetail`
and `orderDetail` all produce `OrderDetail...` classes in `order_detail...` files.

### Fields

`--fields` takes comma-separated `name:Type` pairs. A `?` makes the field
nullable. Default: `id:String`.

```sh
--fields "id:String,reference:String,total:double,note:String?,items:List<String>"
```

The output prefix reads: `create` (new file), `update` (existing file edited at
an anchor), `skip` (file exists, use `--force`). Notes (yellow) list snippets to
paste by hand when an anchor is missing.

---

## `forge g feature <name>`

Aliases: `f`, `resource`. Like `nest g resource`: a whole vertical slice.

| Option | Default | |
|---|---|---|
| `-e, --entity <Name>` | singular of the feature | Entity name. |
| `--fields <fields>` | `id:String` | Entity / model fields. |
| `--[no-]screen` | on | Generate the screen and its route. |

Generates entity, model, data source, repository (contract + implementation),
`get<Feature>` use case (returns `List<Entity>`), the state holder, the screen,
then registers everything in DI and the screen in the router.

```sh
forge g feature orders --fields "id:String,total:double"
forge g feature people --entity Person --no-screen
```

## `forge g entity <Name> -f <feature>`

Alias: `e`. Immutable domain entity with value equality (`Equatable` or
`@freezed`, per `stack.data_class`).

```sh
forge g entity order_line -f orders --fields "id:String,quantity:int,price:double"
```

## `forge g model <Name> -f <feature>`

Alias: `dto`. JSON model (`@JsonSerializable` or freezed) with
`fromJson`/`toJson`, and `toEntity()` when the matching entity exists. A
`Model` suffix in the name is ignored (`order_model` → `OrderModel`). Keys
follow `stack.json_field_case`.

```sh
forge g model order -f orders --fields "id:String,total:double"
```

## `forge g data-source <name> -f <feature>`

Aliases: `ds`, `datasource`. Remote data source named `<Name>RemoteDataSource`
(suffix configurable), registered in DI. Its shape depends on `stack.network`:

| `network` | Generated |
|---|---|
| `retrofit` | `@RestApi()` abstract class with a `factory ... = _X;` |
| `dio` | Interface + `XImpl` taking `Dio` |
| `none` | Interface + `const XImpl()` without client: inject yours (see [Stacks](stacks.md#network-none)) |

```sh
forge g ds order_payments -f orders
```

## `forge g repository <feature>`

Aliases: `repo`, `r`. Named after the feature: `OrdersRepository` contract
(domain) and `OrdersRepositoryImpl` (data) depending on the feature data
source, registered against the contract in DI.

```sh
forge g repository orders
```

## `forge g usecase <name> -f <feature>`

Aliases: `uc`, `use-case`. Use case with a single `call()`, depending on the
feature repository, registered in DI.

| Option | Default | |
|---|---|---|
| `--returns <T>` | `void` | `T` of `FutureEither<T>`. |

When the repository contract lacks the method, forge adds it to the contract
and an `UnimplementedError` stub to the implementation.

```sh
forge g usecase get_order -f orders --returns Order
forge g usecase delete_order -f orders
```

```dart
class GetOrderUseCase {
  const GetOrderUseCase(this._repository);

  final OrdersRepository _repository;

  FutureEither<Order> call() => _repository.getOrder();
}
```

## `forge g state <name> -f <feature>`

Aliases: `bloc`, `provider`, `notifier`, `controller`, `s`. State holder of the
configured stack:

- **bloc**: `<name>_bloc.dart` + `_event.dart` + `_state.dart` (`part` files)
  in `<state>/<name>/`, status enum (`initial/loading/success/failure`),
  registered as a DI factory.
- **riverpod**: `<name>_controller.dart`, an `@riverpod` `AsyncNotifier`.

| Option | |
|---|---|
| `-u, --usecases <a,b>` | Use cases of the feature to inject. The first one loads the state (`<Name>Requested` event / `build()`); every other one gets its own event / method. |

```sh
forge g state orders -f orders -u get_orders,delete_order
```

Blocs depend on use cases only, never on `BuildContext` or repositories.

## `forge g screen <name> -f <feature>`

Aliases: `page`, `sc`. Screen providing its state holder (`BlocProvider` with
`getIt`, or watching the Riverpod controller) and rendering its loading /
failure / success states, registered as a route.

| Option | Default | |
|---|---|---|
| `--route <path>` | `/<name-in-kebab-case>` | Route path, path parameters allowed (`/orders/:id`). |
| `--no-route` | | Do not touch the router. |
| `--state <name>` | the state with the same name, if any | State holder to provide / watch. |

```sh
forge g screen order_detail -f orders --route /orders/:id
forge g screen orders_filters -f orders --no-route --state orders
```

The screen suffix (`Screen`, or `Page` for some layouts) is set in
`naming.screen_suffix`.

## `forge g widget <name> -f <feature>`

Alias: `w`. Widget in the feature `widgets` folder.

| Option | |
|---|---|
| `--stateful` | `StatefulWidget` instead of `StatelessWidget`. |

```sh
forge g widget order_card -f orders
```

## `forge g l10n-key <key> [template text]`

Aliases: `l10n`, `i18n`, `tr`. Adds a translation key to every ARB file.
Works without `forge.yaml`. See [Localization](localization.md).

```sh
forge g l10n-key orders_count "{count, plural, =0{No order} one{1 order} other{{count} orders}}" \
  -t fr="{count, plural, =0{Aucune commande} one{1 commande} other{{count} commandes}}"
```

## `forge init`

| Option | |
|---|---|
| `-y, --yes` | Accept the detected defaults without asking. |
| `--force` | Overwrite an existing `forge.yaml`. |
| `--dry-run` | Show what would be written. |

See [Getting started](getting-started.md#2-configure-the-project-forge-init).

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Success (also after a dry run). |
| `64` | Usage error: missing name / feature, no `pubspec.yaml` found. |
| `78` | Configuration error: no `forge.yaml` in a non-interactive shell, invalid stack combination. |

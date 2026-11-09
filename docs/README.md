# forge_cli documentation

How to use `forge`, the Clean Architecture code generator for Flutter apps.

| Guide | Read it to… |
|---|---|
| [Getting started](getting-started.md) | Install forge, run `forge init`, generate a first feature. |
| [Commands](commands.md) | Every generator, its arguments, options and output. |
| [Configuration](configuration.md) | Understand and edit `forge.yaml` (stack, layout, core files, naming). |
| [Stacks](stacks.md) | What each stack option generates, including `network: none`. |
| [Wiring](wiring.md) | How forge edits DI and router files through anchors. |
| [Localization](localization.md) | Add translation keys to ARB files with `forge g l10n-key`. |
| [Troubleshooting](troubleshooting.md) | Common errors, analyzer warnings and FAQ. |

Quick reference:

```sh
dart run forge_cli:forge init                         # configure the project once
dart run forge_cli:forge g feature orders \
  --fields "id:String,reference:String,total:double"  # whole vertical slice
dart run forge_cli:forge g usecase delete_order -f orders --returns void
dart run forge_cli:forge g screen order_detail -f orders --route /orders/:id
dart run build_runner build --delete-conflicting-outputs
```

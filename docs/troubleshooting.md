# Troubleshooting

[← Documentation](README.md)

## `No pubspec.yaml found in this directory or its parents.`

Run forge from inside the Flutter project.

## `No forge.yaml: run forge init first.`

Generators start `forge init` automatically in a terminal only. In a script or
CI, run `forge init -y` once and commit `forge.yaml`.

## `Missing --feature.` / `Missing <name>.`

Non-interactive shells cannot prompt: pass every argument.

```sh
forge g usecase get_order --feature orders --returns Order
```

## `Invalid forge.yaml: state: riverpod requires di: riverpod`

Riverpod state holders read their use cases from Riverpod providers, Blocs from
get_it. Fix the `stack:` section ([valid combinations](configuration.md#stack)).

## A file was not wired / a note says "add this snippet"

The anchor is missing in the file named by the note (it was deleted or never
added). Paste the printed snippet, or put the anchor back (see
[Wiring](wiring.md#anchors)) and re-run the same generator without `--force`:
existing files are skipped, the missing wiring is applied, and nothing is
duplicated.

## `skip ... (exists, use --force to overwrite)`

forge never overwrites existing files by default. `--force` regenerates them:
your edits in those files are lost, run `--dry-run` first.

## Errors after generating: `Undefined name '_$OrderModelFromJson'`, missing `.g.dart` / `.freezed.dart`

Run code generation:

```sh
dart run build_runner build --delete-conflicting-outputs
```

## `unused_field` warning in a `.g.dart` file

A Retrofit client without any method yet. Exclude generated files from analysis
in `analysis_options.yaml`:

```yaml
analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "**/*.gr.dart"
    - "**/*.config.dart"
```

## Missing packages (`Target of URI doesn't exist`)

`forge init` prints the `flutter pub add ...` commands for the packages the
configured stack needs. Run them, or re-run `forge init --dry-run` to see the
list again.

## FVM projects

When the project has `.fvmrc` / `.fvm/`, forge prints `fvm flutter ...` /
`fvm dart ...` commands. Run forge itself with `fvm dart run forge_cli:forge`.

## Upgrading forge

Change the `ref:` of the git dependency, then `flutter pub upgrade forge_cli`.
Already generated code is not changed; new code follows the new version. See
the [changelog](../CHANGELOG.md).

## FAQ

**Can I use forge on an existing project?** Yes: `init` detects the stack, the
core files and the JSON case, and only adds anchors to existing files.

**Does it generate tests?** No.

**Does it run build_runner for me?** No, it prints the command.

**Can I change the folder structure?** Yes, edit `layout:` in `forge.yaml`
([Configuration](configuration.md#layout)).

# Localization: `forge g l10n-key`

[← Documentation](README.md)

Adds one translation key to every ARB file of a Flutter `gen-l10n` setup. Does
not need `forge.yaml`.

```sh
forge g l10n-key <key> [template text] [-t <locale>=<text> ...] [--description <text>]
```

Aliases: `l10n`, `i18n`, `tr`.

## Where it writes

Read from `l10n.yaml`, with Flutter's defaults when absent:

| Setting | Default |
|---|---|
| `arb-dir` | `lib/l10n` |
| `template-arb-file` | `app_en.arb` |
| `output-class` | `AppLocalizations` |

Every `*.arb` file of `arb-dir` gets the key; the locale comes from `@@locale`
or the file name (`app_fr.arb` → `fr`). Existing formatting and key order are
kept: the entry is appended at the end.

## Examples

```sh
# Template text as 2nd argument, other locales with -t
forge g l10n-key orders_empty_title "No orders yet" -t fr="Aucune commande"

# Placeholders: {name} becomes a String placeholder in @key
forge g l10n-key welcome_user -t en="Welcome {name}" -t fr="Bienvenue {name}"

# Plural: count becomes a num placeholder
forge g l10n-key orders_count \
  "{count, plural, =0{No order} one{1 order} other{{count} orders}}" \
  -t fr="{count, plural, =0{Aucune commande} one{1 commande} other{{count} commandes}}" \
  --description "Number of orders in the list header"
```

Result in the template file:

```json
  "ordersCount": "{count, plural, =0{No order} one{1 order} other{{count} orders}}",
  "@ordersCount": {
    "description": "Number of orders in the list header",
    "placeholders": {
      "count": {
        "type": "num"
      }
    }
  }
```

The key is converted to camelCase (`orders_count` → `ordersCount`). `@key`
metadata is written in the template file only.

## Behavior

- The template-locale text is required (2nd argument or `-t <template>=...`).
  In a terminal, every missing locale is prompted for.
- A locale without text receives the template text and a warning:
  translate it later.
- Placeholders differing from the template's in a locale are reported.
- An existing key is skipped; `--force` replaces its text (and metadata).
- Only top-level placeholders are detected: `{name}`, `{count, plural, ...}`
  (`num`), `{gender, select, ...}` (`String`). Edit `@key` by hand for typed
  placeholders (`DateTime`, `int` with `format`...).

Then regenerate and use it:

```sh
flutter gen-l10n
```

```dart
AppLocalizations.of(context)!.ordersCount(orders.length)
```

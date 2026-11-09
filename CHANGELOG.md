# Changelog

## 0.2.0

- `network: none`: client-free data sources. The data source is an
  interface plus an implementation without dependency, registered in DI
  (const constructor); inject the client you need (Supabase, Firebase, local
  database...) through its constructor. No Dio import, provider or package
  is generated or required. `forge init` selects it when the project
  declares neither `dio` nor `retrofit`.
- `runTask` and the DI scaffolds only reference Dio when the network uses it.
- Dependency-free registrations are `const`; Riverpod providers are
  separated by a blank line; the router no longer re-imports `AppRoutes`
  when it is already in scope (e.g. through a barrel).

## 0.1.0

- `forge g l10n-key`: adds a key to every ARB file, placeholders metadata
  deduced from the template message; text-level edits keep the ARB layout.
- `forge init`: stack and layout detection, `forge.yaml`, core file scaffolding, anchors.
- Generators: feature, entity, model, data-source, repository, usecase, state, screen, widget.
- Stacks: bloc / riverpod, get_it / injectable / riverpod, go_router / auto_route,
  retrofit / dio, equatable / freezed, fpdart / dartz.
- Interactive mode, `--dry-run`, `--force`.

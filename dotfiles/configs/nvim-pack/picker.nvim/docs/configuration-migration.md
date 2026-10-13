# Configuration migration

The public API now requires explicit `picker.setup()`. Neovim integration and
standalone demos/tests use that entry point.

## Ownership

- `picker/config.lua` owns private defaults, configured preferences, merge rules,
  validation and copied invocation settings.
- Search options resolve once before backend allocation. Panel owns a snapshot;
  Input, List, Restore, Preview, Window and Bindings consume resolved values.
- Presentation builds formatters from complete declarations, without default
  lookup. Resume saves declarations and effective settings, not generated
  formatters or `on_instance` hooks.
- Select resolves before allocating its window. Its config module retains view
  validation and a test-facing resolver, but owns no defaults.
- Status-column placement, list inset, native pane declarations and minimum
  screen budgets are structural constants, not independently mutable options.
- Direct source-injected Panel construction remains an internal test boundary
  that accepts partial invocation options; public construction passes resolved
  settings and does not resolve twice.

## Verification

Contract tests cover setup requirements, nested overrides, nonempty list
replacement, false-valued mappings, callback identity, copied tables, setup reset,
atomic rejection, layout normalization, mode titles and Git marker validation.
Search regression tests cover setup/invocation mappings and resume isolation,
including a counter proving one public resolution and no re-resolution on resume.

The old nested Picker configuration module and preview defaults module are
removed. Runtime leaf components do not import default tables.

Automated checks do not prove terminal rendering, mouse behavior or real fff
backend interaction. Those still require interactive acceptance. No commit has
been created as part of this migration.

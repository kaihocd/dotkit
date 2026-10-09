# Agent notes

Read `README.md` and `CONTRIBUTING.md` for setup, package ownership and checks.

- Preserve unrelated working-tree changes; read current files before editing.
- Use existing `@dotkit/task` presets and package scripts for engineering tasks.
- `pnpm check` is static verification; `pnpm test` runs package tests.
- Never run `pnpm slink` without authorization: it changes home-directory links
  and reloads a macOS LaunchAgent. Use `--only-preview` for inspection.
- Do not refresh existing Palette scheme input implicitly or change its pinned
  upstream revision as part of an unrelated task.
- Do not run repository-wide formatting to hide unrelated check failures.
- Keep temporary instrumentation out of committed sources and report which
  checks actually ran, including failures and untested interactive behavior.

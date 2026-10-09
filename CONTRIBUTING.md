# Development

## Verification

Use `pnpm check` and `pnpm test` as separate gates. Every workspace package owns
its check/test scripts; the root aggregates them through `@dotkit/task`. Root
checks also cover repository tooling and documentation. Do not add a second task
runner or duplicate package-specific commands at the root.

`pnpm fix` changes files. Review its diff and run `pnpm check` afterwards. Do not
bulk-format unrelated work just to make a feature diff pass.

GitHub Actions runs build, check and tests on macOS, without installing links or
reloading user services. Native tool versions follow Homebrew; JavaScript
dependencies use the committed pnpm lockfile. A passing local run is not a claim
that a clean-checkout CI run passed.

Some standalone Neovim tests require installed third-party plugins and are not
part of the isolated default suite. Consult the relevant plugin test README;
headless tests do not prove terminal rendering or real mouse interaction.

## Boundaries

- Packages own their domain logic, dependencies, generated artifacts and tests.
- Build writes repository artifacts; `slink` is the explicit user-environment
  mutation boundary. Keep its preview mode free of side effects.
- Palette is the authoritative theme source. Consumers use the applied palette
  rather than creating their own theme mappings or rereading files on every draw.
- Keep Task execution state independent of its renderer.
- Prefer small changes to existing interfaces over new generic frameworks.

## External inputs

Palette's `ensure` is idempotent for valid existing input. It acquires only a
missing collection and validates before publishing it. Invalid input must fail
visibly, not trigger an automatic destructive refresh. Tests must not require a
network download or modify the developer's real theme state.

## Changes and commits

Keep a coherent change per commit; inspect both staged and unstaged diffs.
Never stage the whole repository merely to include one fix. Do not commit local
logs, downloaded scheme collections, dependencies or build output.

Use descriptive messages such as `fix(palette): apply theme before UI startup`.
Commit hooks and message enforcement are not installed yet; CI is the shared
verification gate.

# Dotkit

Personal macOS development-environment workspace: dotfiles, a shared color
palette, login environment profiles, and development tooling. This is not a
published package or a cross-platform installer.

## Requirements

- macOS, Git, and `tar`.
- Node.js **24.2 or newer** and **pnpm 10.29.3** (see `package.json`).
- Neovim **0.12+** for the configuration and Neovim tests.
- `lua-language-server` for Lua checks. Set `VIMRUNTIME` to Neovim's runtime
  directory if it is not already available in your shell.
- macOS `/bin/zsh` and `/usr/bin/expect` for shell/terminal tests.

For example, Homebrew can install `node@24`, `neovim`, and
`lua-language-server`. JavaScript tools, including StyLua, come from pnpm.

## First checkout

```sh
pnpm install --frozen-lockfile
pnpm build
pnpm check
pnpm test
```

`build` first runs `ensure`: Palette downloads its Base16 input from the fixed
upstream commit in `packages/palette/settings.ts` if the local collection is
missing. Existing collections are validated, not replaced. The initial download
requires network access; subsequent builds can reuse valid local input offline.
The YAML collection and generated output are ignored by Git.

An existing collection is not checked byte-for-byte against upstream. To use a
new revision, review the revision change and explicitly move the old collection
aside before running `ensure`; do not silently overwrite local edits.

## Commands

| Command                     | Responsibility                                               |
| --------------------------- | ------------------------------------------------------------ |
| `pnpm ensure`               | Prepare missing external build inputs                        |
| `pnpm build`                | Ensure inputs, then build package artifacts                  |
| `pnpm check`                | Root and package type, lint, and formatting checks; no fixes |
| `pnpm test`                 | Run workspace package test suites                            |
| `pnpm fix`                  | Apply lint/format fixes; run `check` afterwards              |
| `pnpm slink --only-preview` | Inspect package link plans without installing                |
| `pnpm slink`                | Install links and reload the Profiles LaunchAgent            |

**Installation is explicit.** Build/check/test must not install into your home
directory. Review `profiles/profiles.config.ts` and the package slink configuration
before running `slink`. Existing conflicting targets should be resolved manually;
installation is not a workspace-wide transaction and may partially complete.
CI never runs `slink`.

Package operations stay package-local, for example:

```sh
pnpm --filter @dotkit/palette ensure
pnpm --filter @dotkit/task test
```

## Workspace

| Path                | Owns                                                                |
| ------------------- | ------------------------------------------------------------------- |
| `dotfiles/`         | Neovim, local Lua plugins, shell, terminal and prompt configuration |
| `profiles/`         | XDG/login environment and macOS LaunchAgent generation              |
| `packages/palette/` | Theme catalog, CLI and active-theme state                           |
| `packages/shared/`  | Shared environment, linking, output and script infrastructure       |
| `packages/task/`    | Workspace task execution and terminal presentation                  |

See [development guidelines](CONTRIBUTING.md) and
[Task architecture](packages/task/README.md).

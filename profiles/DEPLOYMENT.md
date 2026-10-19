# Deployment review checkpoint

## Boundaries

- `scripts/deploy.ts`: scans available platforms, prompts for a selection, and runs deployment by default; `--preview` selects the read-only path.
- `src/deployment/`: environment resolution, read-only inspection, execution order and results.
- `platforms/<name>/install.ts`: platform configuration and callback wiring.
- `platforms/macos/launch-agent.ts`: owns XDG files, launchctl and verification.
- `src/package-managers/homebrew.ts`: native Homebrew declaration and probe.

Execution API order: authorization → software/link preflight → requirement checks →
read-only preInstall validation → preInstall execution → install/build/links →
postInstall only on success. Independent software entries may continue after another
entry fails. Completed work is not rolled back.

Callbacks are trusted platform code, not sandboxed. `onlyPreview: true` prohibits
writes and service/session changes. Preview does not invoke postInstall. The CLI
defaults to execution; pass `--preview` for inspection. Selecting a platform in execution
mode authorizes its declared writes, network and elevated actions; no implicit sudo is
added. Failed or unfinished execution reports `failed` and sets a nonzero exit code.
Preview reports diagnostics without claiming deployment success.

## Fresh macOS deployment policy

There is no legacy-layout migration feature. Preserve user data; remove only
explicitly identified deployment outputs at cutover, after replacement is ready.
Do not recursively remove XDG directories.

Read-only inspection found the old LaunchAgent link points to
`profiles/dist/dev.qihao.xdg.plist`; that plist invokes
`profiles/dist/set-xdg-environment.sh`. New preparation writes a managed helper at
`$XDG_CONFIG_HOME/environment/xdg.sh` and a regular plist in
`~/Library/LaunchAgents/dev.qihao.xdg.plist`. On the current host, the old link was
backed up and explicitly replaced during live acceptance. On other hosts an existing
symlink remains a blocker; it is not followed or overwritten automatically.

Existing configuration links for Zsh, Neovim, WezTerm, Palette and its completion
point into this repository. Correct links can be kept; deleting them provides no
benefit. An additional `~/.local/bin/prism` link points at `tools/prism/dist/prism.js`;
it is outside the current software declaration and must not be deleted implicitly.

Keep history, caches, plugin installations, Neovim state, Palette state and local
configuration overrides. Zsh uses `$XDG_STATE_HOME/zsh/history`; also preserve
`~/.zsh_history`. Both were backed up before this checkpoint. Refresh the backup
at cutover after active shells have flushed their history; never print history
contents into deployment logs.

## Safe review commands

The isolated tests passed before removal; their sources are preserved in commit
`86ffdaf`. There is currently no Profiles test script. `pnpm check` performs static
verification only.

```sh
pnpm check
printf '1\n' | HOMEBREW_BREW_FILE=/nonexistent/brew pnpm dotkit --preview
```

The final command intentionally reports Homebrew blockers, without invoking real
Homebrew. Platform numbers follow the scanned list; inspect it before selecting.
On the accepted host the managed LaunchAgent passes preInstall inspection.

## Source audit findings

- Zsh loads NVM from `$HOMEBREW_PREFIX/opt/nvm/nvm.sh` and Zinit from
  `$HOMEBREW_PREFIX/opt/zinit/zinit.zsh`. Both paths exist on the inspected host;
  this is not proof of package availability on a clean machine.
- NVM uses `~/.nvm/current/bin`; installing the NVM formula does not install or
  select a Node version. Preserve the existing NVM directory.
- Zinit loads three remote plugins at shell startup. Deployment does not synchronize
  those plugins; opening a fresh shell may trigger separate network activity.
- Neovim resolves its configuration symlink and locates `nvim-pack` beside the
  repository configuration directory. Keeping the config symlink preserves that
  path; copying only the nvim directory would not.
- Palette builds target Node 24 and invoke the current Node executable for a smoke
  check. Its runtime requires Node on PATH. Deploy does not yet establish that
  runtime through NVM. Node satisfying the repository engine requirement and installed
  workspace dependencies are deployment prerequisites, not automatically provisioned
  software. No default NVM version or Node installation source is selected implicitly.
- Existing Palette scheme input remains pinned and is not implicitly refreshed.

## Not yet validated

- Logout/login persistence and ordering relative to other GUI applications. Live
  launchctl publication, verification and repeated loading passed on the current host.
- Full macOS package/prerequisite audit. Builds now run whenever declared; existing
  link sources are not proof of freshness. No incremental-build detection is promised.
- Build callbacks receive the resolved execution context. Palette invokes its package-owned
  ensure/build entrypoints in child processes with explicit HOME/XDG and the current Node
  executable. End-to-end Palette building under custom HOME/XDG has not yet been run.
- Clean-machine deployment. The current host passed live installation/build/link
  execution through the internal executor; the CLI now exposes it by default.
  Existing WezTerm nightly was preserved by declaring `wezterm@nightly`.
- Crash recovery across multiple file writes or service reload failure; no global rollback.
- Concurrent filesystem replacement can race checks; do not deploy while other tools
  modify these paths.

Do not remove correct configuration links merely to obtain a clean preview.
Live acceptance records and recovery steps are in `platforms/macos/ACCEPTANCE.md`.
The prior full-deployment backup is at
`~/.local/state/dotkit/backups/full-deploy-20261018-165342/`.

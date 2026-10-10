# terminal.nvim

Local multi-session terminal manager migrated from nvim-006. Requires Neovim
0.12 and the workspace's `popup.nvim`; no third-party terminal dependency.

```lua
require('terminal').setup({
  border = 'solid',
  width_ratio = 0.75,
  height_ratio = 0.65,
  list_width = 20,
  auto_insert = true,
})
require('terminal').toggle()
```

Solid padding retains native List / Help / Terminal titles. Dotkit's existing
`FloatBorder` and `FloatTitle` palette groups make this visually borderless.
Other themes control their own border appearance; `single` and `rounded` are
also accepted. No private RGB palette is kept by this plugin.

Dotkit binds Ctrl-backslash in Normal and Terminal modes to toggle the manager.
In the list: `n` creates, `r` renames, `d` deletes, Enter selects, `q` closes the
UI. Alt-h/l focus the list/terminal; Alt-j/k select the next/previous session.
Escape twice leaves Terminal mode using the existing Dotkit mapping.

`new({ name = ..., cwd = ... })` starts a shell (default `vim.o.shell`) using the
specified cwd or effective current cwd. `select(index)`, `next()` and `prev()`
reuse existing sessions. `hide()` and `close()` preserve shell jobs; `close()`
also discards the Popup instance. `shutdown()` stops all jobs and releases all
owned buffers. Exiting the last shell closes the popup, without spawning a
replacement; the next `open()` creates a fresh session. VimLeavePre shuts down
all sessions. Closing a UI is deliberately not synonymous with killing a shell.

The optional `group` setting joins an existing Popup group. Dotkit supplies its
exclusive group; standalone callers do not need to create one.

## Ownership

The migrated modules retain their existing boundaries: state owns records and
selection; lifecycle owns shell creation/removal; actions reconciles lifecycle
and UI; float owns Popup; list owns list/help buffers and rendering. Entry-point
shutdown coordinates all resources. These internals are not a public API.

## Verification

From the repository root:

```sh
nvim --headless -u NONE -l dotfiles/configs/nvim-pack/terminal.nvim/tests/lifecycle.lua
pnpm check
pnpm test
```

The lifecycle test runs real `/bin/sh` jobs, checks hide/reopen identity, selection,
deleting a session, natural exit and shutdown. It cleans up even on assertion
failure. Visual title rendering, real terminal input and mouse focus still need
interactive verification. Installation uses the existing Dotfiles link workflow;
build/check/test never create home-directory links.

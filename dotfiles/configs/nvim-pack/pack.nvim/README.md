# Pack

Declare local (`path`) or remote (`src`) plugins with `require('pack').setup(specs)`.
Use `:PackSync` to install declared plugins; setup only loads installed targets.
Restart after installation to trigger startup events again.

## Automatic configuration

```lua
require('pack').setup({
  {
    src = 'https://github.com/lukas-reineke/indent-blankline.nvim',
    main = 'ibl',
    event = 'UIEnter',
    opts = { scope = { enabled = false } },
  },
})
```

Loading follows `dependencies → packadd → configuration → loaded`.

Lazy triggers are consumed only after successful loading. Missing targets or
configuration failures can retry on a later matching event; Pack does not replay
startup events after installation. Reentrant loading of an in-progress plugin
is deferred rather than running its configuration twice.

Repeating setup replaces pending Pack loader autocmds. It starts a fresh registry
and can run configuration again; it does not unload plugins, clear Lua's module
cache, or undo configuration side effects. Plugin setup functions must tolerate
reconfiguration if callers choose to repeat Pack setup.

- `config = function(opts) ... end` takes precedence; automatic setup is not also called.
- `config = false` skips module discovery and configuration.
- Otherwise, Pack calls the entry module's `setup(opts or {})` when available, even without `opts`.
- `main` explicitly identifies the Lua entry module. Without it, Pack tries `name`, then `name` without a `.nvim` suffix.
- `name` defaults to the basename of `src` or `path` and determines the installation directory. Changing it can require reinstalling; use `main` to change only module discovery.
- Missing entry/setup is optional only when neither `opts` nor `main` was supplied. Empty `opts = {}` still requests configuration.
- Errors inside modules or setup propagate, and the plugin is not marked loaded. Configuration side effects are not rolled back.

Declare direct dependencies with `deps`; do not rely on another entry's event callback running first:

```lua
{
  src = 'https://github.com/ya2s/nvim-nonicons',
  deps = {
    { src = 'https://github.com/nvim-tree/nvim-web-devicons' },
  },
  opts = {},
}
```

Shared dependencies initialize once per state. Repeated declarations with the same resolved plugin name and source are merged in declaration traversal order (including dependencies):

- `opts` is deep-merged; later values win, and lists are replaced rather than concatenated.
- `event`, `ft`, and dependencies are combined and deduplicated in first-seen order.
- Explicit `main`, `version`, `config`, and `build` values override earlier values. `config = false` is an explicit override; omitted fields do not erase earlier settings.
- A dependency-only declaration does not erase a feature's configuration. Cycles introduced across separate declarations are rejected before loading.

Different sources using the same name are rejected. Different names remain distinct plugin identities. A plugin with no explicit `opts` retains optional automatic setup semantics.

## Tests

See [tests/README.md](tests/README.md) for isolated Neovim tests and LuaLS checks.

# Pack tests

Run from the plugin root, following Picker's standalone test structure:

```sh
node tests/pack.ts
node tests/check-lua.ts
```

- `pack.ts` runs `setup.lua` in headless Neovim with temporary XDG directories, removed after each run. Tests use real plugin storage, `packadd()` and `require()` without modifying personal plugin data.
- `setup.lua` covers automatic setup, inferred and explicit entry modules, cached modules, options, custom config precedence, disabled configuration, optional setup, error propagation, failed loaded state, dependency ordering and shared dependency initialization.
- `check-lua.ts` runs **LuaLS**, matching Picker's checker (not the separate `luacheck` executable). It discovers the installed Neovim runtime and checks plugin Lua and Lua tests at `Hint` level. Any diagnostics fail the command.

Requirements: Node.js with TypeScript execution support, Neovim, and `lua-language-server` on PATH.

Repository integration tests:

```sh
pnpm exec vitest run dotfiles/test/nvim-pack-setup.spec.ts dotfiles/test/nvim.spec.ts
```

# Picker internal module tests

Run from the plugin directory (Node 24+ and Neovim required):

```sh
node tests/selection.ts
node tests/check-lua.ts
node tests/selection-types.ts
node tests/picker.ts
node tests/picker-types.ts
```

The LuaLS checks require `lua-language-server` on PATH. All runners locate the
plugin from their own location, so they also work from another directory.

## Real fff integration (opt-in)

Set `FFF_NVIM_PATH` to the installed fff plugin root, then run from the plugin directory:

```sh
nvim --headless -u NONE -i NONE -l tests/picker-fff-integration.lua
nvim --headless -u NONE -i NONE -l tests/picker-fff-resume.lua
```

These tests create temporary fixtures without loading personal configuration.
The first covers public grep modes, preview and resume. The second covers fresh
three-page continuation replay, public mapping navigation, mark restoration and
confirmation opening the exact file/line/byte column. Page lengths come from the
backend; requesting 100 matches need not return exactly 100.
Headless window assertions do not certify terminal responsiveness or visual quality.

## Picker public API types

`picker-types.ts` copies the plugin into a temporary workspace and checks valid
`open()` options and inferred mapping Actions first. Separate negative probes
must reject invalid mode/icon values, a string move delta, and invalid mark,
page and preview directions. Each probe expects a type diagnostic, not merely
an unsuccessful LuaLS process. This does not prove every API type is sound.

## Selection types

Annotate constructor options with the concrete item type:

```lua
---@type picker.selection.Options<MyItem>
local options = { key = get_key }
local selection = Selection.new(options)
```

With LuaLS 3.19.1, the callback annotation alone does not infer the item type
through an unannotated options table. The type fixture checks inference from
explicitly typed options without annotating or casting the resulting Selection.

Negative fixtures run in a temporary workspace. They verify rejection of a
non-array replacement argument and misuse of the current item as a number.

**Known checker limitation:** LuaLS 3.19.1 accepts `number[]` for a parameter
annotated as a record array, even in a plain non-generic function. The runner
prints `LIMITATION`, not `PASS`, for this gap. If a future LuaLS rejects the
plain-function probe, it then requires Selection to reject the same input.
A successful exit therefore does not certify array element validation.

These tests exercise an internal Picker module, not a public Selection plugin API.

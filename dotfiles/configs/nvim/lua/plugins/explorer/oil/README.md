# Oil popup integration

## Ownership

- `init.lua`: personal options and mappings.
- `adapter.lua`: stable mapping entry points, active panel reference, native Oil fallback and Cmdwin guard. It does not dispose UI resources.
- `panel.lua`: one opening of the browser. Owns the main Popup, origin, event group, layout and a Preview. Oil directory/selection semantics live here.
- `preview.lua`: owns its Popup and empty scratch buffer. File buffers are borrowed, including unsaved changes. Hiding retains the empty buffer; final close deletes it.

Dependencies are Adapter → Panel → Preview. Preview receives a popup factory and a hidden notification, not a Panel reference. The Panel alone decides whether hiding the preview requires a layout update.

## Lifecycle

A Panel progresses through `opening → open → closing → closed`. An opening failure also transitions through closing. It is not reopened; the Adapter creates a new Panel for each invocation.

Only open Panels process delayed updates. Closing stops events, closes the Preview, leaves the group, and closes the main Popup. Cleanup stages are independent and errors include their stage. An external Popup close event enters the same finalization path but does not request another main Popup close.

Restoring the origin is separate from cleanup: explicit user close/file selection restores focus; external close and failed initialization do not force a focus change. Cmdwin rejects toggle before any UI operation.

## Where to look

- Native Oil versus custom window routing: Adapter.
- Directory/file selection and Oil callbacks: Panel `select` and `open`.
- Leaked events or main windows: Panel `finish`, `stop_events`, `bind_events`.
- Wrong width after preview closes: Panel `render`.
- Preview content or scratch-buffer lifetime: Preview.

## Verification (repository root)

```sh
pnpm exec vitest run dotfiles/test/nvim-oil.spec.ts

# Explicitly select the real installed Oil version to exercise.
OIL_TEST_PATH="$HOME/.local/share/nvim/site/pack/core/opt/oil.nvim" \
  nvim --headless -u NONE -l dotfiles/configs/nvim/tests/oil-integration.lua
```

The lifecycle test uses real Popup/Neovim windows and a small Oil stub. It covers failed initialization, retry, external close, stale events, preview lifetime and real Cmdwin entry. The separate integration script requires Oil (it does not silently skip) and exercises directory navigation, file selection, vertical/horizontal/tab destinations, preview reuse and focus.

This integration still depends on Oil's `handle_buffer_callback` and `oil://` directory-buffer convention. Upgrading Oil requires rerunning the real integration script; these boundaries are not hidden behind trivial API wrappers.

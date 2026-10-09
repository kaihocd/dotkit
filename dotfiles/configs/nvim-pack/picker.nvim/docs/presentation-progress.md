# Presentation migration progress

## Implemented

- Public Picker prefix is a single style; mode selects internal defaults.
- Prefix margins `{ left, right }` default to `{ 0, 1 }` in Picker and Select.
- Public Picker `format` returns `Row.content` segments; legacy row fields are rejected.
- Shared content projection owns byte offsets and clipping.
- Default match style is Search; explicit current-row decoration uses CursorLine.
- Picker row styles are configurable; directory/location remain formatter-owned.
- Select supports `view.format(item, { index, text })`; original `format_item` remains the vim.ui.select text/search adapter.
- Select detail text retains original segment newlines; displayed rows use normalized text.
- Migrated affected existing runtime/type tests and added presentation-content regression.

## Verification

Picker, Select, Select UI, Selection, LuaLS, public type and Selection type runners passed.
Select UI and LuaLS were rerun after correcting custom current-group forwarding.
StyLua and git diff whitespace checks passed.
These are headless checks, not terminal visual acceptance.
LuaLS probes report limitations for inferred Select actions/items and inline formatter returns.

## Remaining review / work

- Remove obsolete internal ListBuild decorations and redundant fallback formatter paths.
- Add dedicated public Select custom-format lifecycle/resize/error regression coverage.
- Audit original TODO against actual files and update all examples, not only README.
- Decide final Select row-style naming; currently existing `view.highlights.current` is retained.
- Confirm overlapping grep syntax and match styles visually after segment flattening.
- Resume runtime on_instance support is a separate unfinished request; this migration has not implemented it.

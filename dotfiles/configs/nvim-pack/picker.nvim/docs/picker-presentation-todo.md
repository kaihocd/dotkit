# Picker Presentation API TODO

This document tracks the presentation API refactor for Picker and Select. The goal is to make row formatting and visual styling cohesive without exposing mode-specific implementation details.

## Target API

Picker exposes one prefix and one formatter for each invocation:

```lua
picker.open({
  mode = 'grep',
  view = {
    presentation = {
      prefix = {
        text = ' Search ',
        highlight = 'FloatTitle',
        margin = { 0, 1 },
      },
      row = {
        match = 'Search',
        current = 'CursorLine',
      },
      format = function(entry, context)
        return {
          content = {
            { entry.content },
          },
        }
      end,
    },
  },
})
```

`margin` is a tuple `{ left, right }`. The right value is the gap between the prefix and the query. Margin cells are not part of the prefix highlight.

Mode-specific defaults remain internal:

- `files` selects the default files prefix and formatter.
- `grep` selects the default grep prefix and formatter.
- A user-supplied `presentation.prefix` or `presentation.format` overrides the selected default for that invocation.
- Public configuration does not contain `prefix.files`, `prefix.grep`, `format.files`, or `format.grep`.

The default cross-mode row styles are:

```lua
row = {
  match = 'Search',
  current = 'CursorLine',
}
```

Directory and location styling remains inside the mode-specific default formatters. It is not exposed as generic row configuration.

## Work plan

### 1. Define the content-based Row protocol

- Replace the public row result with `picker.list.Row` containing `content`.
- Define a content segment as `{ text, highlight? }`.
- Treat a missing segment highlight as the list's normal/default style.
- Keep byte-offset calculation inside the renderer; callers must not calculate ranges.
- Decide and document validation for empty segments, non-string text, invalid highlight names, and malformed content arrays.
- During migration, provide a narrow internal adapter only if needed to keep intermediate tests readable; do not retain two public row protocols after migration.

### 2. Update the shared list renderer

- Change `picker/list.lua` to concatenate content segments into the buffer line.
- Calculate byte offsets internally while concatenating segments.
- Add segment extmarks for segments with a highlight group.
- Preserve clipping behavior and row-to-entry mappings.
- Ensure Unicode text is handled using byte lengths internally while callers only provide strings.
- Add renderer tests for multiple segments, unhighlighted segments, empty segments, and Unicode.

### 3. Add current-row rendering

- Add a dedicated list namespace for the current row.
- Pass the resolved current-row highlight into list rendering.
- Resolve the selected entry index to its display row, including grep rows and filtered results.
- Apply the current highlight to the whole display row even while the input window has focus.
- Clear stale current-row decorations on every render.
- Render current-row background before higher-priority local content/match decorations.
- Verify movement, filtering, paging, resize, and empty-list transitions.

### 4. Add resolved row styles

- Add `presentation.row.match` and `presentation.row.current` to the public Picker presentation options.
- Use defaults `Search` and `CursorLine`.
- Do not add generic `directory` or `location` fields.
- Pass resolved row styles to internal default formatters.
- Keep user formatters independent of mode selection; they receive the resolved context for the current invocation.

### 5. Convert default files and grep formatting

- Refactor the internal files formatter to produce content segments.
- Keep icon, basename, directory, and their internal styles in the files formatter.
- Refactor the internal grep formatter to produce content segments.
- Keep location and syntax styling in the grep formatter.
- Convert match ranges into content segments internally using the resolved `row.match` group.
- Ensure local match styling composes with the current-row background.
- Remove hard-coded `Special` for search matches once the resolved style is available.

### 6. Resolve presentation with mode context

- Change presentation resolution to accept `mode`.
- Select internal default prefix from the mode.
- Select internal default formatter from the mode.
- Deep-merge one public `presentation.prefix` over the selected default prefix.
- Select one public `presentation.format` as an override for the selected default formatter.
- Resolve `presentation.row` independently from mode-specific defaults.
- Return a resolved presentation containing one prefix, one formatter, and resolved row styles.
- Ensure downstream code never reads `prefix.files`, `prefix.grep`, `format.files`, or `format.grep`.

### 7. Update Picker window and input plumbing

- Pass Picker mode into `PickerWindow.new()` and presentation resolution.
- Make the window consume only the resolved single prefix and formatter.
- Update input rendering to apply `{ left, right }` margin around the prefix.
- Keep margin cells outside the prefix highlight.
- Do not modify the query buffer contents to implement the visual gap.
- Preserve cursor placement, insertion, completion, and resize behavior.

### 8. Replace `format_item` with `format`

- Rename the public presentation callback from `format_item` to `format`.
- Update public types, validation, invocation, documentation, and tests.
- Make `format` return the complete content-based Row.
- Do not require custom formatters to choose between files and grep.
- Do not require custom formatters to calculate byte ranges.
- Keep current-row decoration under renderer ownership.
- Decide explicitly whether the old field is rejected or temporarily adapted; final API should have one name only.

### 9. Migrate Select to the shared Row protocol

- Add a single Select `view.format` callback, not mode-specific public formatters.
- Define and use a Select default formatter that produces content segments.
- Reuse the shared Row/content renderer.
- Apply the shared current-row style to Select's current item.
- Keep Select free of Picker files/grep presentation branches.
- Preserve item identity, duplicate items, false-valued items, selection callbacks, and viewport behavior.
- Keep Select's `on_instance` integration independent from presentation formatting.

### 10. Update types and documentation

- Update Picker presentation, Row, content segment, formatter, and resolved presentation types.
- Update Select view and formatter types.
- Document margin as `{ left, right }` and explain that the right value separates prefix and query.
- Document the default `Search` and `CursorLine` groups.
- Document that directory/location styles belong to internal default formatters.
- Remove examples using `prefix.files`, `prefix.grep`, or `format_item`.
- Add examples for one public prefix and one public formatter.

### 11. Test the public behavior

Presentation resolution:

- files selects its internal default prefix and formatter.
- grep selects its internal default prefix and formatter.
- one public prefix overrides the selected mode default.
- one public format overrides the selected mode default.
- mode-specific public branches are not required or accepted.
- default row styles resolve to `Search` and `CursorLine`.

Rows and rendering:

- content segments concatenate correctly.
- segment highlights use the correct byte ranges.
- omitted highlights use the normal list style.
- malformed content produces a useful error.
- Unicode content renders correctly.
- match and current styles compose correctly.

Input:

- files, grep, and Select prefixes render with their default text.
- custom prefix text and highlight render correctly.
- `{ 0, 1 }` leaves one unhighlighted cell before the query.
- query text and cursor state remain unchanged.
- resize and completion preserve the layout.

Selection:

- current row remains visible while input has focus.
- current highlight follows movement, filtering, paging, and resize.
- Select uses the same current-row behavior.
- empty results clear stale current decorations.

### 12. Recommended implementation order

1. Add content-segment types and shared renderer support.
2. Migrate internal files and grep default formatters.
3. Add resolved `row.match` and `row.current` styles.
4. Implement current-row decoration and match style plumbing.
5. Change presentation resolution to accept mode and return one prefix/format.
6. Implement prefix margin rendering.
7. Rename `format_item` to `format` and migrate tests/docs.
8. Migrate Select to the shared Row protocol and current-row rendering.
9. Remove old public row and mode-specific presentation fields.
10. Run the complete Picker/Select/LuaLS/type/UI suites and update documentation.

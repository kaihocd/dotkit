# picker.nvim

File search and grouped content search using fff and native popup.nvim panes.
Also provides an independent Select UI. Loading the plugin does not replace
`vim.ui.select`, install global mappings, or change personal configuration.

## Dependencies

- Neovim (tested with 0.12; older versions are not certified).
- `popup.nvim` on runtimepath.
- `fff.nvim` and its working native backend for files/grep.
- Optional loaded MiniIcons or nvim-web-devicons for file icons.
- Optional Treesitter parsers and highlight queries for grep snippet syntax.

## Open and resume

```lua
local picker = require('picker')
picker.setup() -- Required before open/select/resume; does not install mappings.
picker.open() -- files, current working directory
picker.open({ mode = 'grep', cwd = '/path/to/project' })
picker.resume() -- most recently closed files/grep invocation
```

Each invocation creates its own source and UI. Grep starts in plain matching
mode; an empty grep query does not search content. Search calls are synchronous;
debouncing/scheduling does not turn fff search into asynchronous work.

`resume()` keeps one reusable, in-memory snapshot, not a history or persistent
session. It restores the resolved directory, query, matching mode, ordered marks,
preview switch and invocation configuration, then re-searches using fresh state.
The input starts at the end of the restored query.

`on_instance` is invocation-only: it is not saved in the snapshot or replayed.
Use `picker.resume({ on_instance = configure })` to apply group membership or
other instance configuration again. The hook runs before opening the instance;
resume accepts no other overrides.

Files restore the logical position using the current page size. Grep rebuilds
continuation from page one, up to ten pages; deeper positions fall back to page
one. At the target page, identity is preferred over the saved index. Missing
items or shortened results use a fallback with an informational notice; this is
not a confirmation request. No snapshot produces a notice without opening UI.
Navigation, confirmation or resize stops automatic restoration at the currently
displayed page. Query/matching-mode changes start a fresh search.

Marks retain saved locations, including entries outside the current results;
resume does not revalidate every marked file's existence. Four file-open actions
use the current item; quickfix uses ordered marks, or the current item if unmarked.

## Options

```lua
picker.open({
  mode = 'files', -- 'files' | 'grep'
  cwd = '/path/to/project',
  on_instance = function(instance)
    instance:join_group('my-existing-popup-group') -- optional application policy
  end,
  view = {
    icon = false, -- nil: auto-detect; false: omit; function(path): glyph?, highlight?
    presentation = {
      prefix = { text = ' Find ', highlight = 'Title', margin = { 0, 1 } },
      row = { match = 'Search', current = 'CursorLine' },
      marker = { text = '*', highlight = 'DiagnosticWarn' },
      status = { separator = ' / ' },
      messages = { empty = 'Nothing found', indexing = 'Searching…' },
      -- Pure entry + context -> row; no Session/View/window access.
      format = function(entry, context)
        return { content = { { entry.display, 'Title' } } }
      end,
    },
    -- Optional: compose Window-owned panes with the native popup tree API.
    layout = function(panes)
      -- Keep prompt mounted: it wraps independently of the single-line items.
      local children = { panes.input, panes.prompt, panes.list }
      if panes.preview then children[#children + 1] = panes.preview end
      return require('popup').col({ children = children })
    end,
  },
  keymaps = {
    i = {
      ['<C-t>'] = false, -- disable a default mapping
      ['<F6>'] = function(actions) actions.mark(0) end,
    },
  },
})
```

Presentation overrides are copied, not mutated. Mode selects the internal default prefix
and formatter; the public `prefix` and `format` override only this invocation.
`format` receives an isolated `Entry` and `{ mode, width, git_status,
icon, icon_highlight }`. Return `{ content = { { text, highlight? }, ... } }`.
The renderer owns clipping and byte offsets; omitted highlights inherit the normal style.
Grep filename headings remain built-in and unselectable. A custom formatter owns all
content styling, including matches; current-row highlighting remains automatic.
Selection and marking update renderer decorations only: they do not invoke `format`
or rewrite list text. Result and layout refreshes may invoke it again.

`row.match` defaults to `Search`, and `row.current` to `CursorLine`. Directory and
location styles belong to the default formatters, not public row settings.
`prefix.margin` is `{ left, right }` in cells, outside the prefix background, and
defaults to `{ 0, 1 }`. It never changes the query. `context.width` excludes list
padding. Marker text must fit one cell. Invalid formatter output closes Picker safely.

LuaLS currently accepts some invalid inline formatter return types (for example,
`{ text = 1 }`); runtime validation remains required. Type probes report this as a
limitation rather than a passing negative test.

Options are copied, not mutated. Window owns scratch buffers: replacing pane `buf`
is rejected. The old root and per-pane view options are removed; use `view.layout`.
Picker defaults to a centered popup at 70% of editor width and height. Use
`view.layout = { width_ratio = 0.8, height_ratio = 0.75 }` to adjust these
independently; optional `build(panes, context)` customizes the pane arrangement.
Function-only `view.layout` remains supported with the default size.
See [Layout API](docs/layout.md) for Picker/Select examples and current limitations. A custom layout must use input/list and the supplied enabled preview
exactly once; it may not replace pane buffers. `context.width/height` describe
available root dimensions. See `lua/picker/picker/config.lua` for annotated native
layout types and `lua/picker/picker/types.lua` for Options/Actions.

Mapping tables use native Neovim modes. Values accept disabled mappings (`false`),
recognized action names, native RHS strings, or callbacks receiving guarded
Actions, never a Session. Invalid options fail before source/UI allocation;
action errors close the invocation and report the error.

Search timing, backend limits and cache sizes are internal defaults, not public
options. Old Picker configuration tables cannot be copied into this API wholesale.

## Implementation ownership

Picker-specific code lives under `lua/picker/picker/`:

- `panel.lua`: one interactive Picker, user flows and once-only close/completion.
- `input.lua`: raw-text access, debounce and immediate flush.
- `list/`: backend pages, files logical positions, grep continuation, retry and restore.
- `selection.lua`: Entry identity and the adapter to shared `picker.selection`.
- `window/`: popup resources, layout and input/list/preview projections. ListPane owns
  entry-to-screen-row mappings; PreviewPane owns the viewport, never file reads.
- `preview/`: file content delivery, freshness, read scheduling and cache.
- `editor/`: guarded Actions and editor-event registration/cleanup.
- `options.lua`, `snapshot.lua`, `completion.lua`: validation, value-only resume data
  and final Neovim commands.

Shared `picker/list.lua`, `picker/selection/` and Select retain their own boundaries.
`lua/picker/picker-bak/` is a frozen pre-refactor source backup, not an independently
runnable module. It is excluded from LuaLS to avoid duplicate type definitions.

See `docs/picker-refactor-todo.md` for remaining architecture and acceptance work;
passing tests alone do not establish completion of that checklist.

## Default keys

Defaults apply to input normal and insert modes:

| Keys                 | Action                                           |
| -------------------- | ------------------------------------------------ |
| C-n / Down, C-p / Up | Next / previous item                             |
| Enter / C-j          | Open current file                                |
| C-s, C-v, C-t        | Split, vertical split, tab                       |
| Esc / C-c            | Cancel                                           |
| Tab / Shift-Tab      | Toggle mark, then move forward / backward        |
| C-q                  | Send marks or current item to quickfix           |
| C-d / C-u            | Half-page movement                               |
| C-l                  | Grep plain → regex → fuzzy                       |
| C-o                  | Toggle preview                                   |
| C-f / C-b            | Scroll preview without transferring focus        |
| Left mouse           | Select without confirming or leaving input focus |

C-r is not overridden. Losing focus outside Picker cancels it. Grep headings
are not selectable. Preview is initially off and adapts to available dimensions
when enabled; temporary layout hiding does not turn off the requested preview.

## Select

```lua
require('picker').setup()
require('picker').select({ 'one', 'two' }, { prompt = 'Choose' }, function(item, index)
  -- Original item and original numeric index; cancellation gives nil.
end)
```

Select is independent of files/grep and does not participate in `resume()`.

Default list rows show the original 1-based index in `Comment`, right-aligned to
the width of the original item count. Filtering preserves numbering and alignment.
Item padding defaults to `{ left = 2, right = 1 }`; the prompt retains its own
one-cell padding, and input prefix/query placement is unchanged.
`format_item` remains the standard text/search adapter. Default detail text keeps
that original text (including newlines), without the list number. A custom
`view.format(item, { index, text })` completely replaces default row formatting,
including numbering; its content also supplies detail text.

## Validation and demos

See [tests/README.md](tests/README.md) for automated suites and opt-in real fff
integration. From this directory:

```sh
node tests/demo-picker-fff.ts /path/to/project
```

The isolated demo exposes `:PickerDemo`, `:PickerGrepDemo` and
`:PickerResumeDemo`; confirmation really opens the file. It does not migrate
personal configuration. Implementation progress and evidence limits live in
[docs/picker-plan.md](docs/picker-plan.md).

## Configuration lifecycle

Call `picker.setup()` explicitly, even when using all defaults. Each setup starts
from private defaults; invalid settings leave the previous configuration intact.
Setup installs no mappings and does not replace `vim.ui.select`.

```lua
require('picker').setup({
  picker = {
    view = { layout = { width_ratio = 0.75, height_ratio = 0.75 } },
    search = { debounce_ms = 40, grep_page_size = 100 },
    preview = { max_files = 32, max_bytes = 8 * 1024 * 1024, radius = 2 },
    keymaps = { i = { ['<C-f>'] = false } },
  },
  select = { view = { max_items = 8, max_width = 80 } },
})
```

Records merge recursively, nonempty lists replace, and `false` remains a value
(for keymaps it installs `<Nop>`). Empty records leave inherited fields intact.
Each invocation owns a copied effective configuration. Later setup calls do not
change active sessions or resumed searches. Hooks such as `on_instance` belong
to individual invocations, not saved resume configuration.

Picker `view.presentation` configures titles, row highlights, marks and messages;
`view.signs` configures Git marker tuples and `staged_foreground_ratio` in `[0, 1]`.
The status-column position and list inset are internal geometry invariants, not
independently configurable settings. Native pane declarations and minimum screen
budgets are likewise structural constraints rather than missing-option fallbacks.

# Layout API (development)

Picker and Select expose one composition callback: `view.layout(panes, context)`.

Picker also accepts a layout table to configure its centered root size without
replacing the default pane arrangement:

```lua
picker.open({
  view = {
    layout = {
      width_ratio = 0.8,  -- default 0.7 of editor columns
      height_ratio = 0.75, -- default 0.7 of editor lines
      -- build = function(panes, context) return ... end,
    },
  },
})
```

Ratios must be numbers in `(0, 1]`. Dimensions are rounded down, with minimums
of 20 columns and 6 lines, and recalculated on resize. Screens below those
minimums are rejected. Optional `build` receives the computed root budget and
must fit its panes inside it. Function-only layouts retain the default 70% size.
These ratio options apply to Picker, not Select.
The previous `view.root/input/list/preview/detail` options are removed and rejected.
Root placement and screen-size budgeting are internal to Window, not callback return values.
Non-layout presentation options remain available.

```lua
local popup = require('popup')
local function picker_layout(panes, context)
  local main = popup.col({ children = { panes.input, panes.list } })
  if not panes.preview then return main end
  local split = context.width >= 120 and popup.row or popup.col
  return split({ children = { main, panes.preview } })
end
require('picker').open({ view = { layout = picker_layout } })
```

The default Picker layout uses input/list and, when enabled and space allows,
preview. A custom callback must retain the supplied preview; it is absent when
preview is disabled. Callback evaluation runs again on Picker resize/toggle.

```lua
require('picker').select({ 'first', 'second' }, {
  view = {
    layout = function(panes, context)
      return popup.col({ children = {
        panes.input,
        context.detail and panes.detail or panes.list,
      } })
    end,
  },
}, function(item, original_index)
  if original_index then print(item, original_index) end
end)
```

Select's default full-text mode replaces the list region with an independent detail
buffer; root geometry and input remain unchanged. Only a selected item clipped by
actual list rendering can enter full text. `<C-l>` returns from full text unconditionally.
Hints use the same clipping rule, but are hidden when the input has insufficient space.

`context.detail` is the current mode, not capability. The callback runs initially,
on mode transitions, and on resize. Always retain input; retain list in normal mode
and detail in full-text mode. Custom layouts may explicitly retain both panes.

Detail preserves original newline characters as buffer lines. Long lines use Neovim
`wrap`; no width-based line splitting or inserted newlines. Returning restores list
selection and viewport without overwriting its buffer.

## Callback contract

- `context.width/height` are the root's available dimensions, not editor dimensions.
- Return a native pane/row/col tree. Retain input and the current mode’s required pane exactly once.
- Use the supplied pane objects. Do not replace their IDs, types or buffers.
- Pane size/border/window styling may be adjusted on these fresh declarations;
  there are no separate public pane override tables.
- Do not allocate buffers or new panes in callbacks. Window owns resource cleanup.
- Do not return repeated nodes, cycles, nil or false. Callback errors propagate to
  the invocation's failure boundary, which cancels and releases owned resources.
- Fixed dimensions and borders must fit within the root budget. Composition does
  not automatically enlarge that budget for arbitrary nested layouts.

## Remaining work

Select reevaluates layout on `VimResized`, using the initial candidates and anchor
rather than filtered results or the input cursor. Query and detail state are retained.
A resize callback error or insufficient screen height cancels the invocation once
and releases its resources.

Arbitrary nested layout size inference is outside this migration: the caller must
fit declarations within the root budget. Automated regression and real fff integration
have passed; human terminal acceptance, including narrow-screen interaction, remains open. See
[layout-refactor-acceptance.md](layout-refactor-acceptance.md).

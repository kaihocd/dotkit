-- Row, marker and status rendering for the picker window.
--
-- Reads only the values it is handed: no popup lifecycle, no buffer ownership, no
-- search state. The window remains the owner of native resources and asks this
-- module to paint them.

local signs = require('picker.picker.window.signs')
local input_view = require('picker.picker.window.input')
local list_view = require('picker.picker.window.list')

local M = {}

-- One outer inset, one status cell and one separator precede each entry.
M.PADDING = { left = 3, right = 1 }
M.STATUS_COLUMN = 1

---Everything the renderer may read; all of it is resolved once per invocation.
---@class picker.picker.RendererDeps
---@field pane fun(id: string): popup.pane?
---@field query fun(): string
---@field page_size fun(): integer
---@field presentation picker.picker.ResolvedPresentation
---@field icon fun(path: string): string?, string?
---@field mode 'files'|'grep'
---@field signs picker.SignConfig
---@field list picker.picker.ListPane

---@class picker.picker.Renderer
---@field entries fun(entries: picker.picker.Entry[], index: integer?, status: string?)
---@field marks fun(entries: picker.picker.Entry[], is_marked: fun(entry: picker.picker.Entry): boolean)
---@field status fun(result: picker.picker.Page, marked: integer, mode?: string)
---@field select fun(index: integer?)
---@field page_delta fun(index: integer?, direction: integer): integer

---@param deps picker.picker.RendererDeps
---@return picker.picker.Renderer
function M.new(deps)
  local renderer = {}

  ---@param index integer?
  function renderer.select(index)
    local list = deps.pane('list')
    if list then
      deps.list:select(list, index, deps.presentation.row.current)
    end
  end

  ---@param entries picker.picker.Entry[]
  ---@param index integer?
  ---@param status? 'ready'|'indexing'
  function renderer.entries(entries, index, status)
    local list = deps.pane('list')
    if not list then
      return
    end
    local input = deps.pane('input')
    if input then
      input_view.render_prefix(input, deps.presentation.prefix)
    end
    local built = list_view.build({
      mode = deps.mode,
      width = math.max(0, vim.api.nvim_win_get_width(list.win) - M.PADDING.left - M.PADDING.right),
      entries = entries,
      icon = deps.icon,
      format = deps.presentation.format,
      match = deps.presentation.row.match,
      empty_text = status == 'indexing' and deps.presentation.messages.indexing
        or deps.presentation.messages.empty,
    })
    deps.list:render(list, built, M.PADDING)
    renderer.select(index)
  end

  ---Decorations reflect model marks; they never store a second selection state.
  ---@param entries picker.picker.Entry[]
  ---@param is_marked fun(entry: picker.picker.Entry): boolean
  function renderer.marks(entries, is_marked)
    local list = deps.pane('list')
    if not list then
      return
    end
    deps.list:marks(list, entries, is_marked, function(status, marked)
      return signs.marker(status, marked, deps.presentation.marker, deps.signs)
    end, M.STATUS_COLUMN)
  end

  ---@param result picker.picker.Page
  ---@param marked integer
  ---@param mode? string
  function renderer.status(result, marked, mode)
    local input = deps.pane('input')
    if not input then
      return
    end
    local prefix = deps.presentation.prefix
    return input_view.render_status(
      input,
      string.rep(' ', prefix.margin[1]) .. prefix.text .. string.rep(' ', prefix.margin[2]),
      deps.query(),
      result,
      marked,
      mode,
      deps.presentation.status,
      deps.presentation.messages.indexing
    )
  end

  ---Half-page navigation stays within this grep page until a real item edge is reached.
  ---@param index? integer
  ---@param direction integer
  ---@return integer
  function renderer.page_delta(index, direction)
    return deps.list:page_delta(index, direction, deps.page_size())
  end

  return renderer
end

return M

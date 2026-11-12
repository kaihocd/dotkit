local popup = require('popup')
local tree_ui = require('picker.ui.tree')
local M = {}

---New declarations per evaluation; callbacks never receive persistent pane state.
---@param options picker.picker.ResolvedView
---@param buffers integer[]
---@param preview boolean
---@return popup.spec.root
function M.build(options, buffers, preview)
  if vim.o.columns < 20 or vim.o.lines < 6 then
    error('picker: screen too small for input and list', 0)
  end

  local settings = options.layout
  local builder = settings.build
  local width = math.max(20, math.floor(vim.o.columns * settings.width_ratio))
  local height = math.max(6, math.floor(vim.o.lines * settings.height_ratio))
  ---@type popup.spec.root
  local root = {
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
  }

  local function pane(id, index, defaults)
    local spec = vim.deepcopy(defaults)
    -- Pane identity and scratch buffers belong to the window, not the layout callback.
    spec.id = id
    spec.buf = buffers[index]
    spec.enter = id == 'input'
    return popup.pane(spec)
  end

  local stacked = root.width < 120
  local visible = preview and (builder ~= nil or not stacked or root.height >= 10)
  local panes = {
    input = pane('input', 1, {
      size = { fixed = 1 },
      border = { '┌', '─', '┐', '│', '', '', '', '│' },
    }),
    list = pane('list', 2, {
      size = { flex = 1 },
      border = stacked and visible and { '├', '─', '┤', '│', '', '', '', '│' }
        or { '├', '─', '┤', '│', '┘', '─', '└', '│' },
      win_config = { focusable = false, mouse = true },
    }),
    preview = visible
        and pane('preview', 3, {
          size = { flex = 1 },
          border = stacked and { '├', '─', '┤', '│', '┘', '─', '└', '│' }
            or 'single',
          win_config = { focusable = false },
        })
      or nil,
  }

  local originals = { input = panes.input, list = panes.list, preview = panes.preview }

  if builder then
    root.layout = builder(panes, { width = root.width, height = root.height })
  else
    local main = popup.col({ children = { panes.input, panes.list } })
    if panes.preview then
      local split = stacked and popup.col or popup.row
      root.layout = split({ children = { main, panes.preview } })
    else
      root.layout = main
    end
  end

  tree_ui.validate(root.layout, panes, originals, buffers, {
    prefix = 'picker',
    roles = { 'input', 'list', 'preview' },
    optional = { preview = true },
    requires = function(used)
      if not used.input or not used.list or (visible and not used.preview) then
        return 'layout must retain input, list and the enabled preview'
      end
    end,
  })
  return root
end

return M

local popup = require('popup')
local M = {}

---@param tree popup.node
---@param panes picker.picker.LayoutPanes
---@param buffers integer[]
---@param preview boolean
local function validate(tree, panes, originals, buffers, preview)
  -- Validate against pre-callback identities, not the possibly mutated role table.
  for index, role in ipairs({ 'input', 'list', 'preview' }) do
    local pane = originals[role]
    if panes[role] ~= pane then
      error('picker: view.layout cannot replace supplied panes', 0)
    end
    if
      pane
      and (
        pane.id ~= role
        or pane.type ~= 'pane'
        or pane.buf ~= buffers[index]
        or not vim.api.nvim_buf_is_valid(buffers[index])
      )
    then
      error('picker: view.layout must preserve pane identity and buffer', 0)
    end
  end

  local seen = {}
  local roles = {}

  local function visit(node)
    if type(node) ~= 'table' or seen[node] then
      error('picker: view.layout must return a tree without repeated nodes', 0)
    end
    seen[node] = true

    if node.type == 'pane' then
      local id = node.id
      if not id or node ~= originals[id] or roles[id] then
        error('picker: view.layout must use each supplied pane exactly once', 0)
      end
      roles[id] = true

      local index = id == 'input' and 1 or id == 'list' and 2 or 3
      if node.buf ~= buffers[index] then
        error('picker: view.layout cannot replace pane buffers', 0)
      end
    elseif node.type == 'row' or node.type == 'col' then
      if type(node.children) ~= 'table' or #node.children == 0 then
        error('picker: view.layout containers require a nonempty children array', 0)
      end

      -- Reject holes and named children before ipairs traverses the tree.
      local count = 0
      for index in pairs(node.children) do
        if type(index) ~= 'number' or index % 1 ~= 0 or index < 1 or index > #node.children then
          error('picker: view.layout children must be a dense array', 0)
        end
        count = count + 1
      end
      if count ~= #node.children then
        error('picker: view.layout children must be a dense array', 0)
      end

      for _, child in ipairs(node.children) do
        visit(child)
      end
    else
      error('picker: view.layout expects native pane, row or col nodes', 0)
    end
  end

  visit(tree)

  if not roles.input or not roles.list or (preview and not roles.preview) then
    error('picker: view.layout must retain input, list and the enabled preview', 0)
  end
end

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

  validate(root.layout, panes, originals, buffers, visible)
  return root
end

return M

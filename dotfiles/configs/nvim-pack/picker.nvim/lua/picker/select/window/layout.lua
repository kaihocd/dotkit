local config_util = require('picker.select.config')
local list_renderer = require('picker.list')
local placement = require('popup.layout.placement')
local popup = require('popup')
local rect = require('popup.rect')

local M = {}

local INPUT_BORDER = { '┌', '─', '┐', '│', '', '', '', '│' }
local PROMPT_BORDER = { '├', '─', '┤', '│', '', '', '', '│' }
local LIST_BORDER = { '', '', '', '│', '┘', '─', '└', '│' }

local function border_dimensions(border)
  local edges = rect.normalize(border or 'none').width
  return edges.left + edges.right, edges.top + edges.bottom
end

local function prompt_height(prompt, width)
  local rows = 0
  for _, line in ipairs(vim.split(prompt or '', '\n', { plain = true })) do
    local cells = 0
    rows = rows + 1
    for _, char in ipairs(vim.fn.split(line, '\zs')) do
      local size = vim.fn.strdisplaywidth(char, cells)
      if cells + size > width then
        rows, cells = rows + 1, 0
      end
      cells = cells + size
    end
  end
  return rows
end

local function measure(texts, config, prompt)
  local input_width, input_height = border_dimensions(INPUT_BORDER)
  local list_width, list_height = border_dimensions(LIST_BORDER)
  local input_rows = 1
  local fixed_height = input_rows + 1 + input_height + list_height
  local content_width = math.max(
    vim.fn.strdisplaywidth(config.prefix.text) + 1,
    list_renderer.measure(prompt or '', { padding = config.padding })
  )

  for _, text in ipairs(texts) do
    content_width =
      math.max(content_width, list_renderer.measure(text, { padding = config.padding }))
  end

  local width = math.max(config.min_width, math.min(config.max_width, content_width))
  local available = math.max(1, math.min(width, vim.o.columns - 2))
  local title_rows = prompt_height(prompt, available)
  return {
    prompt_height = title_rows,
    width = width + math.max(input_width, list_width),
    height = math.max(config.min_items, math.min(config.max_items, #texts))
      + fixed_height
      + title_rows,
    min_height = fixed_height + 1,
  }
end

local function make_pane(id, overrides, defaults, buffers, buffer_index)
  local spec = config_util.merge(defaults, overrides)
  spec.id = id
  spec.buf = buffers[buffer_index]
  spec.enter = id == 'input'
  return popup.pane(spec)
end

local function make_panes(buffers, title_rows)
  return {
    prompt = make_pane(
      'prompt',
      {},
      { size = { fixed = title_rows }, border = PROMPT_BORDER, win_config = { focusable = false } },
      buffers,
      4
    ),
    input = make_pane('input', {}, { size = { fixed = 1 }, border = INPUT_BORDER }, buffers, 1),
    list = make_pane(
      'list',
      {},
      { border = LIST_BORDER, win_config = { focusable = false, mouse = true } },
      buffers,
      2
    ),
    detail = make_pane(
      'detail',
      {},
      { border = LIST_BORDER, win_config = { focusable = false, mouse = true } },
      buffers,
      3
    ),
  }
end

local function validate_layout(tree, panes, originals, buffers, detail)
  local seen, used = {}, {}

  -- Check even unmounted panes: callbacks may mutate the supplied role table.
  for index, role in ipairs({ 'input', 'list', 'detail', 'prompt' }) do
    local pane = originals[role]
    if
      panes[role] ~= pane
      or pane.id ~= role
      or pane.type ~= 'pane'
      or pane.buf ~= buffers[index]
      or not vim.api.nvim_buf_is_valid(buffers[index])
    then
      error('picker.select: layout must preserve supplied pane identity and buffer', 0)
    end
  end

  local function visit(node)
    if type(node) ~= 'table' or seen[node] then
      error('picker.select: layout must return a tree without repeated nodes', 0)
    end
    seen[node] = true

    if node.type == 'pane' then
      if not panes[node.id] or panes[node.id] ~= node or used[node.id] then
        error('picker.select: layout must use each supplied pane exactly once', 0)
      end
      used[node.id] = true
      return
    end

    if node.type ~= 'row' and node.type ~= 'col' then
      error('picker.select: layout expects native pane, row or col nodes', 0)
    end
    if type(node.children) ~= 'table' or #node.children == 0 then
      error('picker.select: layout containers require a nonempty children array', 0)
    end

    -- ipairs alone would silently skip holes or named children.
    local count = 0
    for index in pairs(node.children) do
      if type(index) ~= 'number' or index % 1 ~= 0 or index < 1 or index > #node.children then
        error('picker.select: layout children must be a dense array', 0)
      end
      count = count + 1
    end
    if count ~= #node.children then
      error('picker.select: layout children must be a dense array', 0)
    end

    for _, child in ipairs(node.children) do
      visit(child)
    end
  end

  visit(tree)

  if not used.input or not used.prompt or not used[detail and 'detail' or 'list'] then
    error('picker.select: layout must retain input and the active list/detail pane', 0)
  end
  return tree
end

local function root_geometry(texts, config, anchor, prompt)
  local size = measure(texts, config, prompt)
  local viewport = { width = vim.o.columns, height = math.max(1, vim.o.lines - vim.o.cmdheight) }
  local root = placement.below_or_above(size, {
    row = anchor.row - 1,
    col = anchor.col - 1,
  }, viewport)

  -- Clamp placement after choosing above/below; the anchor may now be off-screen.
  root.width = math.min(root.width, viewport.width)
  root.height = math.min(root.height, viewport.height)
  root.row = math.max(0, math.min(root.row, viewport.height - root.height))
  root.col = math.max(0, math.min(root.col, viewport.width - root.width))

  if root.height < size.min_height then
    error('picker.select: screen is too small for the configured input, prompt and borders', 0)
  end
  return root, math.max(1, math.min(size.prompt_height, root.height - size.min_height))
end

---@param texts string[]
---@param config picker.select.ResolvedView
---@param buffers integer[]
---@param anchor { row: integer, col: integer }
---@param detail? boolean
---@param prompt? string
---@return popup.spec.root
function M.build(texts, config, buffers, anchor, detail, prompt)
  local root, title_rows = root_geometry(texts, config, anchor, prompt)
  local panes = make_panes(buffers, title_rows)
  local originals =
    { input = panes.input, list = panes.list, detail = panes.detail, prompt = panes.prompt }

  local tree
  if config.layout then
    tree =
      config.layout(panes, { width = root.width, height = root.height, detail = detail == true })
  else
    tree =
      popup.col({ children = { panes.input, panes.prompt, detail and panes.detail or panes.list } })
  end

  ---@cast root popup.spec.root
  root.layout = validate_layout(tree, panes, originals, buffers, detail)
  return root
end

return M

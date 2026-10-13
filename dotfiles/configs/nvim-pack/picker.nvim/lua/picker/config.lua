-- Configuration boundary. Runtime consumers will receive invocation snapshots,
-- never this module's private defaults or configured state.
---@class picker.SearchConfig
---@field debounce_ms integer
---@field scan_poll_ms integer
---@field grep_page_size integer
---@field resume_grep_pages integer

---@class picker.PreviewConfig
---@field max_files integer
---@field max_bytes integer
---@field radius integer
---@field max_prefetch integer

---@class picker.SignOptions
---@field staged_foreground_ratio? number
---@field git? table<string, string[]>
---@class picker.SignConfig: picker.SignOptions
---@field staged_foreground_ratio number
---@field git table<string, string[]>
---@class picker.SearchOptions
---@field debounce_ms? integer
---@field scan_poll_ms? integer
---@field grep_page_size? integer
---@field resume_grep_pages? integer
---@class picker.PreviewOptions
---@field max_files? integer
---@field max_bytes? integer
---@field radius? integer
---@field max_prefetch? integer
---@class picker.SetupOptions
---@field picker? {view?: picker.picker.ViewOptions, keymaps?: picker.picker.Keymaps, search?: picker.SearchOptions, preview?: picker.PreviewOptions}
---@field select? {view?: picker.select.ViewOptions, keymaps?: table}

---@class picker.PickerConfig
---@field view picker.picker.ResolvedView
---@field keymaps picker.picker.Keymaps
---@field search picker.SearchConfig
---@field preview picker.PreviewConfig

---@class picker.SelectConfig
---@field view picker.select.ResolvedView
---@field keymaps table<string, table<string, string|false|function>>

local M = {}

local picker_keys = {
  ['<C-l>'] = 'cycle_match_mode',
  ['<C-f>'] = 'preview_down',
  ['<C-b>'] = 'preview_up',
  ['<LeftMouse>'] = 'click',
  ['<C-s>'] = 'open_split',
  ['<C-v>'] = 'open_vsplit',
  ['<C-t>'] = 'open_tab',
  ['<C-q>'] = 'quickfix',
  ['<Tab>'] = 'mark_next',
  ['<S-Tab>'] = 'mark_previous',
  ['<C-n>'] = 'next',
  ['<Down>'] = 'next',
  ['<C-p>'] = 'previous',
  ['<Up>'] = 'previous',
  ['<CR>'] = 'confirm',
  ['<C-j>'] = 'confirm',
  ['<Esc>'] = 'cancel',
  ['<C-c>'] = 'cancel',
  ['<C-o>'] = 'toggle_preview',
  ['<C-d>'] = 'page_down',
  ['<C-u>'] = 'page_up',
}

local select_keys = {
  ['<CR>'] = 'confirm',
  ['<C-j>'] = 'confirm',
  ['<C-l>'] = 'toggle_detail',
  ['<Esc>'] = 'cancel',
  ['<C-c>'] = 'cancel',
  ['<C-n>'] = 'next',
  ['<C-p>'] = 'previous',
  ['<C-d>'] = 'page_down',
  ['<C-u>'] = 'page_up',
  ['<LeftMouse>'] = 'click',
}

local defaults = {
  picker = {
    view = {
      layout = { width_ratio = 0.75, height_ratio = 0.75 },
      signs = {
        staged_foreground_ratio = 0.6,
        git = {
          untracked = { '┆', 'Added' },
          modified = { '┃', 'Changed' },
          deleted = { '┃', 'Removed' },
          staged_new = { '┃', 'Added' },
          staged_modified = { '┃', 'Changed' },
          staged_deleted = { '┃', 'Removed' },
          renamed = { '┃', 'Special' },
        },
      },
      presentation = {
        prefix = { highlight = 'FloatTitle', margin = { 0, 1 } },
        row = { match = 'Search', current = 'CursorLine' },
        marker = { text = '▊', highlight = 'Title' },
        status = {
          highlight = 'Comment',
          selected_suffix = ' selected',
          separator = ' · ',
          trailing_space = ' ',
        },
        messages = { empty = 'No Item', indexing = 'Indexing…' },
      },
    },
    keymaps = { n = picker_keys, i = vim.deepcopy(picker_keys) },
    search = { debounce_ms = 40, scan_poll_ms = 100, grep_page_size = 100, resume_grep_pages = 10 },
    preview = { max_files = 32, max_bytes = 8 * 1024 * 1024, radius = 2, max_prefetch = 4 },
  },
  select = {
    view = {
      min_items = 1,
      max_items = 8,
      min_width = 20,
      max_width = 80,
      padding = { left = 2, right = 1 },
      prefix = { text = ' Select ', highlight = 'FloatTitle', margin = { 0, 1 } },
      highlights = { prompt = 'Comment', current = 'CursorLine', hint = 'Comment' },
    },
    keymaps = { n = select_keys, i = vim.deepcopy(select_keys) },
  },
}

local configured

-- Records merge recursively; nonempty sequences replace their predecessors.
local function merge(base, overrides)
  local result = vim.deepcopy(base)
  for key, value in pairs(overrides) do
    if
      type(value) == 'table'
      and type(result[key]) == 'table'
      and (next(value) == nil or not vim.islist(value))
    then
      result[key] = merge(result[key], value)
    else
      result[key] = vim.deepcopy(value)
    end
  end
  return result
end

local function validate_record(options, schema, path)
  if type(options) ~= 'table' then
    error('picker: ' .. path .. ' must be a table', 0)
  end
  for key, value in pairs(options) do
    local name = path .. '.' .. tostring(key)
    if
      path:match('select%.view$')
      and (key == 'root' or key == 'input' or key == 'list' or key == 'preview' or key == 'detail')
    then
      error('picker: view.' .. key .. ' is no longer supported; use view.layout', 0)
    elseif (key == 'layout' or key == 'format') and path:match('select%.view$') then
      if type(value) ~= 'function' then
        error('picker: ' .. name .. ' must be a function', 0)
      end
    elseif key == 'format' and path:match('%.presentation$') then
      if type(value) ~= 'function' then
        error('picker: ' .. name .. ' must be a function', 0)
      end
    elseif key == 'text' and path:match('%.presentation%.prefix$') then
      if type(value) ~= 'string' or value:find('[\r\n\t]') then
        error('picker: ' .. name .. ' must be a single line without tabs', 0)
      end
    elseif key == 'icon' and path:match('picker%.view$') then
      if value ~= false and type(value) ~= 'function' then
        error('picker: view.icon must be false or a function', 0)
      end
    elseif schema[key] == nil then
      error('picker: unsupported option ' .. name, 0)
    elseif key == 'layout' then
      require('picker.picker.options').validate({ view = { layout = value } })
    elseif key == 'keymaps' then
      require('picker.picker.options').validate({ keymaps = value })
    elseif type(schema[key]) == 'table' then
      validate_record(value, schema[key], name)
    elseif type(value) ~= type(schema[key]) then
      error('picker: invalid type for ' .. name, 0)
    elseif
      path:find('.presentation', 1, true)
      and type(value) == 'string'
      and value:find('[\r\n\t]')
    then
      error('picker: ' .. name .. ' must be a single line without tabs', 0)
    end
  end
end

local function validate(kind, options)
  if kind == 'picker' then
    local signs = options.view.signs
    if not (signs.staged_foreground_ratio >= 0 and signs.staged_foreground_ratio <= 1) then
      error('picker: staged_foreground_ratio must be in [0, 1]', 0)
    end
    for _, marker in pairs(signs.git) do
      if
        not vim.islist(marker)
        or #marker ~= 2
        or marker[1]:find('[\r\n\t]')
        or vim.fn.strdisplaywidth(marker[1]) ~= 1
      then
        error('picker: git markers must contain one display cell and a highlight', 0)
      end
    end
    local presentation = options.view.presentation
    local margin = presentation.prefix.margin
    if not vim.islist(margin) or #margin ~= 2 then
      error('picker: prefix.margin must contain two non-negative integers', 0)
    end
    for _, value in ipairs(margin) do
      if not (value >= 0 and value < math.huge and value % 1 == 0) then
        error('picker: prefix.margin must contain non-negative integers', 0)
      end
    end
    if vim.fn.strdisplaywidth(presentation.marker.text) > 1 then
      error('picker: view.presentation.marker.text must fit one display cell', 0)
    end
    for _, key in ipairs({ 'width_ratio', 'height_ratio' }) do
      local ratio = options.view.layout[key]
      if not (ratio > 0 and ratio <= 1) then
        error('picker: layout ratios must be in (0, 1]', 0)
      end
    end
    for key, value in pairs(options.search) do
      local minimum = key == 'debounce_ms' and 0 or 1
      if not (value >= minimum and value < math.huge and value % 1 == 0) then
        error('picker: invalid search.' .. key, 0)
      end
    end
    for key, value in pairs(options.preview) do
      local minimum = (key == 'radius' or key == 'max_prefetch') and 0 or 1
      if not (value >= minimum and value < math.huge and value % 1 == 0) then
        error('picker: invalid preview.' .. key, 0)
      end
    end
  else
    local view = options.view
    for _, key in ipairs({ 'min_items', 'max_items', 'min_width', 'max_width' }) do
      local size = view[key]
      if not (size >= 1 and size < math.huge and size % 1 == 0) then
        error('picker: select sizes must be positive integers', 0)
      end
    end
    local _, problem = require('picker.select.config').validate(view)
    if problem then
      error('picker: ' .. problem, 0)
    end
  end
end

local function normalize(options)
  local result = vim.deepcopy(options)
  if result.view and type(result.view.layout) == 'function' then
    result.view.layout = { build = result.view.layout }
  end
  return result
end

---@param options? picker.SetupOptions
function M.setup(options)
  if options == nil then
    options = {}
  end
  validate_record(options, defaults, 'setup')
  local normalized = vim.deepcopy(options)
  if normalized.picker then
    normalized.picker = normalize(normalized.picker)
  end
  local next_config = merge(defaults, normalized)
  validate('picker', next_config.picker)
  validate('select', next_config.select)
  configured = next_config
end

function M.assert_setup()
  if not configured then
    error('picker: setup() must be called before using the API', 0)
  end
end

---@overload fun(kind: 'picker', overrides?: picker.picker.Options, mode?: 'files'|'grep'): picker.PickerConfig
---@overload fun(kind: 'select', overrides?: picker.select.Options, mode?: nil): picker.SelectConfig
---@param kind 'picker'|'select'
---@param overrides? table
---@param mode? 'files'|'grep'
---@return picker.PickerConfig|picker.SelectConfig
function M.resolve(kind, overrides, mode)
  M.assert_setup()
  if kind ~= 'picker' and kind ~= 'select' then
    error('picker: unknown configuration kind: ' .. tostring(kind), 0)
  end
  if overrides == nil then
    overrides = {}
  end
  validate_record(overrides, configured[kind], kind)
  local resolved = merge(configured[kind], kind == 'picker' and normalize(overrides) or overrides)
  validate(kind, resolved)
  if kind == 'picker' and resolved.view.presentation.prefix.text == nil then
    resolved.view.presentation.prefix.text = mode == 'grep' and ' Grep ' or ' Files '
  end
  return resolved
end

return M

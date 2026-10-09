local M = {}

---@class picker.picker.ResolvedPresentation: picker.picker.PresentationOptions
---@field prefix picker.picker.TextStyle
---@field row picker.picker.RowStyleOptions
---@field marker picker.picker.TextStyle
---@field status picker.picker.StatusPresentation
---@field messages {empty: string, indexing: string}
---@field format? picker.picker.FormatItem

local defaults = {
  prefix = {
    files = { text = ' Files ', highlight = 'FloatTitle', margin = { 0, 1 } },
    grep = { text = ' Grep ', highlight = 'FloatTitle', margin = { 0, 1 } },
  },
  row = { match = 'Search', current = 'CursorLine' },
  marker = { text = '▊', highlight = 'Title' },
  status = {
    highlight = 'Comment',
    selected_suffix = ' selected',
    separator = ' · ',
    trailing_space = ' ',
  },
  messages = { empty = 'No Item', indexing = 'Indexing…' },
}

---Validate partial overrides before merging; unknown fields must not silently do nothing.
---@param options table
---@param expected table
---@param path string
local function validate(options, expected, path)
  if type(options) ~= 'table' then
    error('picker: ' .. path .. ' must be a table', 0)
  end
  for key, value in pairs(options) do
    local name = path .. '.' .. tostring(key)
    local default = expected[key]
    if default == nil then
      error('picker: unsupported option ' .. name, 0)
    elseif type(default) == 'table' then
      validate(value, default, name)
    elseif type(value) ~= type(default) then
      error('picker: ' .. name .. ' must be a ' .. type(default), 0)
    elseif type(value) == 'string' and value:find('[\r\n\t]') then
      error('picker: ' .. name .. ' must be a single line without tabs', 0)
    end
  end
end

---@param options? picker.picker.PresentationOptions
---@return picker.picker.ResolvedPresentation
function M.resolve(options, mode)
  local selected = vim.deepcopy(defaults)
  selected.prefix = vim.deepcopy(defaults.prefix[mode or 'files'])
  selected.format = nil
  options = options or {}

  local schema = vim.tbl_extend('force', selected, { format = function() end })
  validate(options, schema, 'view.presentation')

  local result = vim.tbl_deep_extend('force', selected, vim.deepcopy(options))
  for _, value in ipairs(result.prefix.margin) do
    if value < 0 or value % 1 ~= 0 then
      error('picker: prefix.margin must contain non-negative integers', 0)
    end
  end
  if vim.fn.strdisplaywidth(result.marker.text) > 1 then
    error('picker: view.presentation.marker.text must fit one display cell', 0)
  end
  if not result.format then
    local format = require('picker.picker.window.format')
    local content = require('picker.content')
    local selected_format = mode == 'grep' and format.match or format.file
    result.format = function(entry, context)
      local text, ranges
      if mode == 'grep' then
        text, ranges = selected_format(entry, result.row.match)
      else
        text, ranges =
          selected_format(entry, context.icon, context.icon_highlight, result.row.match)
      end
      return content.from_ranges(text, ranges)
    end
  end
  return result
end

return M

local content = require('picker.content')
local format = require('picker.picker.window.format')
local M = {}

---@param entry picker.picker.Entry
---@param mode 'files'|'grep'
---@param width integer
---@param icon fun(path: string): string?, string?
---@param formatter picker.picker.FormatItem?
---@param match? string
---@return picker.list.Row
function M.item(entry, mode, width, icon, formatter, match)
  local glyph, icon_highlight = icon(entry.path)
  if formatter then
    local row = formatter(vim.deepcopy(entry), {
      mode = mode,
      width = width,
      git_status = entry.git_status,
      icon = glyph,
      icon_highlight = icon_highlight,
    })
    content.project(row)
    return vim.deepcopy(row)
  end

  local text, ranges
  if mode == 'grep' then
    text, ranges = format.match(entry, match)
  else
    text, ranges = format.file(entry, glyph, icon_highlight, match)
  end
  return content.from_ranges(text, ranges)
end

return M

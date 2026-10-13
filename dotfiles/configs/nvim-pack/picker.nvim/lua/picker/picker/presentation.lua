local M = {}

---@class picker.picker.ResolvedPresentation: picker.picker.PresentationOptions
---@field prefix picker.picker.TextStyle
---@field row picker.picker.RowStyleOptions
---@field marker picker.picker.TextStyle
---@field status picker.picker.StatusPresentation
---@field messages {empty: string, indexing: string}
---@field format? picker.picker.FormatItem

---Build a formatter from complete presentation settings; no defaults are read here.
---@param options picker.picker.ResolvedPresentation
---@return picker.picker.ResolvedPresentation
function M.resolve(options, mode)
  local result = vim.deepcopy(options)
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

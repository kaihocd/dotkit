local M = {}

---@class picker.picker.ResolvedPresentation: picker.picker.PresentationOptions
---@field prefix picker.picker.TextStyle
---@field row picker.picker.RowStyleOptions
---@field marker picker.picker.TextStyle
---@field status picker.picker.StatusPresentation
---@field messages {empty: string, indexing: string}
---@field format? picker.picker.FormatItem

---Pick the parts of a complete presentation that depend on the search mode.
---The prefix copy is configuration data keyed by search mode; this only picks
---the entry that applies, so files and grep may differ or share one string.
---`format` is left as the caller supplied it: `picker/picker/window/row.lua`
---applies the built-in formatter when a session does not override it.
---@param options picker.picker.ResolvedPresentation
---@param mode 'files'|'grep'
---@return picker.picker.ResolvedPresentation
function M.resolve(options, mode)
  local result = vim.deepcopy(options)
  local text = result.prefix.text
  if type(text) == 'table' then
    result.prefix.text = text[mode] or text.files
  end
  return result
end

return M

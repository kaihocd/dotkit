---Value-only resume data. No Session, source, window or cached page references.
---@class picker.picker.Snapshot
---@field settings picker.PickerConfig
---@field options picker.picker.ResolvedOptions
---@field query string
---@field match_mode string
---@field preview boolean
---@field page integer Zero-based search page.
---@field size integer Search page size when captured.
---@field index? integer Entry index within the search page.
---@field current? picker.picker.Entry Location only; never cached display content.
---@field marks picker.picker.Entry[] Ordered locations, including marks outside the current page.
---@class picker.picker.SnapshotState
---@field position {page: integer, size: integer}
---@field coherent boolean
---@field query string
---@field match_mode string
---@field preview boolean
---@field index? integer
---@field current? picker.picker.Entry
---@field marks picker.picker.Entry[]
local M = {}

---@param entry? picker.picker.Entry
---@return picker.picker.Entry?
local function location(entry)
  if not entry then
    return nil
  end
  return { path = entry.path, display = entry.display, line = entry.line, col = entry.col }
end

---@param session picker.picker.PickerPanel
---@param options picker.picker.Options Resolved invocation options, including absolute cwd.
---@return picker.picker.Snapshot
function M.capture(session, options)
  local state = session:snapshot_state()
  local position = state.position
  local coherent = state.coherent
  local marks = {}
  for _, entry in ipairs(state.marks) do
    marks[#marks + 1] = location(entry)
  end
  local saved_options = vim.deepcopy(options)
  -- Instance hooks belong to an invocation, never to resumable search settings.
  saved_options.on_instance = nil
  return {
    options = saved_options,
    settings = vim.deepcopy(session._settings),
    query = state.query,
    match_mode = state.match_mode,
    preview = state.preview,
    page = coherent and position.page or 0,
    size = position.size,
    index = coherent and state.index or nil,
    current = coherent and location(state.current) or nil,
    marks = marks,
  }
end

return M

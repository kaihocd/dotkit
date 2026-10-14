-- Terminal record stored in the state.
---@class terminal.record
---@field buf integer
---@field name string
---@field cwd string
---@field job_id integer

-- Shared terminal plugin state.
---@class terminal.state
---@field terminals terminal.record[]
---@field current_index integer
---@field popup? popup.instance
---@field settings? terminal.Config UI settings retained until the popup closes
---@field list_buf? integer
---@field help_buf? integer
---@field list_ns integer
---@field syncing boolean

local M = {
  terminals = {}, -- all terminal records
  current_index = 1, -- index of the selected terminal
  popup = nil, -- popup instance
  list_buf = nil, -- left list buffer handle
  help_buf = nil, -- left help buffer handle
  list_ns = vim.api.nvim_create_namespace('terminal-list'), -- highlight namespace
  syncing = false, -- guard against recursive cursor updates
}

-- Return the number of managed terminals.
---@return integer
function M.count()
  return #M.terminals
end

-- Return the currently selected terminal record.
---@return terminal.record?
function M.current()
  return M.terminals[M.current_index]
end

-- Keep current_index within the valid terminal range.
function M.clamp_index()
  if #M.terminals == 0 then
    M.current_index = 1
    return
  end

  if M.current_index < 1 then
    M.current_index = 1
  elseif M.current_index > #M.terminals then
    M.current_index = #M.terminals
  end
end

-- Select a terminal record by index.
---@param index integer
---@return boolean
function M.select(index)
  if index < 1 or index > #M.terminals then
    return false
  end

  M.current_index = index
  return true
end

-- Add a terminal record and select it.
---@param record terminal.record
---@return integer index
function M.add(record)
  table.insert(M.terminals, record)
  M.current_index = #M.terminals
  return M.current_index
end

-- Remove a terminal record by buffer handle.
---@param buf integer
---@return terminal.record? removed
---@return integer? index
function M.remove_by_buf(buf)
  for i, term in ipairs(M.terminals) do
    if term.buf == buf then
      local removed = table.remove(M.terminals, i)

      if M.current_index > #M.terminals then
        M.current_index = #M.terminals
      elseif M.current_index > i then
        M.current_index = M.current_index - 1
      end

      M.clamp_index()

      return removed, i
    end
  end

  return nil, nil
end

return M

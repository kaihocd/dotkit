local config = require('picker.picker.config')

---A bounded re-search task; each step performs at most one foreground search.
---@class picker.picker.Restore
---@field _snapshot picker.picker.Snapshot
---@field _done boolean
---@field _fallback boolean
local Restore = {}
Restore.__index = Restore

---@param snapshot picker.picker.Snapshot
---@return picker.picker.Restore
function Restore.new(snapshot)
  return setmetatable(
    { _snapshot = vim.deepcopy(snapshot), _done = false, _fallback = false },
    Restore
  )
end

---@param search picker.picker.ListPages Fresh pages owned by the restoring List.
---@param size integer Current page size.
---@return picker.picker.Page result
---@return integer? target
---@return boolean done
---@return boolean fallback
function Restore:step(search, size)
  local saved = self._snapshot
  local grep = saved.options.mode == 'grep'
  local result = search:refresh(saved.query, grep and saved.match_mode or nil, size, true)
  if result.status ~= 'ready' then
    return result, nil, false, self._fallback
  end

  local page = search:position()
  local wanted = saved.page
  local target = saved.index or 1
  if not grep then
    local logical = saved.page * saved.size + target - 1
    local clamped = math.max(0, math.min(logical, result.total - 1))
    wanted, target = math.floor(clamped / size), clamped % size + 1
    self._fallback = clamped ~= logical
  elseif wanted >= config.resume_grep_pages then
    wanted, target, self._fallback = 0, 1, true
  end

  if self._done then
    return result, nil, true, self._fallback
  end

  if page == wanted then
    local current = not self._fallback and saved.current or nil
    if current then
      local found
      for index, entry in ipairs(result.items) do
        if
          entry.path == current.path
          and (entry.line or 0) == (current.line or 0)
          and (entry.col or 0) == (current.col or 0)
        then
          found = index
          break
        end
      end

      if found then
        target = found
      else
        self._fallback = true
      end
    end

    if target > #result.items then
      self._fallback = true
    end

    self._done = true
    return result,
      #result.items > 0 and math.min(target, #result.items) or nil,
      true,
      self._fallback
  end

  if grep then
    if not result.more or not result.next_offset or result.next_offset <= 0 then
      self._done, self._fallback = true, true
      return result, #result.items > 0 and 1 or nil, true, true
    end
    search:move(#result.items, 1)
  else
    search:move(1, wanted * size - page * size)
  end

  return result, nil, false, self._fallback
end

return Restore

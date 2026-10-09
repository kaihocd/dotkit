local FilePages = require('picker.picker.list.files')
local GrepPages = require('picker.picker.list.grep')

---A backend page; counts describe backend results, not rendered rows.
---@class picker.picker.Page
---@field status 'ready'|'indexing'
---@field items picker.picker.Entry[]
---@field total integer
---@field more? boolean
---@field next_offset? integer

---A session-local adapter normalizes both backend pagination styles.
---@class picker.picker.PageSource
---@field search fun(query: string, size: integer, mode: string?, position: integer): picker.picker.Page

---Owns one query's pages and continuation chain, never selection or windows.
---@class picker.picker.ListPages
---@field _source picker.picker.PageSource
---@field _grep boolean
---@field _query string?
---@field _mode string?
---@field _pagination picker.picker.FilePages|picker.picker.GrepPages
---@field _loaded_page integer
---@field _revision integer
---@field _closed boolean
---@field _pending integer?
---@field _result picker.picker.Page
---@field _cache table<integer, picker.picker.Page>
---@field _order integer[]
local ListPages = {}
ListPages.__index = ListPages

---@param source picker.picker.PageSource
---@param grep boolean
---@return picker.picker.ListPages
function ListPages.new(source, grep)
  return setmetatable({
    _source = source,
    _grep = grep,
    _pagination = grep and GrepPages.new() or FilePages.new(),
    _loaded_page = 0,
    _revision = 0,
    _closed = false,
    _result = { status = 'ready', items = {}, total = 0 },
    _cache = {},
    _order = {},
  }, ListPages)
end

---@return integer page Zero-based page, not a continuation offset.
---@return integer size
function ListPages:position()
  return self._pagination.page, self._pagination.size
end

---@private
function ListPages:clear_cache()
  self._cache, self._order = {}, {}
end

---Three-page LRU: page freshness belongs to the query revision.
---@private
---@param index integer
---@param value picker.picker.Page
function ListPages:cache_page(index, value)
  for position, key in ipairs(self._order) do
    if key == index then
      table.remove(self._order, position)
      break
    end
  end
  self._cache[index] = value
  self._order[#self._order + 1] = index
  if #self._order > 3 then
    self._cache[table.remove(self._order, 1)] = nil
  end
end

---@private
---@param index integer
---@return picker.picker.Page
function ListPages:load(index)
  local position = self._pagination:backend_position(index)
  return self._source.search(self._query or '', self._pagination.size, self._mode, position)
end

---Backend errors propagate to Panel; indexing keeps a pending target.
---@param text string
---@param mode string?
---@param size integer Positive, validated page size.
---@param reuse? boolean
---@return picker.picker.Page
---@return integer? target
function ListPages:refresh(text, mode, size, reuse)
  if self._closed then
    return self._result
  end
  self._revision = self._revision + 1
  if self._query ~= text or self._mode ~= mode then
    self._pagination:reset()
    self._pending = nil
    self:clear_cache()
  elseif self._pagination.size ~= size then
    self:clear_cache()
  end
  self._query, self._mode = text, mode
  self._pagination:set_size(size)

  local page = self._pagination.page
  local result = (reuse and self._cache[page]) or self:load(page)
  self._result = result
  self._loaded_page = page
  local target
  if result.status == 'ready' then
    self._pagination:accept(result)
    self:cache_page(page, result)
    if self._pending then
      target = #result.items > 0 and math.max(1, math.min(self._pending, #result.items)) or nil
      self._pending = nil
    end
  end
  return result, target
end

---Grep callers invoke this only at an item edge; files use logical positions.
---@param index integer Current item position within the page.
---@param delta integer
---@return boolean changed_page
---@return integer? target
function ListPages:move(index, delta)
  if self._closed or self._result.status ~= 'ready' or delta == 0 then
    return false, index
  end
  local changed, target = self._pagination:move(self._result, index, delta)
  if changed then
    self._pending = target
    self._revision = self._revision + 1
  end

  return changed, target
end

---@param height integer Positive, validated list height.
---@param index integer Current item position, not a display row.
---@return integer? target
function ListPages:resize(height, index)
  if self._closed then
    return
  end

  local target = self._pagination:resize(height, index)
  if target then
    self._revision = self._revision + 1
    self:clear_cache()
    self._pending = target
  end

  return target
end

---Caller schedules this synchronous work; it is not asynchronous search.
---@return fun()
function ListPages:prefetch()
  local revision = self._revision
  local page, size = self:position()
  return function()
    if self._closed or revision ~= self._revision or self._grep then
      return
    end
    for _, adjacent in ipairs({ page - 1, page + 1 }) do
      if adjacent >= 0 and adjacent * size < self._result.total and not self._cache[adjacent] then
        local ok, result = pcall(self.load, self, adjacent)
        if self._closed or revision ~= self._revision then
          return
        end
        if ok and result.status == 'ready' then
          self:cache_page(adjacent, result)
        end
      end
    end
  end
end

---Keep explicit interaction on the page currently presented, not the next restore step.
function ListPages:cancel_pending()
  self._pagination.page = self._loaded_page
  self._pending = nil
  self._revision = self._revision + 1
end

---Invalidate scheduled prefetch immediately, before a debounced query is applied.
function ListPages:invalidate()
  self._revision = self._revision + 1
end

function ListPages:close()
  self._closed = true
  self._revision = self._revision + 1
  self:clear_cache()
  self._pagination:reset()
  self._result = { status = 'ready', items = {}, total = 0 }
end

return ListPages

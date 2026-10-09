local ListPages = require('picker.picker.list.pages')
local Restore = require('picker.picker.list.restore')
local config = require('picker.picker.config')

---Owns list delivery and pending work, never input buffers or selection.
---@class picker.picker.PickerList
---@field private _pages picker.picker.ListPages
---@field _grep boolean
---@field _mode string
---@field _query string
---@field _page picker.picker.Page
---@field _generation integer
---@field _closed boolean
---@field _restore? picker.picker.Restore
local PickerList = {}
PickerList.__index = PickerList

---@param source picker.picker.PageSource
---@param grep boolean
---@return picker.picker.PickerList
function PickerList.new(source, grep)
  return setmetatable({
    _pages = ListPages.new(source, grep),
    _grep = grep,
    _mode = 'plain',
    _query = '',
    _page = { status = 'ready', items = {}, total = 0 },
    _generation = 0,
    _closed = false,
  }, PickerList)
end

---@return string
function PickerList:match_mode()
  return self._mode
end

function PickerList:cycle_match_mode()
  local next_mode = { plain = 'regex', regex = 'fuzzy', fuzzy = 'plain' }
  self._restore = nil
  self._mode = next_mode[self._mode]
end

---@param snapshot picker.picker.Snapshot
function PickerList:restore(snapshot)
  self._query = snapshot.query
  self._mode = snapshot.match_mode
  self._restore = Restore.new(snapshot)
end

---Explicit interaction resumes from the page that was actually delivered.
function PickerList:interrupt_restore()
  if not self._restore then
    return
  end

  self._restore = nil
  self._generation = self._generation + 1
  self._pages:cancel_pending()
end

---Invalidate both foreground polling and speculative pages immediately on input.
function PickerList:invalidate()
  self._restore = nil
  self._generation = self._generation + 1
  self._pages:invalidate()
end

---@param query string
---@param height integer
---@param reuse boolean?
---@return picker.picker.Page
---@return integer? target
function PickerList:load(query, height, reuse)
  if self._closed then
    return self._page
  end

  self._generation = self._generation + 1
  local size = self._grep and config.grep_page_size or height

  if query ~= self._query then
    self._restore = nil
  end
  self._query = query

  if not self._restore then
    local page, target = self._pages:refresh(query, self._grep and self._mode or nil, size, reuse)
    self._page = page
    return page, target
  end

  local page, target, done, fallback = self._restore:step(self._pages, size)
  if done then
    self._restore = nil
    if fallback then
      vim.notify(
        'picker: previous location unavailable; restored nearest position',
        vim.log.levels.INFO
      )
    end
  end

  self._page = page
  return page, target
end

---Schedule only after the caller has applied the page successfully.
---@param page picker.picker.Page
---@param reload fun()
function PickerList:continue_loading(page, reload)
  if self._closed then
    return
  end

  if not self._restore then
    vim.schedule(self._pages:prefetch())
  end
  if page.status ~= 'indexing' and not self._restore then
    return
  end

  local generation = self._generation
  local delay = page.status == 'indexing' and config.scan_poll_ms or 0

  vim.defer_fn(function()
    if not self._closed and generation == self._generation then
      reload()
    end
  end, delay)
end

---Resolve navigation against the delivered list, not screen rows.
---@param index integer
---@param delta integer
---@return boolean changed_page
---@return integer? target
function PickerList:move(index, delta)
  if self._closed then
    return false
  end

  self:interrupt_restore()

  if self._grep then
    local count = #self._page.items
    local inside = (delta > 0 and index < count) or (delta < 0 and index > 1)

    if inside then
      return false, math.max(1, math.min(count, index + delta))
    end
  end

  return self._pages:move(index, delta)
end

---@param height integer
---@param index integer
---@return integer? target
function PickerList:resize(height, index)
  self:interrupt_restore()
  return self._pages:resize(height, index)
end

---Copied position data; callers never inspect the paging implementation.
---@return { page: integer, size: integer }
function PickerList:snapshot()
  local page, size = self._pages:position()
  return { page = page, size = size }
end

function PickerList:close()
  self._closed = true
  self._restore = nil
  self._generation = self._generation + 1
  self._pages:close()
end

return PickerList

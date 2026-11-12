local Cache = require('picker.picker.preview.cache')
local Reader = require('picker.picker.preview.reader')

---Owns request freshness, not windows. Every opened descriptor closes even after teardown.
---@class picker.picker.PreviewContent
---@field _revision integer
---@field _closed boolean
---@field _max_bytes integer
---@field _max_prefetch integer
---@field _active boolean
---@field _cache picker.picker.PreviewCache
---@field _nearby string[]
---@field _pending? {path: string, deliver?: fun(lines: string[]?, message: string?), revision: integer}
local Content = {}
Content.__index = Content

---@param max_bytes integer
---@param settings picker.PreviewConfig
---@return picker.picker.PreviewContent
function Content.new(max_bytes, settings)
  return setmetatable({
    _revision = 0,
    _closed = false,
    _max_bytes = max_bytes,
    _max_prefetch = settings.max_prefetch,
    _active = false,
    _nearby = {},
    _cache = Cache.new(settings.max_files, settings.max_bytes),
  }, Content)
end

---@param path string
---@param deliver fun(lines: string[]?, message: string?)
function Content:request(path, deliver)
  if self._closed then
    return
  end

  self._revision = self._revision + 1
  self._pending = { path = path, deliver = deliver, revision = self._revision }
  self:drain()
end

---Replace speculative work; it never owns delivery or outranks a foreground request.
---@param paths string[]
function Content:prefetch(paths)
  if self._closed then
    return
  end

  self._nearby = {}
  local seen = {}
  for _, path in ipairs(paths) do
    if not seen[path] and #self._nearby < self._max_prefetch then
      seen[path] = true
      self._nearby[#self._nearby + 1] = path
    end
  end

  self:drain()
end

---Loaded buffers take precedence over disk, including unsaved edits.
---@param path string
---@return string
local function version(path)
  local buf = vim.fn.bufnr(path)
  if buf >= 0 and vim.api.nvim_buf_is_loaded(buf) then
    return 'buffer:' .. buf .. ':' .. vim.api.nvim_buf_get_changedtick(buf)
  end

  local stat = vim.uv.fs_stat(path)
  return stat and ('file:' .. stat.mtime.sec .. ':' .. stat.mtime.nsec .. ':' .. stat.size)
    or 'missing'
end

---Next job to run: a foreground request outranks speculative work.
---@private
---@return {path: string, deliver?: fun(lines: string[]?, message: string?), revision: integer}?
function Content:claim()
  local job = self._pending
  self._pending = nil
  if job then
    return job
  end

  local path = table.remove(self._nearby, 1)
  if path then
    return { path = path, revision = self._revision }
  end
end

---A changed file must not displace the user's newer pending choice.
---@private
---@param job {path: string, deliver?: fun(lines: string[]?, message: string?), revision: integer}
---@param path string
---@param stamp string
---@param lines string[]?
---@param message string?
function Content:settle(job, path, stamp, lines, message)
  self._active = false
  if self._closed then
    return
  end

  if stamp ~= version(path) then
    if job.deliver and job.revision == self._revision then
      self._pending = job
    end
    self:drain()
    return
  end

  if lines then
    self._cache:put(path, stamp, lines)
  end

  -- Start queued work before calling user code, so callback errors cannot wedge the queue.
  self:drain()
  if not self._closed and job.deliver and job.revision == self._revision then
    job.deliver(lines, message)
  end
end

---Only the latest waiting request survives; in-flight reads finish normally.
function Content:drain()
  if self._closed or self._active then
    return
  end

  local job = self:claim()
  if not job then
    return
  end

  self._active = true
  local path, stamp = job.path, version(job.path)
  local cached = self._cache:get(path, stamp)
  if cached then
    vim.schedule(function()
      self:settle(job, path, stamp, cached, nil)
    end)
    return
  end

  Reader.load(path, self._max_bytes, function(lines, message)
    vim.schedule(function()
      self:settle(job, path, stamp, lines, message)
    end)
  end)
end

---Cancel delivery and queued work without discarding reusable snapshots.
function Content:invalidate()
  self._nearby = {}
  self._revision = self._revision + 1
  self._pending = nil
end

function Content:close()
  self._closed = true
  self._cache:clear()
  self._nearby = {}
  self._pending = nil
  self._revision = self._revision + 1
end

return Content

local Cache = require('picker.picker.preview.cache')
local defaults = require('picker.picker.preview.defaults')

---Owns request freshness, not windows. Every opened descriptor closes even after teardown.
---@class picker.picker.PreviewContent
---@field _revision integer
---@field _closed boolean
---@field _max_bytes integer
---@field _active boolean
---@field _cache picker.picker.PreviewCache
---@field _nearby string[]
---@field _pending? {path: string, deliver?: fun(lines: string[]?, message: string?), revision: integer}
local Content = {}
Content.__index = Content

---@param max_bytes integer
---@return picker.picker.PreviewContent
function Content.new(max_bytes)
  return setmetatable({
    _revision = 0,
    _closed = false,
    _max_bytes = max_bytes,
    _active = false,
    _nearby = {},
    _cache = Cache.new(defaults.max_files, defaults.max_bytes),
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
    if not seen[path] and #self._nearby < defaults.max_prefetch then
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

---Only the latest waiting request survives; in-flight descriptors finish normally.
function Content:drain()
  if self._closed or self._active then
    return
  end

  local job = self._pending
  self._pending = nil
  if not job then
    local path = table.remove(self._nearby, 1)
    if not path then
      return
    end
    job = { path = path, revision = self._revision }
  end

  self._active = true
  local path = job.path
  local stamp = version(path)

  local function publish(lines, message)
    vim.schedule(function()
      self._active = false
      if self._closed then
        return
      end

      if stamp ~= version(path) then
        -- Never let a changed old file displace the user's newer pending choice.
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
    end)
  end

  local cached = self._cache:get(path, stamp)
  if cached then
    publish(cached, nil)
    return
  end

  local buf = vim.fn.bufnr(path)
  if buf >= 0 and vim.api.nvim_buf_is_loaded(buf) then
    local count = vim.api.nvim_buf_line_count(buf)
    if vim.api.nvim_buf_get_offset(buf, count) > self._max_bytes then
      publish(nil, 'File too large to preview')
    else
      publish(vim.api.nvim_buf_get_lines(buf, 0, -1, false), nil)
    end
    return
  end

  vim.uv.fs_open(path, 'r', 438, function(open_error, fd)
    if not fd then
      publish(nil, 'Unable to open file: ' .. tostring(open_error))
      return
    end

    local function finish(data, message)
      vim.uv.fs_close(fd, function(close_error)
        if close_error then
          publish(nil, 'Unable to close preview file: ' .. close_error)
          return
        end
        if not data then
          publish(nil, message)
          return
        end
        if data:find('\0', 1, true) then
          publish(nil, 'Binary file')
          return
        end

        local lines = vim.split(data, '\n', { plain = true })
        if #lines > 1 and lines[#lines] == '' then
          table.remove(lines)
        end
        for index, line in ipairs(lines) do
          lines[index] = line:gsub('\r$', '')
        end

        publish(lines, nil)
      end)
    end

    vim.uv.fs_fstat(fd, function(stat_error, stat)
      if not stat then
        finish(nil, 'Unable to stat file: ' .. tostring(stat_error))
        return
      end
      if stat.type ~= 'file' then
        finish(nil, 'Not a regular file')
        return
      end
      if stat.size > self._max_bytes then
        finish(nil, 'File too large to preview')
        return
      end

      -- Read one extra byte to detect files that grew after fstat.
      vim.uv.fs_read(fd, self._max_bytes + 1, 0, function(read_error, data)
        if read_error or not data then
          finish(nil, 'Unable to read file: ' .. tostring(read_error))
        elseif #data > self._max_bytes then
          finish(nil, 'File too large to preview')
        else
          finish(data, nil)
        end
      end)
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

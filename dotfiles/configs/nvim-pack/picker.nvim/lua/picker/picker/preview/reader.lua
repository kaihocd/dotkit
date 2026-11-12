-- Reads one preview target, preferring an unsaved buffer over the file on disk.
--
-- Returns normalized lines or a user-facing message. Owns no freshness, caching
-- or queueing, so speculative and foreground reads share it unchanged.

local M = {}

---Normalize file bytes into display lines: no binary, no CRLF, no trailing blank.
---@param data string
---@return string[]? lines
---@return string? message
local function decode(data)
  if data:find('\0', 1, true) then
    return nil, 'Binary file'
  end

  local lines = vim.split(data, '\n', { plain = true })
  if #lines > 1 and lines[#lines] == '' then
    table.remove(lines)
  end
  for index, line in ipairs(lines) do
    lines[index] = line:gsub('\r$', '')
  end
  return lines, nil
end

---Close the descriptor before reporting, so no path leaks an open file.
---@param fd integer
---@param data string?
---@param message string?
---@param done fun(lines: string[]?, message: string?)
local function finish(fd, data, message, done)
  vim.uv.fs_close(fd, function(close_error)
    if close_error then
      done(nil, 'Unable to close preview file: ' .. tostring(close_error))
      return
    end
    if not data then
      done(nil, message)
      return
    end
    done(decode(data))
  end)
end

---@param fd integer
---@param max_bytes integer
---@param done fun(lines: string[]?, message: string?)
local function read_descriptor(fd, max_bytes, done)
  vim.uv.fs_fstat(fd, function(stat_error, stat)
    if not stat then
      finish(fd, nil, 'Unable to stat file: ' .. tostring(stat_error), done)
      return
    end
    if stat.type ~= 'file' then
      finish(fd, nil, 'Not a regular file', done)
      return
    end
    if stat.size > max_bytes then
      finish(fd, nil, 'File too large to preview', done)
      return
    end

    -- Read one extra byte to detect files that grew after fstat.
    vim.uv.fs_read(fd, max_bytes + 1, 0, function(read_error, data)
      if read_error or not data then
        finish(fd, nil, 'Unable to read file: ' .. tostring(read_error), done)
        return
      end
      if #data > max_bytes then
        finish(fd, nil, 'File too large to preview', done)
        return
      end
      finish(fd, data, nil, done)
    end)
  end)
end

---@param path string
---@param max_bytes integer
---@param done fun(lines: string[]?, message: string?)
function M.load(path, max_bytes, done)
  -- Loaded buffers take precedence over disk, including unsaved edits.
  local buf = vim.fn.bufnr(path)
  if buf >= 0 and vim.api.nvim_buf_is_loaded(buf) then
    if vim.api.nvim_buf_get_offset(buf, vim.api.nvim_buf_line_count(buf)) > max_bytes then
      done(nil, 'File too large to preview')
    else
      done(vim.api.nvim_buf_get_lines(buf, 0, -1, false), nil)
    end
    return
  end

  vim.uv.fs_open(path, 'r', 438, function(open_error, fd)
    if not fd then
      done(nil, 'Unable to open file: ' .. tostring(open_error))
      return
    end
    read_descriptor(fd, max_bytes, done)
  end)
end

return M

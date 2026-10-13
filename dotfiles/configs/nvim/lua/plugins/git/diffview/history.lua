local M = {}

local function warn(message)
  vim.notify(message, vim.log.levels.WARN, { title = 'Git history' })
end

-- Each query owns a snapshot. Ignore asynchronous results after the user
-- switches buffers or edits the file while Git is running.
local function run_git(request, args, callback)
  local command = { 'git', '-C', request.directory }
  vim.list_extend(command, args)

  vim.system(command, { text = true }, function(result)
    vim.schedule(function()
      if vim.api.nvim_get_current_buf() ~= request.buffer then
        return
      end
      if vim.api.nvim_buf_get_changedtick(request.buffer) ~= request.changedtick then
        return
      end

      callback(result)
    end)
  end)
end

local function check_history(request)
  local args = { 'log', '-1', '--format=%H' }

  if request.range then
    local first, last = unpack(request.range)
    local lines = ('%d,%d:./%s'):format(first, last, request.filename)
    vim.list_extend(args, { '-L', lines, 'HEAD' })
  else
    vim.list_extend(args, { 'HEAD', '--', request.filename })
  end

  run_git(request, args, function(result)
    if result.code ~= 0 or not result.stdout:match('%S') then
      warn('No commit history is available for this file or line range.')
      return
    end

    local paths = request.range and {} or { request.path }
    require('diffview').file_history(request.range, paths)
  end)
end

local function check_line_reference(request)
  -- Git line history uses HEAD coordinates. Do not guess a line mapping for
  -- local changes, even when those changes have already been saved or staged.
  run_git(request, { 'diff', '--quiet', 'HEAD', '--', request.filename }, function(result)
    if result.code ~= 0 then
      warn('The file differs from HEAD. Use <leader>gf to view file history instead.')
      return
    end

    check_history(request)
  end)
end

local function open_history(range)
  local buffer = vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(buffer)

  if vim.bo[buffer].buftype ~= '' or path == '' then
    warn('Open a regular file to view Git history.')
    return
  end

  if range and vim.bo[buffer].modified then
    warn('The file has unsaved changes. Use <leader>gf to view file history instead.')
    return
  end

  local request = {
    buffer = buffer,
    changedtick = vim.api.nvim_buf_get_changedtick(buffer),
    path = path,
    directory = vim.fs.dirname(path),
    filename = vim.fs.basename(path),
    range = range,
  }

  if request.range then
    check_line_reference(request)
  else
    check_history(request)
  end
end

function M.open_file()
  open_history()
end

function M.open_lines(first, last)
  first = first or vim.fn.line('.')
  last = last or first
  open_history({ math.min(first, last), math.max(first, last) })
end

return M

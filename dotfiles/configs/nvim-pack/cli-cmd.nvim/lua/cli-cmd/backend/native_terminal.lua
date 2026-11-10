---Native terminal backend built only on Neovim primitives (`jobstart` with `term = true`).
---The backend owns its buffer and job, and places the terminal in a fresh tab by
---default so a long-running or interactive command never replaces the current
---view. No dependency on `terminal.nvim`.
local check = require('cli-cmd.guard')('cli-cmd.backend.native_terminal')
local Instance = {}
Instance.__index = Instance

---Built-in placements. `sbuffer` reuses the terminal buffer without creating a
---stray empty buffer, and keeps the terminal buffer unlisted.
local layouts = {
  tab = function(buf)
    vim.cmd('tab sbuffer ' .. buf)
  end,
  split = function(buf)
    vim.cmd('sbuffer ' .. buf)
  end,
  vsplit = function(buf)
    vim.cmd('vertical sbuffer ' .. buf)
  end,
}

---A terminal window is a screen for a child process, and it inherits the window
---options of whatever window the tab or split was opened from. Line numbers, signs,
---a color column and soft wrapping all take width from the child and land in the
---middle of what the user is trying to read or copy; Neovim sets some of these for
---a terminal buffer and leaves the rest inherited, so they are set here.
---@param win integer
local function dress(win)
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = 'no'
  vim.wo[win].foldcolumn = '0'
  vim.wo[win].colorcolumn = ''
  vim.wo[win].cursorline = false
  vim.wo[win].spell = false
  vim.wo[win].list = false
  vim.wo[win].wrap = false
end

---`term:///tmp//1234:/bin/sh` says which pty the run got, not what the run is. A
---name made from the argv is what the tab list, `:ls` and the status line can use.
---@param context table
---@return string
local function name_of(context)
  return 'cli-cmd://' .. table.concat({ context.executable, unpack(context.argv) }, ' ')
end

local function discard(buf)
  pcall(vim.api.nvim_buf_delete, buf, { force = true })
end

---One exit path for every failure: release what was started, then fail the task.
local function abort(task, buf, job_id, message)
  if job_id then
    pcall(vim.fn.jobstop, job_id)
  end
  discard(buf)
  task:finish({ kind = 'error', message = message })
  error(message, 0)
end

local function stream(task, name)
  return function(_, data)
    vim.schedule(function()
      for _, chunk in ipairs(data or {}) do
        if chunk ~= '' then
          task:output(name, chunk)
        end
      end
    end)
  end
end

local function exit(task)
  return function(_, code)
    vim.schedule(function()
      task:finish({ kind = 'exit', code = code })
    end)
  end
end

---Start `context` inside `buf` and return the job id, or fail the task.
---`jobstart` with `term = true` is the current API: `vim.fn.termopen` is
---deprecated in favour of it and behaves identically for our options.
local function start(context, task, buf)
  local ok, job_id = pcall(vim.api.nvim_buf_call, buf, function()
    return vim.fn.jobstart({ context.executable, unpack(context.argv) }, {
      cwd = context.cwd,
      env = context.env,
      term = true,
      on_stdout = stream(task, 'stdout'),
      on_stderr = stream(task, 'stderr'),
      on_exit = exit(task),
    })
  end)
  if not ok or type(job_id) ~= 'number' or job_id <= 0 then
    abort(task, buf, nil, 'failed to start terminal: ' .. tostring(job_id))
  end
  return job_id
end

---@param context table
---@param task table
---@return {buf: integer, job_id: integer, cancel: fun()}
function Instance:run(context, task)
  check(type(context) == 'table', 'context is required')
  check(task and type(task.finish) == 'function', 'task is required')

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value('buflisted', false, { buf = buf })
  local job_id = start(context, task, buf)
  --`jobstart` gives the buffer a `term://` pty name; the readable one has to come
  --after it, or it is overwritten.
  pcall(vim.api.nvim_buf_set_name, buf, name_of(context))

  local placed, placement_error = pcall(layouts[self._layout], buf)
  if not placed then
    abort(task, buf, job_id, 'failed to present terminal: ' .. tostring(placement_error))
  end
  dress(vim.api.nvim_get_current_win())
  --The run is now the thing on screen, and an interactive child (a pager, a
  --`Stage this hunk?` prompt) is waiting for keys; making the user press `i` first
  --would look like the command hung.
  vim.cmd('startinsert')
  task:annotate('surface', 'terminal')

  local handle = {
    buf = buf,
    job_id = job_id,
    cancel = function()
      if vim.fn.jobwait({ job_id }, 0)[1] == -1 then
        vim.fn.jobstop(job_id)
      end
    end,
  }

  --The surface owns the job. Closing the tab or wiping the buffer is the user
  --saying they are done with this run, and Neovim does not do it for us: a
  --measured `:tabclose` leaves the terminal buffer hidden and the job running,
  --so a `fetch` would keep writing into a buffer nobody can see.
  --Closing the surface settles both directions: while the job runs, the user is
  --done with it, so it is cancelled; after the job ended, the buffer is what is
  --left to release. Neovim does neither — a measured `:tabclose` keeps a finished
  --terminal buffer loaded and hidden forever.
  local group = vim.api.nvim_create_augroup('cli_cmd_terminal_' .. buf, { clear = true })

  local function released()
    discard(buf)
    vim.schedule(function()
      pcall(vim.api.nvim_del_augroup_by_id, group)
    end)
  end

  vim.api.nvim_create_autocmd({ 'BufHidden', 'BufDelete', 'BufWipeout' }, {
    group = group,
    buffer = buf,
    callback = function()
      if task:status() == 'running' then
        task:cancel()
        return
      end
      if task:status() ~= 'finished' then
        return
      end
      --`BufHidden` fires while the window is still listed, so asking whether the
      --buffer is on screen has to wait until the event has been processed.
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(buf) and #vim.fn.win_findbuf(buf) == 0 then
          released()
        end
      end)
    end,
  })

  task:on(function(event)
    if event.kind == 'cancel' then
      handle.cancel()
      return
    end
    if event.kind ~= 'result' then
      return
    end
    --A run whose surface is already gone leaves nothing to read, so the buffer
    --goes with it. One that the user is still looking at stays, and the autocmd
    --above releases it when they close it.
    if vim.api.nvim_buf_is_valid(buf) and #vim.fn.win_findbuf(buf) == 0 then
      released()
    end
  end)
  return handle
end

local M = {}

---@param opts? {layout?: 'tab'|'split'|'vsplit'}
---@return table terminal instance with `:run(context, task)`
function M.new(opts)
  opts = opts or {}
  check(type(opts) == 'table', 'options must be a table')
  local layout = opts.layout or 'tab'
  check(
    type(layout) == 'string' and layouts[layout] ~= nil,
    'layout must be one of tab, split, vsplit'
  )
  return setmetatable({ _layout = layout }, Instance)
end

---Run with the default layout (`tab`).
function M.run(context, task)
  return M.new():run(context, task)
end

return M

---Command sessions: a session that runs argv instead of a shell, and what happens
---to it once its job is gone.
return function(test)
  local terminal = require('terminal')
  local state = require('terminal.state')

  ---Each case starts from an empty manager: `state` is module-level by design, so a
  ---test has to hand it back the way it found it.
  local function reset()
    for _, term in ipairs(state.terminals) do
      pcall(vim.fn.jobstop, term.job_id)
      if vim.api.nvim_buf_is_valid(term.buf) then
        pcall(vim.api.nvim_buf_delete, term.buf, { force = true })
      end
    end
    state.terminals = {}
    state.current_index = 1
  end

  local function wait_until(fn, what)
    local ok = vim.wait(5000, fn, 10)
    assert(ok, 'timed out waiting for ' .. what)
  end

  local function screen(buf)
    return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
  end

  terminal.setup({})

  test('runs argv directly, without a shell in between', function()
    reset()
    local index = terminal.new({ command = { 'echo', '$(id)' } })
    local buf = state.terminals[index].buf
    assert(index == 1)
    wait_until(function()
      return state.terminals[1].code ~= nil
    end, 'the command to exit')
    assert(screen(buf):find('$(id)', 1, true), 'a shell would have run that: ' .. screen(buf))
    reset()
  end)

  test('passes the environment a caller resolved, as jobstart takes it', function()
    reset()
    local index = terminal.new({
      command = { 'sh', '-c', 'printf "%s" "$PROBE_ENV"' },
      env = { PROBE_ENV = 'from-context' },
    })
    local buf = state.terminals[index].buf
    wait_until(function()
      return state.terminals[1].code ~= nil
    end, 'the command to exit')
    assert(screen(buf):find('from-context', 1, true), screen(buf))
    reset()
  end)

  test('reports the exit code and keeps the session so its output stays readable', function()
    reset()
    local reports = {}
    local index = terminal.new({
      name = 'failing',
      command = { 'sh', '-c', 'printf boom; exit 3' },
      on_exit = function(code)
        reports[#reports + 1] = code
      end,
    })
    local buf = state.terminals[index].buf
    wait_until(function()
      return #reports == 1
    end, 'the exit callback')
    assert(reports[1] == 3, vim.inspect(reports))
    assert(state.count() == 1, 'a command session must outlive its job')
    assert(state.terminals[1].code == 3)
    assert(state.terminals[1].name == 'failing')
    assert(vim.api.nvim_buf_is_valid(buf), 'a kept session keeps its buffer')
    assert(screen(buf):find('boom', 1, true), 'the output must still be there')
    reset()
  end)

  test('keeps a successful command session too, marked with its code', function()
    reset()
    terminal.new({ command = { 'sh', '-c', 'exit 0' } })
    wait_until(function()
      return state.terminals[1].code ~= nil
    end, 'the command to exit')
    assert(state.count() == 1)
    assert(state.terminals[1].code == 0)
    reset()
  end)

  test('honours keep = false for a command session', function()
    reset()
    terminal.new({ command = { 'sh', '-c', 'exit 0' }, keep = false })
    wait_until(function()
      return state.count() == 0
    end, 'the session to be dropped')
    reset()
  end)

  test('keeps the old behaviour for a plain shell session', function()
    reset()
    terminal.new({})
    local buf = state.terminals[1].buf
    local job_id = state.terminals[1].job_id
    assert(vim.fn.jobwait({ job_id }, 0)[1] == -1, 'the shell must be running')
    vim.fn.jobstop(job_id)
    wait_until(function()
      return state.count() == 0
    end, 'the exited shell to be dropped')
    assert(not vim.api.nvim_buf_is_valid(buf), 'a dropped session leaves no buffer')
    reset()
  end)

  test('removes a kept session on request', function()
    reset()
    terminal.new({ command = { 'sh', '-c', 'exit 0' } })
    local buf = state.terminals[1].buf
    wait_until(function()
      return state.terminals[1].code ~= nil
    end, 'the command to exit')
    terminal.forget(buf)
    assert(state.count() == 0)
    assert(not vim.api.nvim_buf_is_valid(buf))
    reset()
  end)

  test('removes a session whose job is still running', function()
    reset()
    terminal.new({ command = { 'sh', '-c', 'sleep 30' } })
    local buf = state.terminals[1].buf
    local job_id = state.terminals[1].job_id
    require('terminal.lifecycle').stop_or_remove(1, terminal)
    assert(state.count() == 0, 'the record must go')
    vim.wait(1000, function()
      return vim.fn.jobwait({ job_id }, 0)[1] ~= -1
    end, 10)
    assert(vim.fn.jobwait({ job_id }, 0)[1] ~= -1, 'the job must stop with it')
    assert(not vim.api.nvim_buf_is_valid(buf))
    reset()
  end)

  test('fails loudly when the command cannot start', function()
    reset()
    local ok, err = pcall(terminal.new, { command = { '/path/that/does/not/exist' } })
    assert(not ok)
    assert(tostring(err):find('terminal: failed to start command', 1, true), tostring(err))
    assert(state.count() == 0, 'a failed start must leave no record')
    reset()
  end)
end

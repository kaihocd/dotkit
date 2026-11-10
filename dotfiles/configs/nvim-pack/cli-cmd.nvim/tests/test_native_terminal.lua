return function(test)
  local function wait_for(task)
    vim.wait(3000, function()
      return task:status() == 'finished'
    end, 10)
    assert(task:status() == 'finished', 'terminal process did not finish')
  end

  test('runs an argv list in a native terminal and reports its exit code', function()
    local Native = require('cli-cmd.backend.native_terminal')
    local Task = require('cli-cmd.task')
    local task = Task.new()
    local outputs = {}
    task:on(function(event)
      if event.kind == 'output' then
        outputs[event.stream] = (outputs[event.stream] or '') .. event.data
      end
    end)
    task:start()
    local handle = Native.run({
      executable = 'sh',
      argv = { '-c', 'printf native; exit 4' },
      cwd = vim.fn.getcwd(),
    }, task)
    assert(type(handle.cancel) == 'function')
    wait_for(task)
    assert(task:result().kind == 'exit' and task:result().code == 4)
    assert(outputs.stdout:find('native', 1, true))
    assert(vim.api.nvim_buf_is_valid(handle.buf))
    assert(task:metadata().surface == 'terminal', 'the backend must annotate its output surface')
    vim.api.nvim_buf_delete(handle.buf, { force = true })
  end)

  test('cancels its own native terminal process without affecting another task', function()
    local Native = require('cli-cmd.backend.native_terminal')
    local Task = require('cli-cmd.task')
    local first, second = Task.new(), Task.new()
    first:start()
    second:start()
    local handle =
      Native.run({ executable = 'sh', argv = { '-c', 'sleep 5' }, cwd = vim.fn.getcwd() }, first)
    Native.run(
      { executable = 'sh', argv = { '-c', 'printf alive' }, cwd = vim.fn.getcwd() },
      second
    )
    assert(first:cancel() == true)
    wait_for(first)
    wait_for(second)
    assert(first:result().kind == 'cancelled')
    assert(second:result().kind == 'exit' and second:result().code == 0)
    vim.api.nvim_buf_delete(handle.buf, { force = true })
  end)

  test('shows the terminal in a new tab by default without replacing the current buffer', function()
    local Native = require('cli-cmd.backend.native_terminal')
    local Task = require('cli-cmd.task')
    local task = Task.new()
    task:start()
    local original_buf = vim.api.nvim_get_current_buf()
    local tabs_before = #vim.api.nvim_list_tabpages()

    local handle = Native.run(
      { executable = 'sh', argv = { '-c', 'printf tabbed' }, cwd = vim.fn.getcwd() },
      task
    )
    wait_for(task)

    assert(#vim.api.nvim_list_tabpages() == tabs_before + 1, 'the terminal must open in a new tab')
    assert(vim.api.nvim_get_current_buf() == handle.buf, 'the terminal must be the visible buffer')
    assert(
      vim.api.nvim_get_current_win() ~= nil and vim.fn.win_findbuf(handle.buf)[1] ~= nil,
      'the terminal buffer must be displayed in a window'
    )
    assert(vim.api.nvim_buf_is_valid(original_buf), 'the original buffer must survive')

    local tab = vim.api.nvim_get_current_tabpage()
    vim.cmd('tabclose!')
    assert(#vim.api.nvim_list_tabpages() == tabs_before, 'tab must close cleanly')
    assert(not vim.api.nvim_tabpage_is_valid(tab))
  end)

  test('can place the terminal in a split instead of a tab', function()
    local Native = require('cli-cmd.backend.native_terminal')
    local Task = require('cli-cmd.task')
    local task = Task.new()
    task:start()
    local tabs_before = #vim.api.nvim_list_tabpages()
    local windows_before = #vim.api.nvim_list_wins()

    local handle =
      Native.new({ layout = 'split' })
        :run({ executable = 'sh', argv = { '-c', 'printf split' }, cwd = vim.fn.getcwd() }, task)
    wait_for(task)

    assert(#vim.api.nvim_list_tabpages() == tabs_before, 'split layout must not create a tab')
    assert(#vim.api.nvim_list_wins() == windows_before + 1, 'split layout must create a window')
    assert(vim.fn.win_findbuf(handle.buf)[1] ~= nil)
    vim.api.nvim_win_close(0, true)
  end)

  test('rejects unknown layouts and leaves no tab behind when spawning fails', function()
    local Native = require('cli-cmd.backend.native_terminal')
    local Task = require('cli-cmd.task')
    ---@diagnostic disable-next-line: assign-type-mismatch
    local ok, err = pcall(Native.new, { layout = 'float' })
    assert(not ok)
    assert(tostring(err):find('layout must be one of tab, split, vsplit', 1, true))

    local task = Task.new()
    task:start()
    local tabs_before = #vim.api.nvim_list_tabpages()
    local spawned = pcall(
      Native.run,
      { executable = '/path/that/does/not/exist', argv = {}, cwd = vim.fn.getcwd() },
      task
    )
    assert(not spawned)
    assert(#vim.api.nvim_list_tabpages() == tabs_before, 'failed spawn must not open a tab')
  end)

  test('reports terminal spawn failure and does not leave an owned buffer', function()
    local Native = require('cli-cmd.backend.native_terminal')
    local Task = require('cli-cmd.task')
    local task = Task.new()
    task:start()
    local before = vim.api.nvim_list_bufs()
    local ok = pcall(Native.run, {
      executable = '/path/that/does/not/exist',
      argv = {},
      cwd = vim.fn.getcwd(),
    }, task)
    assert(not ok)
    assert(task:status() == 'finished' and task:result().kind == 'error')
    local after = vim.api.nvim_list_bufs()
    assert(#after == #before)
  end)
end

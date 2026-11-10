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

  ---Measured: `:tabclose` does not stop a terminal job — Neovim keeps both the
  ---buffer and the process — so the backend has to treat the closed surface as a
  ---cancellation, or a long command keeps running where nobody can see it.
  test('stops the job when its surface is closed', function()
    local Native = require('cli-cmd.backend.native_terminal')
    local Task = require('cli-cmd.task')
    local task = Task.new()
    task:start()
    local handle =
      Native.run({ executable = 'sh', argv = { '-c', 'sleep 30' }, cwd = vim.fn.getcwd() }, task)
    assert(vim.fn.jobwait({ handle.job_id }, 0)[1] == -1, 'the job must be running')

    vim.cmd('tabclose')

    wait_for(task)
    assert(task:result().kind == 'cancelled', vim.inspect(task:result()))
    assert(vim.fn.jobwait({ handle.job_id }, 0)[1] ~= -1, 'closing the tab must stop the job')
    vim.wait(500, function()
      return not vim.api.nvim_buf_is_valid(handle.buf)
    end, 10)
    assert(not vim.api.nvim_buf_is_valid(handle.buf), 'the closed surface leaves no buffer behind')
  end)

  test('leaves the buffer alone when the job ends while it is still visible', function()
    local Native = require('cli-cmd.backend.native_terminal')
    local Task = require('cli-cmd.task')
    local task = Task.new()
    task:start()
    local handle =
      Native.run({ executable = 'sh', argv = { '-c', 'printf keep' }, cwd = vim.fn.getcwd() }, task)
    wait_for(task)
    assert(vim.api.nvim_buf_is_valid(handle.buf), 'a finished run must stay readable')
    assert(#vim.fn.win_findbuf(handle.buf) == 1)
    vim.cmd('tabclose!')
  end)

  ---A terminal window inherits the current window's options, so a user with line
  ---numbers on gets a number column in a shell that cannot use one — measured, and
  ---the reason the backend has to set these itself instead of trusting defaults.
  test('gives the output the whole window instead of gutter columns', function()
    local Native = require('cli-cmd.backend.native_terminal')
    local Task = require('cli-cmd.task')
    local win_before = vim.api.nvim_get_current_win()
    local saved = {
      number = vim.wo[win_before].number,
      relativenumber = vim.wo[win_before].relativenumber,
      signcolumn = vim.wo[win_before].signcolumn,
      foldcolumn = vim.wo[win_before].foldcolumn,
      colorcolumn = vim.wo[win_before].colorcolumn,
      cursorline = vim.wo[win_before].cursorline,
      wrap = vim.wo[win_before].wrap,
    }
    vim.wo[win_before].number = true
    vim.wo[win_before].relativenumber = true
    vim.wo[win_before].signcolumn = 'yes'
    vim.wo[win_before].foldcolumn = '2'
    vim.wo[win_before].colorcolumn = '80'
    vim.wo[win_before].cursorline = true
    vim.wo[win_before].wrap = true

    local task = Task.new()
    task:start()
    local handle = Native.run(
      { executable = 'sh', argv = { '-c', 'printf gutter' }, cwd = vim.fn.getcwd() },
      task
    )
    wait_for(task)

    local win = vim.fn.win_findbuf(handle.buf)[1]
    assert(win, 'the terminal must be visible to have window options')
    assert(vim.wo[win].number == false, 'the terminal must not inherit line numbers')
    assert(vim.wo[win].relativenumber == false)
    assert(vim.wo[win].signcolumn == 'no', 'a terminal has nothing to sign')
    assert(vim.wo[win].foldcolumn == '0')
    assert(vim.wo[win].colorcolumn == '')
    assert(vim.wo[win].cursorline == false)
    assert(vim.wo[win].wrap == false, 'the child decides where its lines end')

    for name, value in pairs(saved) do
      vim.wo[win_before][name] = value
    end
    vim.cmd('tabclose!')
  end)

  test('names the terminal after the command it runs', function()
    local Native = require('cli-cmd.backend.native_terminal')
    local Task = require('cli-cmd.task')
    local task = Task.new()
    task:start()
    local handle = Native.run(
      { executable = 'sh', argv = { '-c', 'printf named' }, cwd = vim.fn.getcwd() },
      task
    )
    wait_for(task)
    assert(
      vim.api.nvim_buf_get_name(handle.buf):find('cli%-cmd://sh %-c printf named') == 1,
      'the buffer must say what it ran, not which pty it owns: '
        .. vim.api.nvim_buf_get_name(handle.buf)
    )
    vim.cmd('tabclose!')
  end)

  ---Measured: after a run ends Neovim keeps its terminal buffer alive, so closing
  ---the tab afterwards left a hidden `term://` buffer behind for good.
  test('releases the buffer when a finished run is closed', function()
    local Native = require('cli-cmd.backend.native_terminal')
    local Task = require('cli-cmd.task')
    local task = Task.new()
    task:start()
    local handle =
      Native.run({ executable = 'sh', argv = { '-c', 'printf gone' }, cwd = vim.fn.getcwd() }, task)
    wait_for(task)
    assert(vim.api.nvim_buf_is_valid(handle.buf), 'a finished run stays readable while it is open')

    vim.cmd('tabclose!')
    vim.wait(500, function()
      return not vim.api.nvim_buf_is_valid(handle.buf)
    end, 10)
    assert(
      not vim.api.nvim_buf_is_valid(handle.buf),
      'closing the surface of a finished run must release the buffer'
    )
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

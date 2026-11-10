return function(test)
  local Output = require('cli.presenter.output')
  local Task = require('cli.task')
  local levels = vim.log.levels

  local function capture()
    local messages = {}
    local presenter = Output.new({
      notify = function(message, level)
        messages[#messages + 1] = { message = message, level = level }
      end,
    })
    return presenter, messages
  end

  ---Attach first, then drive the task, mirroring how the command pipeline does it.
  local function present(presenter, result, chunks)
    local task = Task.new():start()
    presenter:attach(task)
    for _, chunk in ipairs(chunks or {}) do
      task:output(chunk[1], chunk[2])
    end
    task:complete(result)
    return task
  end

  test('reports buffered output once after a successful exit', function()
    local presenter, messages = capture()
    present(presenter, { kind = 'exit', code = 0 }, {
      { 'stdout', 'On branch main\n' },
      { 'stdout', 'clean\n' },
    })
    assert(#messages == 1, 'expected exactly one notification: ' .. vim.inspect(messages))
    assert(messages[1].message == 'On branch main\nclean')
    assert(messages[1].level == levels.INFO)
  end)

  test('stays silent for a successful exit without output', function()
    local presenter, messages = capture()
    present(presenter, { kind = 'exit', code = 0 })
    assert(#messages == 0, 'success without output must not notify')
  end)

  test('merges both streams and reports a nonzero exit as an error', function()
    local presenter, messages = capture()
    present(presenter, { kind = 'exit', code = 1 }, {
      { 'stdout', 'partial\n' },
      { 'stderr', 'fatal\n' },
    })
    assert(#messages == 1, vim.inspect(messages))
    assert(messages[1].message == 'partial\nfatal')
    assert(messages[1].level == levels.ERROR)
  end)

  test('falls back to the result when a failing task produced no output', function()
    local presenter, messages = capture()
    present(presenter, { kind = 'exit', code = 3 })
    present(presenter, { kind = 'error', message = 'spawn failed' })
    present(presenter, { kind = 'cancelled' })
    assert(#messages == 3, vim.inspect(messages))
    assert(messages[1].message == 'exit 3' and messages[1].level == levels.ERROR)
    assert(messages[2].message == 'spawn failed' and messages[2].level == levels.ERROR)
    assert(messages[3].message == 'cancelled' and messages[3].level == levels.WARN)
  end)

  test('normalizes carriage returns from progress-style output', function()
    local presenter, messages = capture()
    present(presenter, { kind = 'exit', code = 0 }, { { 'stderr', 'one\rtwo\r\n' } })
    assert(#messages == 1)
    assert(messages[1].message == 'one\ntwo', vim.inspect(messages[1].message))
  end)

  test('moves a report too long for the message area into a scratch tab', function()
    local presenter = Output.new({ max_lines = 3, notify = function() end })
    local tabs_before = #vim.api.nvim_list_tabpages()
    local task = Task.new():start()
    presenter:attach(task)
    task:output('stdout', 'one\ntwo\nthree\nfour\n')
    task:complete({ kind = 'exit', code = 0 })
    assert(#vim.api.nvim_list_tabpages() == tabs_before + 1, 'a long report opens a tab')
    local buffer = vim.api.nvim_get_current_buf()
    assert(vim.deep_equal(vim.api.nvim_buf_get_lines(buffer, 0, -1, false), {
      'one',
      'two',
      'three',
      'four',
    }))
    assert(vim.bo[buffer].modifiable == false, 'the report is read-only')
    vim.cmd('tabclose!')
    assert(#vim.api.nvim_list_tabpages() == tabs_before, 'closing the tab leaves nothing behind')
  end)

  test('keeps a report that exactly fills the limit in the message area', function()
    local presenter, messages = capture()
    present(presenter, { kind = 'exit', code = 0 }, { { 'stdout', 'one\ntwo\nthree\n' } })
    assert(#messages == 1, vim.inspect(messages))
  end)

  test('rejects a max_lines that is not a positive integer', function()
    assert(not pcall(Output.new, { max_lines = 0 }))
    assert(not pcall(Output.new, { max_lines = 2.5 }))
    ---@diagnostic disable-next-line: assign-type-mismatch
    local ok, err = pcall(Output.new, { max_lines = 'many' })
    assert(not ok and tostring(err):find('max_lines must be a positive integer', 1, true))
  end)

  test('does not report tasks a terminal already presents', function()
    local presenter, messages = capture()
    present(presenter, { kind = 'delegated', target = 'terminal' })
    assert(#messages == 0)
  end)

  test('skips tasks annotated with the terminal surface', function()
    local presenter, messages = capture()
    local task = Task.new():start()
    task:annotate('surface', 'terminal')
    presenter:attach(task)
    task:output('stdout', 'visible in the terminal\n')
    task:complete({ kind = 'exit', code = 1 })
    assert(#messages == 0, 'terminal surface must not be duplicated through notify')
  end)

  test('resolves vim.notify at emit time so a later override takes over', function()
    local original = vim.notify
    local seen
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.notify = function(message, level)
      seen = { message = message, level = level }
    end
    local ok, err = pcall(function()
      present(Output.new(), { kind = 'exit', code = 0 }, { { 'stdout', 'hello\n' } })
    end)
    vim.notify = original
    assert(ok, tostring(err))
    assert(seen and seen.message == 'hello', 'override of vim.notify must be used')
  end)

  test('presents real Git output through the command pipeline', function()
    local root = cli_test.temp_repo()
    local presenter, messages = capture()
    local Git = require('cli.adapter.git')
    local git = Git.new({ cwd = root, routes = { capture = 'process' }, presenter = presenter })
    local task = git:dispatch({
      argv = { 'status', '--short', '--branch' },
      raw_input = 'status',
      route_key = 'capture',
    })
    vim.wait(15000, function()
      return task:status() == 'finished'
    end, 10)
    assert(task:result().kind == 'exit' and task:result().code == 0)
    assert(#messages == 1, vim.inspect(messages))
    assert(
      messages[1].message:find('master', 1, true),
      'git status output must be reported: ' .. messages[1].message
    )
  end)

  test('can be disabled on a command', function()
    local root = cli_test.temp_repo()
    local Git = require('cli.adapter.git')
    local git = Git.new({ cwd = root, routes = { capture = 'process' }, presenter = false })
    local task = git:dispatch({ argv = { 'status' }, raw_input = 'status', route_key = 'capture' })
    vim.wait(15000, function()
      return task:status() == 'finished'
    end, 10)
    assert(task:result().kind == 'exit')
  end)
end

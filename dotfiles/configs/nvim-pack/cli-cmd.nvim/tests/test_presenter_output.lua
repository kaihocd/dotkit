return function(test)
  local Output = require('cli-cmd.presenter.output')
  local Task = require('cli-cmd.task')
  local levels = vim.log.levels

  ---A presenter whose sink records instead of rendering, so the report itself can
  ---be asserted without a window in the way.
  local function capture(opts)
    local messages = {}
    opts = vim.tbl_extend('force', {
      kind = function(message, level)
        messages[#messages + 1] = { message = message, level = level }
      end,
    }, opts or {})
    local presenter = Output.new(opts)
    ---@cast presenter cli-cmd.OutputPresenter
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

  ---`vim.o.lines / 3` is the tallest a split report is allowed to be.
  local function height_cap()
    return math.max(1, math.floor(vim.o.lines / 3))
  end

  test('reports buffered output once after a successful exit', function()
    local presenter, messages = capture()
    present(presenter, { kind = 'exit', code = 0 }, {
      { 'stdout', 'On branch main\n' },
      { 'stdout', 'clean\n' },
    })
    assert(#messages == 1, 'expected exactly one report: ' .. vim.inspect(messages))
    assert(messages[1].message == 'On branch main\nclean')
    assert(messages[1].level == levels.INFO)
  end)

  test('stays silent for a successful exit without output', function()
    local presenter, messages = capture()
    present(presenter, { kind = 'exit', code = 0 })
    assert(#messages == 0, 'success without output must not report')
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

  test('opens the report in a bottom split by default, never in a tab', function()
    local presenter = Output.new({})
    local tabs_before = #vim.api.nvim_list_tabpages()
    local wins_before = #vim.api.nvim_tabpage_list_wins(0)
    present(presenter, { kind = 'exit', code = 0 }, { { 'stdout', 'one\ntwo\n' } })
    assert(#vim.api.nvim_list_tabpages() == tabs_before, 'a report must not open a tab')
    assert(#vim.api.nvim_tabpage_list_wins(0) == wins_before + 1, 'the default sink opens a split')
    assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { 'one', 'two' }))
    assert(vim.bo.buftype == 'nofile', 'the report is not a file')
    assert(vim.bo.modifiable == false, 'the report is read-only')
    vim.cmd('close')
    assert(
      #vim.api.nvim_tabpage_list_wins(0) == wins_before,
      'closing the split leaves nothing behind'
    )
    assert(vim.fn.bufexists(vim.api.nvim_get_current_buf()) == 1, 'the user buffer survives')
  end)

  test('sizes the split to the report', function()
    local presenter = Output.new({})
    present(presenter, { kind = 'exit', code = 0 }, { { 'stdout', 'one\ntwo\n' } })
    assert(vim.api.nvim_win_get_height(0) == 2, 'a short report gets a short split')
    vim.cmd('close')
  end)

  test('honours min_height and max_height', function()
    local presenter = Output.new({ min_height = 3 })
    present(presenter, { kind = 'exit', code = 0 }, { { 'stdout', 'one\n' } })
    assert(vim.api.nvim_win_get_height(0) == 3, 'a short report grows to min_height')
    vim.cmd('close')

    presenter = Output.new({ max_height = 2 })
    present(presenter, { kind = 'exit', code = 0 }, { { 'stdout', 'one\ntwo\nthree\n' } })
    assert(vim.api.nvim_win_get_height(0) == 2, 'a long report stops at max_height')
    vim.cmd('close')
  end)

  test('measures the default max_height against the current screen', function()
    local presenter = Output.new({})
    local tall = {}
    for index = 1, vim.o.lines * 2 do
      tall[index] = 'line ' .. index
    end
    present(presenter, { kind = 'exit', code = 0 }, { { 'stdout', table.concat(tall, '\n') } })
    assert(vim.api.nvim_win_get_height(0) == height_cap(), 'the default cap follows vim.o.lines')
    vim.cmd('close')
  end)

  test('rejects heights that are not positive integers', function()
    assert(not pcall(Output.new, { min_height = 0 }))
    assert(not pcall(Output.new, { max_height = 1.5 }))
    local ok, err = pcall(Output.new, { min_height = 5, max_height = 2 })
    assert(
      not ok and tostring(err):find('min_height must not exceed max_height', 1, true),
      tostring(err)
    )
  end)

  test('can send the report to a tab instead', function()
    local presenter = Output.new({ kind = 'tab' })
    local tabs_before = #vim.api.nvim_list_tabpages()
    present(presenter, { kind = 'exit', code = 0 }, { { 'stdout', 'in a tab\n' } })
    assert(#vim.api.nvim_list_tabpages() == tabs_before + 1, 'this sink does open a tab')
    assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { 'in a tab' }))
    assert(vim.bo.modifiable == false, 'the report is read-only')
    vim.cmd('tabclose!')
    assert(#vim.api.nvim_list_tabpages() == tabs_before, 'closing the tab leaves nothing behind')
  end)

  test('can send every report to the message area instead', function()
    local original = vim.notify
    local seen
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.notify = function(message, level)
      seen = { message = message, level = level }
    end
    local ok, err = pcall(present, Output.new({ kind = 'notify' }), { kind = 'exit', code = 0 }, {
      { 'stdout', 'hello\n' },
    })
    vim.notify = original
    assert(ok, tostring(err))
    assert(seen and seen.message == 'hello', 'the notify sink uses vim.notify')
    assert(seen.level == levels.INFO, vim.inspect(seen))
  end)

  test('resolves vim.notify when the report is emitted, not when it is created', function()
    local presenter = Output.new({ kind = 'notify' })
    local original = vim.notify
    local seen
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.notify = function(message, level)
      seen = { message = message, level = level }
    end
    local ok, err = pcall(present, presenter, { kind = 'exit', code = 0 }, {
      { 'stdout', 'late override\n' },
    })
    vim.notify = original
    assert(ok, tostring(err))
    assert(seen and seen.message == 'late override', 'an override after new() still wins')
  end)

  test('can leave the report in a background tab', function()
    local presenter = Output.new({ kind = 'tab', enter = false })
    local origin = vim.api.nvim_get_current_tabpage()
    local tabs_before = #vim.api.nvim_list_tabpages()
    present(presenter, { kind = 'exit', code = 0 }, { { 'stdout', 'background\n' } })
    local tabs = vim.api.nvim_list_tabpages()
    assert(#tabs == tabs_before + 1, 'the report still gets its own tab')
    assert(vim.api.nvim_get_current_tabpage() == origin, 'the cursor stays where it was')
    local report_tab = tabs[#tabs]
    assert(report_tab ~= origin, 'the new tab is not the current one')
    local buffer = vim.api.nvim_tabpage_list_wins(report_tab)[1]
    assert(buffer ~= nil, 'the background tab has a window')
    local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(buffer), 0, -1, false)
    assert(vim.deep_equal(lines, { 'background' }), vim.inspect(lines))
    vim.cmd('tabclose! ' .. vim.api.nvim_tabpage_get_number(report_tab))
    assert(#vim.api.nvim_list_tabpages() == tabs_before)
  end)

  test('switches to the tab by default', function()
    local presenter = Output.new({ kind = 'tab' })
    local tabs_before = #vim.api.nvim_list_tabpages()
    present(presenter, { kind = 'exit', code = 0 }, { { 'stdout', 'foreground\n' } })
    assert(
      vim.api.nvim_get_current_tabpage()
        == vim.api.nvim_list_tabpages()[#vim.api.nvim_list_tabpages()]
    )
    vim.cmd('tabclose!')
    assert(#vim.api.nvim_list_tabpages() == tabs_before)
  end)

  test('rejects enter on a kind that never opens a tab', function()
    ---@diagnostic disable-next-line: assign-type-mismatch
    local ok, err = pcall(Output.new, { kind = 'split', enter = false })
    assert(not ok and tostring(err):find('does not apply to kind', 1, true), tostring(err))
    ---@diagnostic disable-next-line: assign-type-mismatch
    local bad = pcall(Output.new, { kind = 'tab', enter = 'no' })
    assert(not bad, 'enter is a boolean')
  end)

  test('applies window options to the report, not to the editor', function()
    vim.wo.number = false
    vim.wo.wrap = true
    local presenter = Output.new({ number = true, wrap = false })
    present(presenter, { kind = 'exit', code = 0 }, { { 'stdout', 'one\n' } })
    assert(vim.wo.number == true, 'number reaches the report window')
    assert(vim.wo.wrap == false, 'wrap reaches the report window')
    vim.cmd('close')
    assert(vim.wo.number == false, 'the editor window keeps its own setting')
    assert(vim.wo.wrap == true, 'the editor window keeps its own setting')
  end)

  test('rejects window options on a kind with no window', function()
    ---@diagnostic disable-next-line: assign-type-mismatch
    local ok, err = pcall(Output.new, { kind = 'notify', number = true })
    assert(not ok and tostring(err):find('does not apply to kind', 1, true), tostring(err))
    ---@diagnostic disable-next-line: assign-type-mismatch
    local bad = pcall(Output.new, { wrap = 'yes' })
    assert(not bad, 'wrap is a boolean')
  end)

  ---The declaration is the whole answer to "what does it do by default", so it
  ---is checked against a presenter nobody configured instead of trusted.
  test('every declared default reaches an unconfigured presenter', function()
    for kind, rules in pairs(Output.defaults.kinds) do
      local presenter = Output.new({ kind = kind })
      ---@diagnostic disable-next-line: invisible
      local options = presenter._options
      for name, rule in pairs(rules) do
        assert(
          options[name] == rule.default,
          ('%s.%s default is %s, got %s'):format(
            kind,
            name,
            tostring(rule.default),
            tostring(options[name])
          )
        )
      end
    end
  end)

  test('an unconfigured presenter has no option outside the declaration', function()
    local presenter = Output.new({})
    ---@diagnostic disable-next-line: invisible
    for name in pairs(presenter._options) do
      assert(Output.defaults.kinds.split[name] ~= nil, name .. ' is not declared')
    end
    ---@diagnostic disable-next-line: invisible
    assert(presenter._kind == Output.defaults.kind, 'the default kind comes from the declaration')
  end)

  test('rejects a kind it does not know', function()
    ---@diagnostic disable-next-line: assign-type-mismatch
    local ok, err = pcall(Output.new, { kind = 'pane' })
    assert(
      not ok and tostring(err):find("kind must be 'split', 'notify', 'tab', or a function", 1, true),
      tostring(err)
    )
    ---@diagnostic disable-next-line: assign-type-mismatch
    local bad_level = pcall(Output.new, { level = 'loud' })
    assert(not bad_level, 'a level must be a number')
  end)

  test('rejects split options on a kind with no window to size', function()
    ---@diagnostic disable-next-line: assign-type-mismatch
    local ok, err = pcall(Output.new, { kind = 'notify', min_height = 3 })
    assert(not ok and tostring(err):find('does not apply to kind', 1, true), tostring(err))
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
    assert(#messages == 0, 'terminal surface must not be duplicated through the presenter')
  end)

  test('presents real Git output through the command pipeline', function()
    local root = cli_cmd_test.temp_repo()
    local presenter, messages = capture()
    local GitCommand = require('cli-cmd.tools.git.command')
    local git = _G.cli_cmd_test.git_command({
      cwd = root,
      routes = { capture = 'process' },
      presenter = presenter,
    })
    local task = git:dispatch({
      argv = { 'status', '--short', '--branch' },
      route_key = 'capture',
    })
    vim.wait(15000, function()
      return task:status() == 'finished'
    end, 10)
    assert(task:result().kind == 'exit' and task:result().code == 0)
    assert(#messages == 1, vim.inspect(messages))
    assert(
      messages[1].message:find('## ' .. cli_cmd_test.branch, 1, true),
      'git status output must be reported: ' .. messages[1].message
    )
  end)

  test('can be disabled on a command', function()
    local root = cli_cmd_test.temp_repo()
    local GitCommand = require('cli-cmd.tools.git.command')
    local git = _G.cli_cmd_test.git_command({
      cwd = root,
      routes = { capture = 'process' },
      presenter = false,
    })
    local task = git:dispatch({ argv = { 'status' }, route_key = 'capture' })
    vim.wait(15000, function()
      return task:status() == 'finished'
    end, 10)
    assert(task:result().kind == 'exit')
  end)
end

return function(test)
  local Installer = require('cli-cmd.install')
  local Output = require('cli-cmd.presenter.output')
  local cli = require('cli-cmd')

  ---`:exists()` treats a shorter name as an abbreviation, so compare exact names.
  local function installed(name)
    return vim.api.nvim_get_commands({})[name] ~= nil
  end

  ---Palette writes its active theme under `$XDG_STATE_HOME`, so a temporary state
  ---home keeps the real one untouched and makes `set` observable.
  local function with_state(test_body)
    local previous = vim.env.XDG_STATE_HOME
    vim.env.XDG_STATE_HOME = vim.fn.tempname()
    vim.fn.mkdir(vim.env.XDG_STATE_HOME, 'p')
    local ok, err = pcall(test_body)
    vim.env.XDG_STATE_HOME = previous
    assert(ok, err)
  end

  ---Run `argv` through the installed command and collect what the presenter saw.
  local function run(report, argv)
    report.last = nil
    vim.cmd(('Palette %s'):format(table.concat(argv, ' ')))
    vim.wait(20000, function()
      return report.last ~= nil
    end, 20)
    assert(report.last ~= nil, 'no report for: Palette ' .. table.concat(argv, ' '))
    return report.last
  end

  ---Install with a recording presenter so a report is observable without tabs.
  local function install()
    local report = { messages = {} }
    local presenter = Output.new({
      notify = function(message)
        report.messages[#report.messages + 1] = message
        report.last = message
      end,
      max_lines = 1000,
    })
    Installer.dispose('palette')
    local tool = cli.install('palette', { presenter = presenter })
    return tool, report
  end

  test('installs Palette and reports what it prints', function()
    if vim.fn.executable('palette') == 0 then
      return
    end
    with_state(function()
      local tool, report = install()
      assert(vim.deep_equal(tool.commands, { 'Palette' }), vim.inspect(tool.commands))
      assert(installed('Palette'))
      assert(tool.editor == nil, 'Palette never needs an editor bridge')

      local listed = run(report, { 'list' })
      assert(listed:find('\nnord\n', 1, true), listed:sub(1, 80))

      run(report, { 'set', 'nord' })
      assert(run(report, { 'get' }):find('nord', 1, true))

      local failed = run(report, { 'nope' })
      assert(failed:find('exit', 1, true) or failed:find('PALETTE_ERROR', 1, true), failed)
      Installer.dispose('palette')
      assert(not installed('Palette'))
    end)
  end)

  test('routes every invocation to capture, with no terminal or editor', function()
    local spec = require('cli-cmd.tools.palette')
    assert(spec.route_key == nil, 'Palette has no surfaces to tell apart')
    assert(spec.routes == nil and spec.fallback == 'process', 'everything unrouted is captured')
    assert(spec.build == nil, 'the generic build is enough')
    assert(spec.editor == nil, 'no editor bridge')
    local tool, report = install()
    if vim.fn.executable('palette') == 0 then
      Installer.dispose('palette')
      return
    end
    with_state(function()
      local tabs_before = #vim.api.nvim_list_tabpages()
      local listed = run(report, { 'list' })
      assert(#listed > 20, 'palette list has one line per theme')
      assert(#vim.api.nvim_list_tabpages() == tabs_before, 'a captured run opens no terminal')
      Installer.dispose('palette')
    end)
  end)
end

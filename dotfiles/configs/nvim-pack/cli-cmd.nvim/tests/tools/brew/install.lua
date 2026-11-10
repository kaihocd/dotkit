return function(test)
  local Installer = require('cli-cmd.install')
  local Output = require('cli-cmd.presenter.output')
  local cli = require('cli-cmd')
  local Brew = require('cli-cmd.tools.brew.command')

  ---`:exists()` treats a shorter name as an abbreviation, so compare exact names.
  local function installed(name)
    return vim.api.nvim_get_commands({})[name] ~= nil
  end

  test('routes work that changes the machine to a terminal', function()
    for _, argv in ipairs({
      { 'install', 'wget' },
      { 'uninstall', 'wget' },
      { 'upgrade' },
      { 'update' },
      { 'cleanup' },
      { 'services', 'start', 'postgresql' },
      { 'edit', 'wget' },
    }) do
      assert(Brew.route_key(argv) == 'interactive', table.concat(argv, ' ') .. ' needs a terminal')
    end
    for _, argv in ipairs({
      { 'list' },
      { 'info', 'wget' },
      { 'search', 'wget' },
      { 'outdated' },
      { '--version' },
      { '--prefix' },
      { 'deps', 'wget' },
      { 'cat', 'wget' },
    }) do
      assert(Brew.route_key(argv) == 'capture', table.concat(argv, ' ') .. ' is a query')
    end
    assert(Brew.route_key({}) == 'capture', 'an empty command line asks for nothing')
    assert(Brew.route_key({ '--verbose', 'upgrade' }) == 'interactive')
    assert(Brew.route_key({ '--quiet', 'list' }) == 'capture')
  end)

  ---The table is a claim about the installed Brew, so check it against Brew.
  test('declares only commands the installed Brew has', function()
    if vim.fn.executable('brew') == 0 then
      test.skip('brew is not installed')
    end
    local finished = vim.system({ 'brew', 'commands', '--quiet' }, { text = true }):wait(60000)
    assert(finished and finished.code == 0, 'brew commands failed')
    local known = {}
    for _, name in ipairs(vim.split(finished.stdout or '', '\n', { trimempty = true })) do
      known[name] = true
    end
    for name in pairs(Brew.needs_a_terminal) do
      assert(known[name], 'Brew has no command named ' .. name)
    end
  end)

  test('installs Brew and reports what it prints', function()
    local report = { messages = {} }
    local presenter = Output.new({
      notify = function(message)
        report.messages[#report.messages + 1] = message
        report.last = message
      end,
      max_lines = 1000,
    })
    Installer.dispose('brew')
    local tool = cli.install('brew', { presenter = presenter })
    assert(vim.deep_equal(tool.commands, { 'Brew' }), vim.inspect(tool.commands))
    assert(installed('Brew'))
    if vim.fn.executable('brew') == 0 then
      Installer.dispose('brew')
      test.skip('brew is not installed, so there is nothing to run')
    end
    vim.cmd('Brew --version')
    vim.wait(60000, function()
      return report.last ~= nil
    end, 20)
    assert(report.last and report.last:find('Homebrew', 1, true), tostring(report.last))
    Installer.dispose('brew')
    assert(not installed('Brew'))
  end)

  ---A state-changing command must reach a real terminal. Installing a formula that
  ---does not exist changes nothing, so it is safe to run for real.
  test('run in a terminal, never in a captured pipe', function()
    if vim.fn.executable('brew') == 0 then
      test.skip('brew is not installed')
    end
    Installer.dispose('brew')
    cli.install('brew')
    local before = #vim.api.nvim_list_tabpages()
    vim.cmd('Brew install cli-cmd-no-such-formula')
    vim.wait(60000, function()
      local buffers = vim.api.nvim_list_bufs()
      for _, buffer in ipairs(buffers) do
        if vim.bo[buffer].buftype == 'terminal' then
          return true
        end
      end
      return false
    end, 20)
    local terminal
    for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[buffer].buftype == 'terminal' then
        terminal = buffer
      end
    end
    assert(terminal, 'a state-changing Brew command must get a terminal')
    assert(#vim.api.nvim_list_tabpages() > before, 'the terminal opens in its own tab')
    local handle = vim.b[terminal].terminal_job_id
    vim.wait(60000, function()
      return handle == nil or vim.fn.jobwait({ handle }, 0)[1] ~= -1
    end, 20)
    for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[buffer].buftype == 'terminal' then
        vim.cmd('silent! bdelete! ' .. buffer)
      end
    end
    Installer.dispose('brew')
  end)
end

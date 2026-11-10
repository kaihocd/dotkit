return function(test)
  local Provider = require('cli-cmd.tools.brew.completion')
  local Spec = require('cli-cmd.tools.brew.completion.spec')

  local lists = {
    { 'brew', 'commands', '--quiet' },
    { 'brew', 'formulae' },
    { 'brew', 'list', '--formula' },
    { 'brew', 'casks' },
  }
  local answers = {
    [table.concat(lists[1], ' ')] = {
      'install',
      'uninstall',
      'info',
      'list',
      'upgrade',
      '--prefix',
    },
    [table.concat(lists[2], ' ')] = { 'wget', 'jq', 'git' },
    [table.concat(lists[3], ' ')] = { 'wget', 'jq' },
    [table.concat(lists[4], ' ')] = { 'wezterm', 'alacritty' },
  }

  ---A fake Brew: only the four commands above answer, and every call is recorded so
  ---a test can see which list a query needed.
  local function provider()
    local calls = {}
    local instance = Provider.new({
      run = function(argv)
        calls[#calls + 1] = table.concat(argv, ' ')
        return answers[table.concat(argv, ' ')] or {}
      end,
    })
    return instance, calls
  end

  ---Ask through the real callback so prefix filtering and escaping are exercised.
  local function complete(line, opts)
    local instance = opts and opts.instance or provider()
    local callback = require('cli-cmd.completion').callback(instance)
    return callback('', line, #line)
  end

  test('offers the commands Brew itself reports', function()
    assert(
      vim.deep_equal(
        complete('Brew '),
        { '-h', '--help', 'install', 'uninstall', 'info', 'list', 'upgrade', '--prefix' }
      )
    )
    assert(vim.deep_equal(complete('Brew ins'), { 'install' }))
    -- `--prefix` is a global flag, not a command: the command position is still open.
    assert(
      vim.deep_equal(
        complete('Brew --prefix '),
        { '-h', '--help', 'install', 'uninstall', 'info', 'list', 'upgrade', '--prefix' }
      )
    )
  end)

  test('offers the list the command acts on, and only that list', function()
    local function asked(line)
      local instance, calls = provider()
      complete(line, { instance = instance })
      return calls
    end
    assert(vim.deep_equal(asked('Brew install w'), { 'brew formulae' }))
    assert(vim.deep_equal(asked('Brew uninstall w'), { 'brew list --formula' }))
    assert(vim.deep_equal(asked('Brew upgrade w'), { 'brew list --formula' }))
    assert(vim.deep_equal(asked('Brew list w'), {}))
    assert(vim.deep_equal(asked('Brew search w'), {}))
  end)

  test('reads casks when the command line asks for them', function()
    -- The framework filters by the unfinished word, so only the cask prefix survives.
    assert(vim.deep_equal(complete('Brew install --cask w'), { 'wezterm' }))
    assert(vim.deep_equal(complete('Brew uninstall --cask a'), { 'alacritty' }))
    -- Brew takes a list of casks, so the position stays open.
    assert(
      vim.deep_equal(complete('Brew install --cask wezterm '), { '-h', '--help', 'alacritty' })
    )
  end)

  test('reads each list once per provider', function()
    local instance, calls = provider()
    complete('Brew install ', { instance = instance })
    complete('Brew install j', { instance = instance })
    complete('Brew install w', { instance = instance })
    assert(vim.deep_equal(calls, { 'brew formulae' }), vim.inspect(calls))
  end)

  test('turns a failing source into no candidates, not an error', function()
    local instance = Provider.new({
      run = function()
        error('brew is not installed')
      end,
    })
    local callback = require('cli-cmd.completion').callback(instance)
    assert(vim.deep_equal(callback('', 'Brew install ', 13), { '-h', '--help' }))
    assert(vim.deep_equal(callback('', 'Brew ', 5), { '-h', '--help' }))
  end)

  ---The tables above claim what the installed Brew offers. Ask Brew whether each
  ---declared command exists, and whether every source command answers.
  test('agrees with the installed Brew about its own vocabulary', function()
    if vim.fn.executable('brew') == 0 then
      return
    end
    local function run(argv)
      local finished = vim.system(argv, { text = true }):wait(60000)
      assert(finished and finished.code == 0, table.concat(argv, ' ') .. ' failed')
      return vim.split(finished.stdout or '', '\n', { trimempty = true })
    end
    local commands = {}
    for _, name in ipairs(run({ 'brew', 'commands', '--quiet' })) do
      commands[name] = true
    end
    commands['--prefix'] = true -- a flag Brew's own list contains too
    for name in pairs(Spec.any_formula) do
      assert(commands[name], 'Brew has no command named ' .. name)
    end
    for name in pairs(Spec.installed_formula) do
      assert(commands[name], 'Brew has no command named ' .. name)
    end

    local sources = {
      commands = { 'commands', '--quiet' },
      formulae = { 'formulae' },
      installed = { 'list', '--formula' },
      casks = { 'casks' },
    }
    for name, argv in pairs(sources) do
      assert(vim.deep_equal(Spec.sources[name], argv), name .. ' source drifted')
      assert(#run(vim.list_extend({ 'brew' }, argv)) > 0, name .. ' answered nothing')
    end
  end)
end

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

  test('answers again when a source had no answer yet', function()
    local calls = 0
    local instance = Provider.new({
      run = function()
        calls = calls + 1
        if calls == 1 then
          return nil
        end
        return { 'jq' }
      end,
    })
    local callback = require('cli-cmd.completion').callback(instance)
    assert(vim.deep_equal(callback('', 'Brew install ', 13), { '-h', '--help' }))
    assert(vim.deep_equal(callback('', 'Brew install j', 14), { 'jq' }))
    assert(calls == 2, 'a source without an answer must be asked again')
  end)

  ---The editor must stay usable while Brew works: a machine that has never run Brew
  ---downloads its API data on the first call, and waiting for that would freeze
  ---Neovim for as long as the download takes. Point Brew at an empty cache so it has
  ---to do the work, and check the provider gives up instead of hanging.
  test('answers quickly even when Brew is slow', function()
    -- A fake brew that takes 10s, first on PATH: no network, no real Brew needed.
    local bin = vim.fn.tempname()
    vim.fn.mkdir(bin, 'p')
    local script = bin .. '/brew'
    vim.fn.writefile({ '#!/bin/sh', 'sleep 10', 'echo wget' }, script)
    vim.fn.setfperm(script, 'rwxr-xr-x')
    local saved = vim.env.PATH
    vim.env.PATH = bin .. ':' .. saved
    local instance = Provider.new({})
    local started = vim.uv.hrtime()
    instance({ tokens = {} })
    local elapsed = (vim.uv.hrtime() - started) / 1e6
    vim.env.PATH = saved
    vim.fn.delete(bin, 'rf')
    assert(elapsed < 5000, ('completion blocked the editor for %.0fms'):format(elapsed))
  end)

  ---A slow answer must not be killed: the work it does is what makes the next Tab
  ---instant. The fake brew answers instantly only after it has been run once.
  test('lets a slow answer finish in the background', function()
    local bin = vim.fn.tempname()
    vim.fn.mkdir(bin, 'p')
    local marker = bin .. '/warm'
    local script = bin .. '/brew'
    vim.fn.writefile({
      '#!/bin/sh',
      'if [ -f ' .. marker .. ' ]; then',
      '  echo wget',
      'else',
      '  sleep 2',
      '  : > ' .. marker,
      '  echo wget',
      'fi',
    }, script)
    vim.fn.setfperm(script, 'rwxr-xr-x')
    local saved = vim.env.PATH
    vim.env.PATH = bin .. ':' .. saved
    local instance = Provider.new({})
    local first = instance({ tokens = {} })
    assert(vim.deep_equal(first, { '-h', '--help' }), vim.inspect(first))
    vim.wait(4000, function()
      return vim.fn.filereadable(marker) == 1
    end, 50)
    local second = instance({ tokens = {} })
    vim.env.PATH = saved
    vim.fn.delete(bin, 'rf')
    assert(vim.deep_equal(second, { '-h', '--help', 'wget' }), vim.inspect(second))
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

    -- A source is right when its output *is* the candidate list: not "prints
    -- something", which depends on this machine's Brew (a cache that has never been
    -- filled prints nothing and exits 0), but "what Brew says is what the provider
    -- offers". Comparing against Brew's own answer holds either way.
    local real = require('cli-cmd.completion').callback(Provider.new({}))
    local declared = {
      commands = { 'commands', '--quiet' },
      formulae = { 'formulae' },
      installed = { 'list', '--formula' },
      casks = { 'casks' },
    }
    local positions = {
      commands = 'Brew ',
      formulae = 'Brew install ',
      installed = 'Brew uninstall ',
      casks = 'Brew install --cask ',
    }
    local function as_set(list)
      local set = {}
      for _, value in ipairs(list) do
        set[value] = true
      end
      return set
    end
    for name, argv in pairs(declared) do
      assert(vim.deep_equal(Spec.sources[name], argv), name .. ' source drifted')
      local expected = as_set(run(vim.list_extend({ 'brew' }, argv)))
      for _, option in ipairs(Spec.global_options) do
        expected[option] = true
      end
      assert(
        vim.deep_equal(as_set(real('', positions[name], #positions[name])), expected),
        name .. ' candidates are not what Brew answers'
      )
    end
  end)
end

return function(test)
  local Provider = require('cli-cmd.tools.palette.completion')
  local Spec = require('cli-cmd.tools.palette.completion.spec')

  ---Themes as the double reports them; `palette list` is one id per line.
  local themes = { 'nord', 'gruvbox-dark', 'tokyonight' }

  local function provider(opts)
    return Provider.new(vim.tbl_extend('force', {
      list = function()
        return themes
      end,
    }, opts or {}))
  end

  ---Ask through the real callback so prefix filtering and escaping are exercised.
  local function complete(line)
    local callback = require('cli-cmd.completion').callback(provider())
    local cursor = #line
    return callback('', line, cursor)
  end

  test('offers the commands of the tool, then the themes it reports', function()
    assert(vim.deep_equal(complete('Palette '), { 'list', 'get', 'set', 'help', '-h', '--help' }))
    assert(
      vim.deep_equal(
        complete('Palette set '),
        { '-h', '--help', 'nord', 'gruvbox-dark', 'tokyonight' }
      )
    )
    assert(vim.deep_equal(complete('Palette set gr'), { 'gruvbox-dark' }))
  end)

  test('offers no second argument and no option the command does not accept', function()
    assert(vim.deep_equal(complete('Palette set nord '), { '-h', '--help' }))
    assert(vim.deep_equal(complete('Palette list '), { '-h', '--help', '--json' }))
    assert(vim.deep_equal(complete('Palette help '), { '-h', '--help', 'list', 'get', 'set' }))
  end)

  test('never offers an option twice and never offers values of a plain command', function()
    assert(
      vim.deep_equal(
        complete('Palette get --json '),
        { '-h', '--help', 'nord', 'gruvbox-dark', 'tokyonight' }
      )
    )
    assert(vim.deep_equal(complete('Palette nope '), {}))
  end)

  test('reads the catalog once per provider', function()
    local calls = 0
    local queries = require('cli-cmd.completion').callback(Provider.new({
      list = function()
        calls = calls + 1
        return themes
      end,
    }))
    local line = 'Palette set '
    queries('', line, #line)
    queries('', line, #line)
    assert(calls == 1, 'expected one catalog read, got ' .. calls)
  end)

  test('turns a failing catalog into no candidates, not an error', function()
    local failing = Provider.new({
      list = function()
        error('palette is not installed')
      end,
    })
    local line = 'Palette set '
    assert(vim.deep_equal(failing({ tokens = { 'set' }, arglead = '' }), { '-h', '--help' }))
    local callback = require('cli-cmd.completion').callback(failing)
    assert(vim.deep_equal(callback('', line, #line), { '-h', '--help' }))
  end)

  ---The contract above is a copy of `palette --help`, so compare it with the real
  ---help whenever the tool is installed. A copy that drifts is worse than none.
  test('the contract matches the help Palette prints', function()
    if vim.fn.executable('palette') == 0 then
      return
    end
    local completed = vim.system({ 'palette', '--help' }, { text = true }):wait(10000)
    assert(completed and completed.code == 0, 'palette --help must succeed')
    local listed, seen = {}, {}
    for line in (completed.stdout or ''):gmatch('[^\n]+') do
      local name = line:match('^%s+palette%s+([%a][%w-]*)')
      if name and not seen[name] then
        seen[name] = true
        listed[#listed + 1] = name
      end
    end
    -- `help` itself is a command Palette accepts but does not advertise.
    local expected = vim.tbl_filter(function(name)
      return name ~= Spec.help_command
    end, Spec.order)
    assert(vim.deep_equal(listed, expected), vim.inspect(listed))
  end)
end

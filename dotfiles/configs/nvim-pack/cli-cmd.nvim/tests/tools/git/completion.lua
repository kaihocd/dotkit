return function(test)
  local Completion = require('cli-cmd.completion')
  local Discover = require('cli-cmd.tools.git.completion.discover')
  local GitCompletion = require('cli-cmd.tools.git.completion')
  local Spec = require('cli-cmd.tools.git.completion.spec')

  ---Discovery double: no Git involved, fixed vocabulary, counts calls.
  local function fake_discover(opts)
    opts = opts or {}
    local calls = { subcommands = 0, vocabulary = 0 }
    return {
      calls = calls,
      ---A double never runs Git: candidate sources get no output, which is the
      ---same answer a failed Git gives.
      run = function()
        return nil
      end,
      subcommands = function()
        calls.subcommands = calls.subcommands + 1
        return opts.subcommands or { 'add', 'checkout', 'commit', 'log', 'stash', 'status' }
      end,
      vocabulary = function(_, command)
        calls.vocabulary = calls.vocabulary + 1
        return opts.vocabulary
          or {
            options = { '--amend', '--author=', '--message=' },
            values = { ['--author'] = true, ['--message'] = true },
            words = command == 'stash' and { 'apply', 'drop', 'pop' } or {},
          }
      end,
    }
  end

  test('splits arguments with native user-command rules', function()
    local tokens, current = Completion.split([[checkout my\ file.txt]])
    assert(vim.deep_equal(tokens, { 'checkout' }))
    assert(current == 'my file.txt')

    local finished = Completion.split([[checkout my\ file.txt ]])
    assert(vim.deep_equal(finished, { 'checkout', 'my file.txt' }))

    local quoted, rest = Completion.split('"hello world')
    assert(vim.deep_equal(quoted, { '"hello' }))
    assert(rest == 'world')

    local partial, tail = Completion.split([[checkout feat]])
    assert(vim.deep_equal(partial, { 'checkout' }))
    assert(tail == 'feat')
  end)

  test('wraps a provider and escapes spaces in candidates', function()
    local callback = Completion.callback(function()
      return { 'my file', 'other' }
    end)
    assert(vim.deep_equal(callback('my', 'MyGit my', 8), { 'my\\ file' }))
  end)

  test('parses completion-helper output into options, values and words', function()
    local parsed = Discover.parse_helper([[--amend --author= apply drop -- --no-amend]])
    assert(vim.deep_equal(parsed.options, { '--amend', '--author=', '--no-amend' }))
    assert(parsed.values['--author'] == true)
    assert(parsed.values['--amend'] == nil)
    assert(vim.deep_equal(parsed.words, { 'apply', 'drop' }))
  end)

  test('caches discovery per command and version', function()
    local runs = {}
    local discover = Discover.new({
      run = function(argv)
        runs[#runs + 1] = table.concat(argv, ' ')
        if argv[1] == '--version' then
          return 'git version 9.9.9\n'
        elseif argv[1] == '--list-cmds=main,others' then
          return 'status\ncommit\n'
        elseif argv[2] == '--git-completion-helper' then
          return '--amend --author= '
        end
      end,
    })
    assert(vim.deep_equal(discover:subcommands(), { 'status', 'commit' }))
    assert(vim.deep_equal(discover:subcommands(), { 'status', 'commit' }))
    assert(#discover:vocabulary('commit', '/repo').options == 2)
    discover:vocabulary('commit', '/repo')
    local helper_runs = 0
    for _, run in ipairs(runs) do
      if run:find('--git-completion-helper', 1, true) then
        helper_runs = helper_runs + 1
      end
    end
    assert(helper_runs == 1, 'helper output must be cached')
    assert(#runs == 3, vim.inspect(runs))
  end)

  test('reports no vocabulary when Git cannot answer', function()
    local discover = Discover.new({ run = function() end })
    assert(vim.deep_equal(discover:subcommands(), {}))
    local vocabulary = discover:vocabulary('submodule', '/repo')
    assert(vim.deep_equal(vocabulary, { options = {}, values = {}, words = {} }))
  end)

  test('offers subcommands from discovery and global options before them', function()
    local provider = GitCompletion.new({
      cwd = vim.fn.getcwd(),
      discover = fake_discover(),
      sources = { refs = function() end, remotes = function() end, authors = function() end },
    })
    assert(vim.deep_equal(provider({ tokens = {}, arglead = '' }), fake_discover().subcommands()))
    assert(vim.tbl_contains(provider({ tokens = {}, arglead = '--no' }), '--no-pager'))
  end)

  test('offers only the subcommand vocabulary after a subcommand', function()
    local provider = GitCompletion.new({
      cwd = vim.fn.getcwd(),
      discover = fake_discover(),
      sources = { refs = function() end, remotes = function() end, authors = function() end },
    })
    local after = provider({ tokens = { 'commit' }, arglead = '--' })
    assert(vim.tbl_contains(after, '--amend'))
    assert(not vim.tbl_contains(after, '--no-pager'), 'global options must not leak')
    assert(not vim.tbl_contains(after, '--bare'), 'global options must not leak')
  end)

  test('resolves value options to their own candidates instead of paths', function()
    local provider = GitCompletion.new({
      cwd = vim.fn.getcwd(),
      discover = fake_discover(),
      sources = {
        refs = function() end,
        remotes = function() end,
        authors = function()
          return { 'Ada Lovelace', 'Grace Hopper' }
        end,
      },
    })
    -- providers do not filter by prefix; `cli-cmd.completion.callback` does
    assert(vim.deep_equal(provider({ tokens = { 'commit', '--author' }, arglead = 'G' }), {
      'Ada Lovelace',
      'Grace Hopper',
    }))
    assert(vim.deep_equal(provider({ tokens = { 'commit' }, arglead = '--author=G' }), {
      '--author=Ada Lovelace',
      '--author=Grace Hopper',
    }))
    assert(vim.deep_equal(provider({ tokens = { 'commit', '-m' }, arglead = '' }), {}))
  end)

  test('offers static and Git-derived value candidates', function()
    local provider = GitCompletion.new({
      cwd = vim.fn.getcwd(),
      discover = fake_discover(),
      sources = {
        refs = function()
          return { 'feature-one', 'main' }
        end,
        remotes = function()
          return { 'origin' }
        end,
        authors = function() end,
      },
    })
    assert(
      vim.tbl_contains(provider({ tokens = { 'log' }, arglead = '--since=' }), '--since=yesterday')
    )
    assert(
      vim.tbl_contains(
        provider({ tokens = { 'merge' }, arglead = '--strategy=' }),
        '--strategy=ort'
      )
    )
    assert(vim.tbl_contains(provider({ tokens = { 'checkout' }, arglead = 'fe' }), 'feature-one'))
    assert(vim.tbl_contains(provider({ tokens = { 'fetch' }, arglead = '' }), 'origin'))
  end)

  test('uses the position to pick between remote and refspec candidates', function()
    local provider = GitCompletion.new({
      cwd = vim.fn.getcwd(),
      discover = fake_discover(),
      sources = {
        refs = function()
          return { 'main' }
        end,
        remotes = function()
          return { 'origin' }
        end,
        authors = function() end,
      },
    })
    assert(vim.deep_equal(provider({ tokens = { 'push' }, arglead = '' }), { 'origin' }))
    assert(vim.deep_equal(provider({ tokens = { 'push', 'origin' }, arglead = '' }), { 'main' }))
    assert(
      vim.deep_equal(provider({ tokens = { 'push', '--force', 'origin' }, arglead = '' }), {
        'main',
      }),
      'options must not count as positionals'
    )
  end)

  test('returns the words Git reports for a nested subcommand', function()
    local provider = GitCompletion.new({
      cwd = vim.fn.getcwd(),
      discover = fake_discover(),
      sources = { refs = function() end, remotes = function() end, authors = function() end },
    })
    assert(
      vim.deep_equal(provider({ tokens = { 'stash' }, arglead = '' }), { 'apply', 'drop', 'pop' })
    )
  end)

  test('treats -C as the base for paths and stops guessing after --', function()
    local repo = cli_cmd_test.temp_repo()
    local provider = GitCompletion.new({ cwd = repo })
    assert(
      vim.tbl_contains(provider({ tokens = { 'add', '--' }, arglead = 'tracked' }), 'tracked.txt')
    )
    assert(vim.deep_equal(provider({ tokens = { 'status' }, arglead = 'feature' }), {}))
    local nested = vim.fn.tempname()
    vim.fn.mkdir(nested .. '/sub', 'p')
    vim.fn.writefile({ 'x' }, nested .. '/sub/file.txt')
    assert(
      vim.tbl_contains(provider({ tokens = { '-C', nested, 'add' }, arglead = 'sub' }), 'sub/'),
      'paths must resolve against -C'
    )
  end)

  test('uses the real Git vocabulary in a repository and nothing outside one', function()
    local repo = cli_cmd_test.temp_repo()
    local provider = GitCompletion.new({ cwd = repo })
    local commit_options = provider({ tokens = { 'commit' }, arglead = '--am' })
    assert(vim.tbl_contains(commit_options, '--amend'), 'Git reports --amend')
    assert(not vim.tbl_contains(commit_options, '--no-pager'), 'global options must not leak')
    local log_values = provider({ tokens = { 'log' }, arglead = '--author=' })
    assert(#log_values > 0, 'revision authors must be offered')
    assert(vim.tbl_contains(provider({ tokens = { 'stash' }, arglead = '' }), 'pop'))

    local outside = vim.fn.tempname()
    vim.fn.mkdir(outside, 'p')
    local outside_provider = GitCompletion.new({ cwd = outside })
    assert(vim.deep_equal(outside_provider({ tokens = { 'commit' }, arglead = '--am' }), {}))
    assert(vim.deep_equal(outside_provider({ tokens = { 'checkout' }, arglead = 'fe' }), {}))
  end)

  test('offers nothing for a value Git has no vocabulary for, not the option again', function()
    local provider = GitCompletion.new({
      cwd = vim.fn.getcwd(),
      discover = fake_discover(),
      sources = { refs = function() end, remotes = function() end, authors = function() end },
    })
    -- `--grep=` and `--max-count=` are curated as value-taking, and Git itself
    -- reports no candidate vocabulary for either.
    assert(vim.deep_equal(provider({ tokens = { 'log' }, arglead = '--grep=' }), {}))
    assert(vim.deep_equal(provider({ tokens = { 'log' }, arglead = '--grep=fix' }), {}))
    assert(vim.deep_equal(provider({ tokens = { 'log' }, arglead = '--max-count=' }), {}))
    assert(vim.deep_equal(provider({ tokens = { 'log', '--grep' }, arglead = '' }), {}))
    -- A value that does have a source still completes, so the contrast is real.
    assert(
      #provider({ tokens = { 'log' }, arglead = '--author=' }) == 0,
      'the double has no authors'
    )

    local callback = Completion.callback(provider)
    local line = 'Git log --grep='
    assert(vim.deep_equal(callback('--grep=', line, #line), {}))
  end)

  test('asks every candidate source through the one discovery runner', function()
    local asked = {}
    local discover = Discover.new({
      run = function(argv)
        asked[#asked + 1] = table.concat(argv, ' ')
        if argv[1] == 'for-each-ref' then
          return 'main\nfeature/x\n'
        elseif argv[1] == 'remote' then
          return 'origin\n'
        elseif argv[1] == 'log' then
          return 'Ann\nBob\nAnn\n'
        end
      end,
    })
    local provider = GitCompletion.new({ cwd = vim.fn.getcwd(), discover = discover })

    assert(
      vim.deep_equal(provider({ tokens = { 'checkout' }, arglead = '' }), { 'main', 'feature/x' })
    )
    assert(vim.deep_equal(provider({ tokens = { 'push' }, arglead = '' }), { 'origin' }))
    assert(vim.deep_equal(provider({ tokens = { 'log' }, arglead = '--author=' }), {
      '--author=Ann',
      '--author=Bob',
    }))
    for _, argv in ipairs({
      'for-each-ref --format=%(refname:short) refs/heads refs/tags refs/remotes',
      'remote',
      'log --no-merges -n 500 --format=%an',
    }) do
      assert(vim.tbl_contains(asked, argv), argv)
    end
  end)

  test('keeps the curated specification aligned with Git behaviour', function()
    assert(Spec.positionals.checkout == 'refs')
    assert(Spec.positionals.add == 'paths')
    assert(vim.deep_equal(Spec.positionals.push, { 'remotes', 'refs' }))
    assert(Spec.value_kinds['--author'] == 'authors')
    assert(Spec.value_kinds['--since'] == 'dates')
    assert(Spec.value_kinds['--onto'] == 'refs')
    assert(vim.tbl_contains(Spec.extra_options.log, '--oneline'))
    assert(vim.tbl_contains(Spec.global_options, '--no-pager'))
    assert(Spec.global_values['-C'] == 'paths')
  end)
end

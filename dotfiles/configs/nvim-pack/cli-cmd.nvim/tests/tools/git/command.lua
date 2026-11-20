return function(test)
  test('builds a Git command definition and routes native command arguments', function()
    local GitCommand = require('cli-cmd.tools.git.command')
    local seen
    local command = _G.cli_cmd_test.git_command({
      cwd = vim.fn.getcwd(),
      backends = {
        process = function(context, task)
          seen = context
          task:complete({ kind = 'exit', code = 0 })
        end,
      },
      routes = { capture = 'process' },
      fallback = 'process',
    })
    command:register('CliGitProbe', { route_key = GitCommand.route_key })
    vim.cmd([[execute 'CliGitProbe --no-pager -C . status']])
    assert(seen.executable == 'git')
    assert(vim.deep_equal(seen.argv, { '--no-pager', '-C', '.', 'status' }))
    assert(seen.route_key == 'capture')
  end)

  test('preserves custom executable and environment configuration', function()
    local GitCommand = require('cli-cmd.tools.git.command')
    local command = _G.cli_cmd_test.git_command({
      executable = '/usr/bin/git',
      cwd = vim.fn.getcwd(),
      env = { GIT_OPTIONAL_LOCKS = '0' },
      backends = {
        process = function(context, task)
          assert(context.executable == '/usr/bin/git')
          assert(context.env.GIT_OPTIONAL_LOCKS == '0')
          task:complete({ kind = 'exit', code = 0 })
        end,
      },
      routes = { capture = 'process' },
      fallback = 'process',
    })
    command:register('CliGitConfigProbe', { route_key = GitCommand.route_key })
    vim.cmd('CliGitConfigProbe status')
  end)

  test('combines the editor environment with an env function that returns nothing', function()
    local GitCommand = require('cli-cmd.tools.git.command')
    local Command = require('cli-cmd.command')
    local seen
    local command = _G.cli_cmd_test.git_command({
      cwd = vim.fn.getcwd(),
      editor = {
        env = function()
          return { GIT_EDITOR = 'editor' }
        end,
      },
      -- An env function is allowed to return nothing; the editor variables must
      -- still arrive, and the function itself must never be treated as a table.
      env = function()
        return nil
      end,
      backends = {
        process = function(context, task)
          seen = context
          task:complete({ kind = 'exit', code = 0 })
        end,
      },
      routes = { capture = 'process' },
      fallback = 'process',
    })
    assert(command ~= nil)
    command:dispatch({ argv = { 'commit' }, route_key = 'capture' })
    assert(seen.env.GIT_EDITOR == 'editor', vim.inspect(seen.env))
  end)

  test('runs real Git through the default preset: every report lands in a split', function()
    local GitCommand = require('cli-cmd.tools.git.command')
    local repo = _G.cli_cmd_test.temp_repo()
    _G.cli_cmd_test.stage(repo, 'tracked.txt', { 'first' })

    -- No injected presenter: this is the sink a plain `install('git')` gives you.
    local git = _G.cli_cmd_test.git_command({ cwd = repo })
    local tabs_before = #vim.api.nvim_list_tabpages()
    local wins_before = #vim.api.nvim_tabpage_list_wins(0)

    ---Dispatch, read the report out of the split it opened, then close the split.
    local function report_of(argv)
      local task = git:dispatch({ argv = argv, route_key = GitCommand.route_key(argv) })
      vim.wait(10000, function()
        return task:status() == 'finished'
      end, 20)
      assert(task:result().kind == 'exit' and task:result().code == 0, vim.inspect(task:result()))
      assert(
        #vim.api.nvim_tabpage_list_wins(0) == wins_before + 1,
        argv[1] .. ' must open exactly one split'
      )
      local text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
      vim.cmd('close')
      assert(#vim.api.nvim_tabpage_list_wins(0) == wins_before, 'the split is all that goes away')
      return text
    end

    local status = report_of({ 'status', '--short', '--branch' })
    assert(status:find('## ', 1, true), status)

    local log = report_of({ 'log', '-1', '--oneline' })
    assert(log:find('init', 1, true), log)

    for index = 1, 16 do
      local name = string.format('n%02d.txt', index)
      _G.cli_cmd_test.stage(repo, name, { name })
      _G.cli_cmd_test.ok(repo, { 'git', 'commit', '--quiet', '-m', name })
    end
    local long = report_of({ 'log', '--oneline' })
    assert(#vim.split(long, '\n') == 17, long)
    assert(long:find('n16.txt', 1, true), long)

    assert(#vim.api.nvim_list_tabpages() == tabs_before, 'Git reports never open a tab')
  end)
end

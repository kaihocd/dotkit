return function(test)
  local EditorBridge = require('cli.bridge.editor')
  local Git = require('cli.adapter.git')

  test(
    'edits a real commit through the CLI Git command and keeps hooks in natural order',
    function()
      local root = cli_test.temp_repo()
      cli_test.stage(root, 'tracked.txt', { 'hooked change' })
      local log = root .. '/hooks.log'
      local hooks = root .. '/.git/hooks'
      local function hook(name, body)
        local path = hooks .. '/' .. name
        vim.fn.writefile({ '#!/bin/sh', body }, path)
        vim.fn.setfperm(path, 'rwxr-xr-x')
      end
      hook('pre-commit', 'echo pre-commit >> "' .. log .. '"')
      hook('prepare-commit-msg', 'echo prepare-commit-msg >> "' .. log .. '"')
      hook('commit-msg', 'echo commit-msg >> "' .. log .. '"')

      local opened = {}
      local bridge = EditorBridge.new({
        cwd = root,
        open = function(path)
          opened.path = path
          vim.cmd('split ' .. vim.fn.fnameescape(path))
          opened.buf = vim.api.nvim_get_current_buf()
          opened.win = vim.api.nvim_get_current_win()
        end,
      })

      local git = Git.new({ cwd = root, editor = bridge, routes = { capture = 'process' } })
      local task =
        git:dispatch({ argv = { 'commit' }, raw_input = 'commit', route_key = 'capture' })

      vim.wait(15000, function()
        return bridge:active()
      end, 10)
      assert(bridge:active(), 'editor session was never opened')
      assert(task:status() == 'running', 'task must stay running while editing')
      local before = vim.fn.readfile(log)
      assert(
        vim.deep_equal(before, { 'pre-commit', 'prepare-commit-msg' }),
        'hooks must run before the editor: ' .. vim.inspect(before)
      )

      vim.api.nvim_buf_set_lines(opened.buf, 0, -1, false, { 'hooked message' })
      vim.api.nvim_buf_call(opened.buf, function()
        vim.cmd('silent write')
      end)
      vim.api.nvim_win_close(opened.win, true)

      vim.wait(15000, function()
        return task:status() == 'finished'
      end, 10)
      assert(task:status() == 'finished', 'task did not finish after the session closed')
      assert(
        vim.deep_equal(task:result(), { kind = 'exit', code = 0 }),
        'unexpected result: ' .. vim.inspect(task:result())
      )
      assert(
        vim.deep_equal(vim.fn.readfile(log), { 'pre-commit', 'prepare-commit-msg', 'commit-msg' }),
        'commit-msg must run after the editor: ' .. vim.inspect(vim.fn.readfile(log))
      )
      local subject = cli_test.ok(root, { 'git', 'log', '-1', '--pretty=%s' }).stdout
      assert(subject:find('hooked message', 1, true))
      bridge:dispose()
    end
  )

  test('releases Git when Neovim exits with an edit session open', function()
    local root = cli_test.temp_repo()
    cli_test.stage(root, 'tracked.txt', { 'abandoned change' })
    local bridge = EditorBridge.new({
      cwd = root,
      open = function(path)
        vim.cmd('split ' .. vim.fn.fnameescape(path))
      end,
    })
    local git = Git.new({ cwd = root, editor = bridge, routes = { capture = 'process' } })
    local task = git:dispatch({ argv = { 'commit' }, raw_input = 'commit', route_key = 'capture' })
    vim.wait(15000, function()
      return bridge:active()
    end, 10)
    assert(bridge:active(), 'editor session was never opened')

    vim.cmd('doautocmd VimLeavePre')

    vim.wait(15000, function()
      return task:status() == 'finished'
    end, 10)
    assert(task:status() == 'finished', 'Git must be released, not left waiting')
    assert(
      task:result().kind == 'exit' and task:result().code ~= 0,
      'an abandoned edit must not commit: ' .. vim.inspect(task:result())
    )
    assert(not bridge:active())
    assert(
      cli_test.ok(root, { 'git', 'log', '-1', '--pretty=%s' }).stdout:find('abandoned', 1, true)
        == nil,
      'nothing must have been committed'
    )
    bridge:dispose()
  end)

  test('reports a failing hook as a nonzero Git exit through the same task', function()
    local root = cli_test.temp_repo()
    cli_test.stage(root, 'tracked.txt', { 'blocked change' })
    local hook = root .. '/.git/hooks/pre-commit'
    vim.fn.writefile({ '#!/bin/sh', 'echo "hook refused" >&2', 'exit 1' }, hook)
    vim.fn.setfperm(hook, 'rwxr-xr-x')

    local bridge = EditorBridge.new({ cwd = root, open = function() end })
    local git = Git.new({ cwd = root, editor = bridge, routes = { capture = 'process' } })
    local task = git:dispatch({ argv = { 'commit' }, raw_input = 'commit', route_key = 'capture' })
    local diagnostics = {}
    task:on(function(event)
      if event.kind == 'output' then
        diagnostics[#diagnostics + 1] = event.data
      end
    end)

    vim.wait(15000, function()
      return task:status() == 'finished'
    end, 10)
    assert(task:status() == 'finished')
    assert(
      task:result().kind == 'exit' and task:result().code ~= 0,
      'hook failure must surface as nonzero exit'
    )
    assert(
      table.concat(diagnostics, ''):find('hook refused', 1, true),
      'hook stderr must be preserved'
    )
    assert(not bridge:active(), 'no editor session should have opened')
    bridge:dispose()
  end)
end

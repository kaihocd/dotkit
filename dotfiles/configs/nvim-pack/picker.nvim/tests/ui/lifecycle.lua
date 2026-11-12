local lifecycle = require('picker.ui.lifecycle')

return function(test)
  test('closes while focus is still inside, then returns focus', function()
    local origin = vim.api.nvim_get_current_win()
    vim.cmd('split')
    local inside = vim.api.nvim_get_current_win()
    assert(inside ~= origin, 'precondition: a second window owns focus')

    local observed
    local ok = lifecycle.release(origin, true, function()
      observed = vim.api.nvim_get_current_win()
    end)

    assert(ok, 'close is reported as successful')
    assert(observed == inside, 'the popup is destroyed before focus moves')
    assert(vim.api.nvim_get_current_win() == origin, 'focus is handed back')
    vim.api.nvim_win_close(inside, true)
  end)

  test('leaves focus alone when the UI never had it', function()
    local origin = vim.api.nvim_get_current_win()
    vim.cmd('split')
    local current = vim.api.nvim_get_current_win()

    local ok = lifecycle.release(origin, false, function() end)

    assert(ok, 'close succeeded')
    assert(vim.api.nvim_get_current_win() == current, 'focus was not moved')
    vim.api.nvim_win_close(current, true)
  end)

  test('reports a failing close without skipping the focus restore', function()
    local origin = vim.api.nvim_get_current_win()
    vim.cmd('split')
    local inside = vim.api.nvim_get_current_win()

    local ok, problem = lifecycle.release(origin, true, function()
      error('unmount failed', 0)
    end)

    assert(not ok, 'the failure is reported, not raised')
    assert(tostring(problem):find('unmount failed', 1, true), tostring(problem))
    assert(vim.api.nvim_get_current_win() == origin, 'focus is still handed back')
    vim.api.nvim_win_close(inside, true)
  end)

  test('tolerates an origin window that no longer exists', function()
    local ok = lifecycle.release(1, true, function() end)
    assert(ok, 'a stale origin is not an error')
    assert(not vim.api.nvim_win_is_valid(1), 'precondition: window 1 is gone in a headless session')
  end)
end

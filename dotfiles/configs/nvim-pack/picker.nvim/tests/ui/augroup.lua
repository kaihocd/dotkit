local augroup = require('picker.ui.augroup')

return function(test)
  test('registers listeners in its own group and removes them on close', function()
    local fired = 0
    local group = augroup.new('picker:test')
    local id = group._id
    group:create('User', {
      pattern = 'PickerAugroupTest',
      callback = function()
        fired = fired + 1
      end,
    })
    assert(#vim.api.nvim_get_autocmds({ group = id }) == 1, 'listener is registered in the group')

    vim.api.nvim_exec_autocmds('User', { pattern = 'PickerAugroupTest' })
    assert(fired == 1, 'listener fires while the group is open')

    group:close()
    vim.api.nvim_exec_autocmds('User', { pattern = 'PickerAugroupTest' })
    assert(fired == 1, 'listener is gone after close')
    assert(not pcall(vim.api.nvim_get_autocmds, { group = id }), 'the group itself was deleted')
  end)

  test('keeps concurrent invocations from clearing each other', function()
    local first = augroup.new('picker:test')
    local second = augroup.new('picker:test')
    first:create('User', { pattern = 'PickerAugroupFirst', callback = function() end })
    second:create('User', { pattern = 'PickerAugroupSecond', callback = function() end })

    first:close()

    local remaining = vim.api.nvim_get_autocmds({ group = second._id })
    assert(#remaining == 1, 'the second invocation keeps its listener')
    assert(remaining[1].pattern == 'PickerAugroupSecond', remaining[1].pattern)
    second:close()
  end)

  test('closing twice is a no-op and a closed group refuses new listeners', function()
    local group = augroup.new('picker:test')
    group:close()
    assert(pcall(group.close, group), 'closing twice does not raise')

    local ok, problem = pcall(group.create, group, 'User', { callback = function() end })
    assert(not ok, 'a closed group cannot create listeners')
    assert(tostring(problem):find('augroup is closed', 1, true), tostring(problem))
  end)

  test('owns the listener even when the caller names another group', function()
    local other = vim.api.nvim_create_augroup('PickerAugroupOther', { clear = true })
    local group = augroup.new('picker:test')
    group:create('User', {
      pattern = 'PickerAugroupOwned',
      group = other,
      callback = function() end,
    })

    assert(#vim.api.nvim_get_autocmds({ group = group._id }) == 1, 'landed in the invocation group')
    assert(#vim.api.nvim_get_autocmds({ group = other }) == 0, 'the caller group stays empty')

    group:close()
    vim.api.nvim_del_augroup_by_id(other)
  end)
end

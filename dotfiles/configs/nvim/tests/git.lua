-- Standalone integration check: requires mini-git and mini.diff on runtimepath.
vim.opt.runtimepath:append('dotfiles/configs/nvim')
local root = vim.fn.tempname()
vim.fn.mkdir(root, 'p')
local function git(...)
  local command = { 'git', '-C', root }
  vim.list_extend(command, { ... })
  local result = vim.system(command, { text = true }):wait()
  assert(result.code == 0, result.stderr)
  return result.stdout
end
local ok, err = xpcall(function()
  git('init', '-b', 'test-branch')
  vim.fn.writefile({ 'one', 'two', 'three' }, root .. '/file.txt')
  git('add', 'file.txt')
  git('-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '-m', 'Initial')
  vim.cmd.edit(root .. '/file.txt')
  for _, spec in ipairs(require('plugins.git')) do
    spec.config(spec.opts or {})
  end
  assert(vim.fn.exists(':Git') == 2)
  assert(
    vim.wait(5000, function()
      return (vim.b.minigit_summary or {}).head_name == 'test-branch'
    end),
    'mini.git did not track branch'
  )
  local diff = require('mini.diff')
  assert(
    vim.wait(5000, function()
      local data = diff.get_buf_data(0)
      return data and data.ref_text ~= nil
    end),
    'mini.diff did not attach'
  )
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'one', 'added A', 'added B', 'two', 'three' })
  assert(
    vim.wait(5000, function()
      return #diff.get_buf_data(0).hunks > 0
    end),
    'mini.diff did not detect changes'
  )

  -- Exercise the actual Visual mapping: only one line of a two-line addition.
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.cmd('normal! V')
  vim.fn.maparg('<leader>hs', 'x', false, true).callback()
  vim.cmd('execute "normal! \\<Esc>"')
  assert(
    vim.wait(5000, function()
      return git('show', ':file.txt') == 'one\nadded A\ntwo\nthree\n'
    end),
    'visual staging included unselected lines'
  )
  assert(
    vim.wait(5000, function()
      local data = diff.get_buf_data(0)
      return data.ref_text == 'one\nadded A\ntwo\nthree\n'
        and #data.hunks == 1
        and data.hunks[1].buf_start == 3
        and data.hunks[1].buf_count == 1
    end),
    'reference did not refresh'
  )
  vim.api.nvim_win_set_cursor(0, { 3, 0 })
  vim.fn.maparg('<leader>hs', 'n', false, true).callback()
  assert(
    vim.wait(5000, function()
      return git('show', ':file.txt') == 'one\nadded A\nadded B\ntwo\nthree\n'
    end),
    'normal hunk staging failed'
  )
  assert(vim.fn.maparg('G', 'c', true) == 'Git')
  assert(vim.fn.maparg('<leader>hr', 'x') ~= '')
  assert(vim.fn.maparg('<leader>hb', 'n') == '')
  assert(vim.fn.maparg('<leader>gB', 'n') == '')
  assert(package.loaded.gitsigns == nil)
end, debug.traceback)
vim.cmd('bwipeout!')
vim.fn.delete(root, 'rf')
assert(ok, err)
print('Git integration checks passed')

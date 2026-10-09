local api = vim.api
local root = vim.fn.getcwd()
vim.opt.runtimepath:prepend(root .. '/dotfiles/configs/nvim')
vim.opt.runtimepath:prepend(root .. '/dotfiles/configs/nvim-pack/popup.nvim')
local oil_path = assert(vim.env.OIL_TEST_PATH, 'OIL_TEST_PATH must point to an installed oil.nvim')
assert(vim.fn.filereadable(oil_path .. '/lua/oil/init.lua') == 1)
vim.opt.runtimepath:prepend(oil_path)
local oil = require('oil')
oil.setup({ columns = {}, watch_for_changes = false })
require('popup').group('oil-integration', {})
local dir = vim.fn.tempname()
vim.fn.mkdir(dir .. '/child', 'p')
vim.fn.writefile({ 'original', 'second line' }, dir .. '/sample.txt')
vim.cmd.cd(vim.fn.fnameescape(dir))
local Adapter = require('plugins.explorer.oil.adapter')
local adapter = Adapter.new({
  min_pane_size = 3,
  border = 'solid',
  group = 'oil-integration',
  geometry = function()
    return { width = 50, height = 10, row = 1, col = 1 }
  end,
  oil_title = function()
    return { title = 'Oil' }
  end,
  preview_title = function()
    return { title = 'Preview' }
  end,
  keymaps = {},
  oil_win_options = {},
  preview_win_options = {},
})
local origin = api.nvim_get_current_win()
local function choose(name)
  assert(
    vim.wait(2000, function()
      for row in ipairs(api.nvim_buf_get_lines(0, 0, -1, false)) do
        local entry = oil.get_entry_on_line(0, row)
        if entry and entry.name == name then
          api.nvim_win_set_cursor(0, { row, 0 })
          return true
        end
      end
      return false
    end),
    'entry unavailable: ' .. name
  )
end
local ok, err = xpcall(function()
  adapter:toggle()
  choose('sample.txt')
  adapter:preview()
  assert(api.nvim_get_current_win() == adapter.active.win, 'preview stole focus')
  local file = vim.fn.bufnr(dir .. '/sample.txt')
  assert(file ~= -1)
  api.nvim_buf_set_lines(file, 0, 1, false, { 'unsaved' })
  adapter:scroll_preview('down')
  adapter:preview()
  adapter:preview()
  assert(api.nvim_buf_get_lines(file, 0, 1, false)[1] == 'unsaved')
  adapter:select()
  assert(vim.wait(2000, function()
    return adapter.active == nil
  end))
  assert(api.nvim_get_current_win() == origin and api.nvim_get_current_buf() == file)
  assert(#api.nvim_list_wins() == 1)
  vim.bo[file].modified = false
  adapter:toggle()
  choose('child')
  adapter:select()
  assert(vim.wait(2000, function()
    local current = oil.get_current_dir()
    return current ~= nil and current:find('/child/', 1, true) ~= nil
  end))
  assert(adapter.active ~= nil, 'directory selection closed panel')
  adapter:close()
  assert(#api.nvim_list_wins() == 1)
  for _, opts in ipairs({ { vertical = true }, { horizontal = true }, { tab = true } }) do
    api.nvim_set_current_win(origin)
    api.nvim_win_set_buf(origin, file)
    adapter:toggle()
    choose('sample.txt')
    adapter:select(opts)
    assert(vim.wait(2000, function()
      return adapter.active == nil
    end))
    assert(api.nvim_get_current_buf() == file)
    assert(api.nvim_get_current_win() ~= origin, 'split/tab did not create a destination')
    vim.cmd.close()
  end
  assert(#api.nvim_list_wins() == 1)
end, debug.traceback)
vim.fn.delete(dir, 'rf')
assert(ok, err)
print('PASS real Oil directory navigation, file selection, preview reuse and focus')

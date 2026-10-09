-- Run with fff v0.10.6 and its matching binary on runtimepath; no user config needed.
local api = vim.api
local root = vim.fn.tempname()
for _, dir in ipairs({ 'one', 'two' }) do
  vim.fn.mkdir(root .. '/' .. dir, 'p')
end
vim.fn.writefile({ 'one' }, root .. '/one/alpha.lua')
vim.fn.writefile({ 'two' }, root .. '/two/bravo.lua')

local fff = require('fff')
fff.setup({
  base_path = root .. '/one',
  frecency = { db_path = root .. '/frequency' },
  history = { db_path = root .. '/history' },
})

local function search(query, cwd)
  local source = require('plugins.explorer.picker.search.files').new(cwd)
  local result
  assert(
    vim.wait(5000, function()
      result = source.search(query)
      if result.status == 'indexing' then
        assert(#result.items == 0, 'Indexing must not expose stale results')
      end
      return result.status == 'ready'
    end, 20),
    'Index did not become ready'
  )
  return result
end

local first = search('alpha', root .. '/one')
assert(#first.items == 1 and first.items[1].display == 'alpha.lua')
local second = search('bravo', root .. '/two')
assert(#second.items == 1 and second.items[1].display == 'bravo.lua')
assert(#search('zzzzzzzzzzzzzzzzzzzz', root .. '/two').items == 0)
assert(#search('', root .. '/two').items == 1)
assert(#api.nvim_list_wins() == 1)
assert(package.loaded['fff.picker_ui'] == nil)
assert(#api.nvim_get_autocmds({ group = 'fff_file_tracking', event = 'BufEnter' }) == 1)

-- Opening a file should be counted by fff itself, not by the future Picker.
vim.cmd.edit(vim.fn.fnameescape(root .. '/two/bravo.lua'))
assert(
  vim.wait(5000, function()
    local health = require('fff.rust').health_check(root .. '/two')
    return health.frecency.db_healthcheck.absolute_frecency_entries > 0
  end, 20),
  'File access was not recorded'
)
print('PASS fff backend')
vim.cmd('qa!')

vim.opt.runtimepath:prepend(vim.fn.getcwd())
local config = require('picker.config')
local picker = require('picker')
assert(not pcall(picker.open))
assert(not pcall(picker.select, {}, {}, function() end))
assert(not pcall(picker.resume))

local ok, problem = pcall(config.resolve, 'picker')
assert(not ok and tostring(problem):find('setup', 1, true))

config.setup({ picker = { view = { layout = { width_ratio = 0.8 } } } })
local resolved = config.resolve('picker', { view = { layout = { height_ratio = 0.6 } } })
assert(resolved.view.layout.width_ratio == 0.8)
assert(resolved.view.layout.height_ratio == 0.6)
assert(config.resolve('picker').view.layout.height_ratio == 0.75)
local input = { picker = { view = { layout = { width_ratio = 0.9 } } } }
config.setup(input)
input.picker.view.layout.width_ratio = 0.1
resolved = config.resolve('picker')
resolved.view.layout.width_ratio = 0.2
assert(config.resolve('picker').view.layout.width_ratio == 0.9)

for _, invalid in ipairs({
  false,
  { unknown = {} },
  { picker = { view = { layout = { width_ratio = 0 } } } },
  { select = { view = { min_items = 10, max_items = 2 } } },
}) do
  assert(not pcall(config.setup, invalid))
  assert(config.resolve('picker').view.layout.width_ratio == 0.9)
end
assert(not pcall(config.resolve, 'picker', { view = { layout = { height_ratio = 2 } } }))
assert(not pcall(config.resolve, 'unknown'))
config.setup()
assert(config.resolve('picker').view.layout.width_ratio == 0.75)
assert(config.resolve('select').view.max_items == 8)
local action = function() end
config.setup({
  picker = {
    keymaps = { i = { ['<CR>'] = false, ['<F6>'] = action } },
    preview = { max_files = 4 },
    search = { debounce_ms = 0 },
  },
})
resolved = config.resolve('picker', { keymaps = { n = { ['<F7>'] = 'confirm' } } })
assert(resolved.keymaps.i['<CR>'] == false)
assert(resolved.keymaps.i['<F6>'] == action)
assert(resolved.keymaps.n['<CR>'] == 'confirm')
assert(resolved.keymaps.n['<F7>'] == 'confirm')
assert(config.resolve('picker').keymaps.n['<F7>'] == nil)
assert(resolved.preview.max_files == 4 and resolved.preview.max_bytes == 8 * 1024 * 1024)
assert(resolved.search.debounce_ms == 0)
for _, overrides in ipairs({
  { keymaps = { bad = {} } },
  { keymaps = { n = { ['x'] = true } } },
  { preview = { max_files = 0 } },
  { search = { debounce_ms = -1 } },
}) do
  assert(not pcall(config.resolve, 'picker', overrides))
end
config.setup()
assert(config.resolve('picker').keymaps.i['<CR>'] == 'confirm')
assert(config.resolve('picker').keymaps.i['<F6>'] == nil)
local builder = function(panes)
  return panes.input
end
config.setup({ picker = { view = { layout = { width_ratio = 0.8, build = builder } } } })
resolved = config.resolve('picker', { view = { layout = { height_ratio = 0.6 } } })
assert(resolved.view.layout.build == builder and resolved.view.layout.width_ratio == 0.8)
resolved = config.resolve('picker', { view = { layout = builder } })
assert(resolved.view.layout.build == builder and resolved.view.layout.height_ratio == 0.75)
---@diagnostic disable-next-line: assign-type-mismatch
assert(not pcall(config.setup, { picker = { view = { layout = { build = true } } } }))
assert(config.resolve('picker').view.layout.build == builder)
config.setup({
  select = {
    view = { prefix = { margin = { 2, 3 }, highlight = 'Title' }, layout = builder },
    keymaps = { i = { ['<CR>'] = false } },
  },
})
local select_resolved = config.resolve('select', { view = { prefix = { margin = { 4, 5 } } } })
assert(vim.deep_equal(select_resolved.view.prefix.margin, { 4, 5 }))
assert(
  select_resolved.view.prefix.text == ' Select '
    and select_resolved.view.prefix.highlight == 'Title'
)
assert(select_resolved.view.layout == builder)
assert(
  select_resolved.keymaps.i['<CR>'] == false and select_resolved.keymaps.n['<CR>'] == 'confirm'
)
assert(vim.deep_equal(config.resolve('select').view.prefix.margin, { 2, 3 }))
assert(not pcall(config.resolve, 'select', { view = { prefix = { margin = { 1 } } } }))
assert(not pcall(config.resolve, 'select', { view = { padding = { left = -1 } } }))
---@diagnostic disable-next-line: assign-type-mismatch
assert(not pcall(config.resolve, 'select', { view = { layout = {} } }))
config.setup()
assert(config.resolve('select').view.layout == nil)
config.setup({ picker = { view = { presentation = { row = { match = 'IncSearch' } } } } })
local files = config.resolve('picker')
local grep = config.resolve('picker', nil, 'grep')
assert(files.view.presentation.prefix.text == ' Files ')
assert(grep.view.presentation.prefix.text == ' Grep ')
assert(grep.view.presentation.row.match == 'IncSearch')
assert(
  not pcall(config.setup, { picker = { view = { presentation = { marker = { text = 'wide' } } } } })
)
assert(config.resolve('picker').view.presentation.row.match == 'IncSearch')
config.setup()
assert(files.view.presentation.row.match == 'IncSearch')
picker.setup({
  picker = { view = { icon = false, signs = { git = { modified = { '|', 'Title' } } } } },
})
local invocation = require('picker.picker.options').resolve({})
assert(invocation.view.icon == false)
assert(vim.deep_equal(invocation.view.signs.git.modified, { '|', 'Title' }))
assert(not pcall(picker.setup, { picker = { view = { signs = { staged_foreground_ratio = 2 } } } }))
assert(
  not pcall(
    picker.setup,
    { picker = { view = { signs = { git = { modified = { 'wide', 'Title' } } } } } }
  )
)
assert(config.resolve('picker').view.signs.git.modified[1] == '|')
print('PASS configuration precedence, isolation, validation, keymaps and normalized layout')

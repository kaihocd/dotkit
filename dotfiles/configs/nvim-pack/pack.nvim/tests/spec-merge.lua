local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
vim.opt.runtimepath:prepend(root)
local spec = require('pack.spec')
local first = {
  src = 'a',
  opts = { menu = { border = 'single', enabled = true }, sources = { 'lsp', 'path' } },
  event = 'UIEnter',
  deps = { { src = 'b' } },
  config = function() end,
}
local second = {
  src = 'a',
  opts = { menu = { border = 'rounded' }, sources = { 'buffer' } },
  event = { 'UIEnter', 'InsertEnter' },
  ft = 'lua',
  config = false,
  main = 'entry',
  version = 'main',
  deps = { { src = 'b', opts = { enabled = true } }, { src = 'c' } },
}
local state = spec.build({ first, second, { src = 'a', ft = { 'lua', 'python' } } })
local a = state.registry.a
assert(a.config == false and a.main == 'entry' and a.version == 'main')
assert(
  vim.deep_equal(a.opts, { menu = { border = 'rounded', enabled = true }, sources = { 'buffer' } })
)
assert(vim.deep_equal(a.dependencies, { 'b', 'c' }))
assert(vim.deep_equal(a.event, { 'UIEnter', 'InsertEnter' }))
assert(vim.deep_equal(a.ft, { 'lua', 'python' }))
assert(state.registry.b.opts.enabled)
assert(first.opts.menu.border == 'single' and #first.opts.sources == 2)
assert(#spec.select(state) == 3)
local custom = function() end
assert(
  spec.build({ { src = 'a', config = false }, { src = 'a', config = custom } }).registry.a.config
    == custom
)
assert(
  not pcall(
    spec.build,
    { { src = 'a', deps = { { src = 'b' } } }, { src = 'b', deps = { { src = 'a' } } } }
  )
)
assert(not pcall(spec.build, { { src = 'a', name = 'same' }, { src = 'b', name = 'same' } }))
assert(spec.build({ { src = 'a' }, { src = 'a' } }).registry.a.opts == nil)
print('PASS Pack spec merging: options, lists, dependencies, overrides, immutability and cycles')

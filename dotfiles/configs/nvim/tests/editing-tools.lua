local root = vim.fn.getcwd()
vim.opt.runtimepath:prepend(root .. '/dotfiles/configs/nvim')
vim.opt.runtimepath:prepend(root .. '/dotfiles/configs/nvim-pack/pack.nvim')
_G.G = { local_plugins_root = root .. '/dotfiles/configs/nvim-pack' }
local installed = assert(vim.env.EDITING_TEST_ROOT)
for _, name in ipairs({ 'guess-indent.nvim', 'nvim-origami', 'conform.nvim' }) do
  vim.opt.runtimepath:append(installed .. '/' .. name)
end
vim.opt.runtimepath:append(assert(vim.env.CONTEXT_TEST_PATH))
local specs = {}
for _, feature in ipairs({ 'ui', 'editing', 'devtool' }) do
  vim.list_extend(specs, require('plugins.' .. feature))
end
local state = require('pack.spec').build(specs)
for _, name in ipairs({
  'guess-indent.nvim',
  'nvim-origami',
  'nvim-treesitter-context',
  'conform.nvim',
}) do
  local spec = assert(state.registry[name])
  if spec.config then
    spec.config(spec.opts)
  else
    require(spec.main or name:gsub('%.nvim$', '')).setup(spec.opts or {})
  end
end
assert(vim.o.foldlevel == 99 and vim.o.foldlevelstart == 99)
assert(vim.fn.maparg('[c', 'n') ~= '')
assert(vim.fn.maparg('<leader>lf', 'n') ~= '')
local conform = require('conform')
assert(conform.formatters_by_ft.lua[1] == 'stylua')
assert(conform.formatters_by_ft.sh[1] == 'shfmt')
-- Exercise the real BufWritePre path with a deterministic local formatter.
conform.formatters.dotkit_test = { command = 'sh', args = { '-c', "tr 'a-z' 'A-Z'" }, stdin = true }
conform.formatters_by_ft.dotkit_test = { 'dotkit_test' }
local file = vim.fn.tempname()
vim.cmd.edit(file)
vim.bo.filetype = 'dotkit_test'
vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'hello' })
vim.cmd.write()
assert(vim.fn.readfile(file)[1] == 'hello', 'save formatting must default to off')
vim.cmd.ToggleFormatOnSave()
vim.cmd.write()
assert(vim.fn.readfile(file)[1] == 'HELLO', 'formatting must finish before saving')
vim.cmd.ToggleFormatOnSave()
vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'again' })
vim.cmd.write()
assert(vim.fn.readfile(file)[1] == 'again')
vim.fn.delete(file)
print('PASS four migrated plugins: real setup, mappings, formatter routing and save toggle')

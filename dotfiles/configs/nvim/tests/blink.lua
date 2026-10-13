local root = vim.fn.getcwd()
vim.opt.runtimepath:prepend(root .. '/dotfiles/configs/nvim')
local plugin_root =
  assert(vim.env.BLINK_TEST_ROOT, 'BLINK_TEST_ROOT must contain the installed Blink dependencies')
for _, name in ipairs({ 'blink.lib', 'blink.cmp', 'friendly-snippets', 'colorful-menu.nvim' }) do
  local path = vim.fs.joinpath(plugin_root, name)
  assert(vim.fn.isdirectory(path) == 1, 'missing dependency: ' .. path)
  vim.opt.runtimepath:append(path)
end
vim.opt.runtimepath:prepend(root .. '/dotfiles/configs/nvim-pack/pack.nvim')
_G.G = { local_plugins_root = root .. '/dotfiles/configs/nvim-pack' }
local specs = {}
vim.list_extend(specs, require('plugins.ui'))
vim.list_extend(specs, require('plugins.editing'))
vim.list_extend(specs, require('plugins.devtool'))
local spec = require('pack.spec').build(specs).registry['blink.cmp']
assert(spec.version == 'main')
assert(vim.deep_equal(spec.event, { 'UIEnter' }))
for _, name in ipairs({ 'blink.lib', 'friendly-snippets', 'colorful-menu.nvim' }) do
  assert(vim.tbl_contains(spec.dependencies, name), 'missing merged dependency: ' .. name)
end
assert(spec.opts.completion.menu.draw.components.label.text)
vim.o.winborder = 'single'
local cmp = require('blink.cmp')
cmp.setup(spec.opts)
vim.opt.runtimepath:prepend(root .. '/dotfiles/configs/nvim-pack/picker.nvim')
vim.opt.runtimepath:prepend(root .. '/dotfiles/configs/nvim-pack/popup.nvim')
assert(cmp.is_enabled(), 'Blink should remain enabled in ordinary buffers')
require('picker').setup()
local picker_window =
  require('picker.picker.window').new(require('picker.picker.options').resolve({}).view)
picker_window:open()
local picker_input = assert(picker_window:pane('input'))
assert(not cmp.is_enabled(), 'Blink must respect the Picker prompt buffer')
vim.api.nvim_feedkeys(vim.keycode('ihello<BS>p<Esc>'), 'xt', false)
assert(picker_window:query() == 'hellp', 'prompt must retain normal typing and backspace')
picker_window:restore_query('中文', false)
assert(picker_window:query() == '中文')
picker_window:resize()
assert(vim.bo[picker_input.buf].buftype == 'prompt' and not cmp.is_enabled())
picker_window:close()
assert(cmp.is_enabled(), 'closing Picker must not disable ordinary completion')
local config = require('blink.cmp.config')
assert(config.keymap.preset == 'default')
assert(config.keymap['<C-j>'][1] == 'select_and_accept')
assert(config.keymap['<C-y>'] == false)
assert(config.keymap['<C-h>'][1] == 'snippet_backward')
assert(config.keymap['<C-l>'][1] == 'snippet_forward')
assert(config.cmdline.keymap.preset == 'inherit')
local cmdline_config = config.get({ mode = 'cmdline' })
assert(cmdline_config.completion.list.selection.preselect == true)
assert(cmdline_config.completion.list.selection.auto_insert == false)
assert(vim.deep_equal(cmdline_config.completion.list.selection, config.completion.list.selection))
assert(config.appearance.kind_icons.Function == '󰡱')
assert(config.appearance.kind_icons.Variable == '')
local base24 = {}
for index = 0, 23 do
  base24[('base%02X'):format(index)] = '#888888'
end
local semantic = require('palette.colors').semantic({
  id = 'blink-test',
  name = 'Blink test',
  variant = 'dark',
  palette = base24,
})
semantic.fgBright, semantic.fgDim = '#eeeeee', '#888888'
local palette_groups = require('palette.hl-groups.plugins')(semantic)
for name, value in pairs(palette_groups) do
  if name:match('^BlinkCmp') then
    vim.api.nvim_set_hl(0, name, value)
  end
end
assert(vim.api.nvim_get_hl(0, { name = 'BlinkCmpDoc', link = false }).bg == nil)
assert(vim.api.nvim_get_hl(0, { name = 'BlinkCmpMenuSelection' }).link == 'Visual')
-- Exercise real Blink windows with the final config, not only setup validation.
local Window = require('blink.cmp.lib.window')
for _, options in ipairs({
  config.completion.menu,
  config.completion.documentation.window,
  config.signature.window,
}) do
  local window = Window.new('dotkit-blink-test', {
    filetype = 'blink-test',
    border = options.border,
    winhighlight = options.winhighlight,
  })
  vim.api.nvim_buf_set_lines(window:get_buf(), 0, -1, false, { 'Test content' })
  window:open()
  local win = window:get_win()
  assert(vim.wo[win].winhighlight == options.winhighlight)
  local border = vim.api.nvim_win_get_config(win).border
  assert(border and #border == 8, 'expected inherited single border')
  assert(border[1] == '┌' or (type(border[1]) == 'table' and border[1][1] == '┌'))
  local buf = window:get_buf()
  window:close()
  if vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end
end
local capabilities = cmp.get_lsp_capabilities()
assert(capabilities.textDocument.completion.completionItem.snippetSupport)
vim.lsp.config('*', { capabilities = capabilities })
assert(vim.lsp.config['*'].capabilities.textDocument.completion.completionItem.snippetSupport)
local mappings = require('blink.cmp.keymap').mappings
assert(mappings.default['<c-j>'][1] == 'select_and_accept')
assert(mappings.cmdline['<c-j>'][1] == 'select_and_accept')
assert(mappings.default['<tab>'][1] == 'snippet_forward')
local presets = require('blink.cmp.keymap.presets')
assert(presets.get('default')['<Tab>'][1] == 'snippet_forward')
assert(presets.get('default')['<S-Tab>'][1] == 'snippet_backward')
print(
  'PASS Blink v2 setup, merged UI, default/snippet keymaps, C-j acceptance and LSP capabilities'
)

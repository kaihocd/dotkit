local api = vim.api
local original_select, original_input = vim.ui.select, vim.ui.input
local ui = require('native-ui')
assert(vim.ui.select == original_select and vim.ui.input == original_input)
assert(package.loaded.popup == nil, 'Importing the component must not load popup')
local popup = require('popup')
local baseline = #api.nvim_list_wins()
local supplied = api.nvim_create_buf(false, true)
local options = {
  input = {
    id = 'search',
    buf = supplied,
    enter = false,
    border = 'double',
    win_config = { title = 'Custom', title_pos = 'right', focusable = false },
  },
  list = {
    id = 'choices',
    border = { '', '', '', '', '', '', '', '' },
    win_config = { focusable = true },
  },
  layout = { gap = 1 },
  prefix = { text = ' Pick ', highlight = 'WarningMsg' },
  gap = { text = '  ', highlight = 'Normal' },
}
local snapshot = vim.deepcopy(options)
local panel = ui.InputList.new(options)
local root = popup
  .root({ row = 1, col = 2, width = 40, height = 10, zindex = 80, layout = panel:layout() })
  :open()
panel:attach(root)
assert(vim.deep_equal(options, snapshot), 'Overrides must not be mutated')
assert(panel.input.buf == supplied)
local input = api.nvim_win_get_config(panel.input.win)
assert(input.border[2] == '═' and input.title_pos == 'right' and not input.focusable)
assert(api.nvim_win_get_config(panel.list.win).focusable)
assert(api.nvim_get_current_win() ~= panel.input.win)
local ns = api.nvim_create_namespace('NativeInputList')
local mark = api.nvim_buf_get_extmark_by_id(supplied, ns, 1, { details = true })
assert(vim.deep_equal(mark[3].virt_text, { { ' Pick ', 'WarningMsg' }, { '  ', 'Normal' } }))
vim.bo[supplied].modifiable = true
api.nvim_buf_set_lines(supplied, 0, -1, false, { 'query' })
assert(panel:text() == 'query')
panel:set_prefix({ text = ' Changed ' })
panel:set_status('3 items', 'Number')
assert(
  api.nvim_buf_get_extmark_by_id(supplied, ns, 2, { details = true })[3].virt_text[1][2] == 'Number'
)
local node = panel:layout({ list = { border = 'single' } })
assert(node.children[2].border == 'single')
assert(panel:layout().children[2].border[2] == '', 'Per-render overrides must not persist')
root:close()
assert(api.nvim_buf_is_valid(supplied), 'Caller-owned buffer must survive')
api.nvim_buf_delete(supplied, { force = true })
local fresh = ui.InputList.new()
assert(fresh:layout().children[2].win_config.focusable == false, 'Defaults must remain unchanged')
assert(#api.nvim_list_wins() == baseline)
print('PASS InputList native overrides, composition, content and import isolation')
vim.cmd('qa!')

local api = vim.api
local config = vim.deepcopy(require('plugins.explorer.picker.config').view)
config.preview.enabled = false
local original_windows = #api.nvim_list_wins()
local closed = 0
local view = require('plugins.explorer.picker.view').open('Files', function()
  closed = closed + 1
end, config)
local function prompt_text(buf)
  local namespace = api.nvim_create_namespace('NativeInputList')
  local mark = api.nvim_buf_get_extmark_by_id(buf, namespace, 1, { details = true })
  assert(mark[3].virt_text[1][2] == 'FloatTitle')
  assert(mark[3].virt_text[2][1] == ' ')
  assert(mark[3].virt_text[2][2] == 'NormalFloat')
  return mark[3].virt_text[1][1]
end
assert(prompt_text(view.query.buf) == ' Files ')
local query, results = view.query.win, view.results.win
assert(vim.wo[query].winhighlight:find('Normal:NormalFloat', 1, true))
assert(vim.wo[query].winhighlight:find('NormalNC:NormalFloat', 1, true))
assert(vim.wo[results].winhighlight:find('Normal:NormalFloat', 1, true))
assert(#api.nvim_list_wins() == original_windows + 3, 'One root and two left panes')
local q = api.nvim_win_get_config(query)
local r = api.nvim_win_get_config(results)
assert(q.border[2] == '─' and q.border[6] == '')
assert(not q.title)
assert(r.border[2] == '─' and r.border[6] == '─')
assert(r.border[1] == '├' and r.border[3] == '┤')
assert(not r.title, 'Results must not have a title')
assert(r.focusable == false, 'Results must not accept normal window navigation')
vim.cmd.wincmd('w')
assert(api.nvim_get_current_win() ~= results, 'Window navigation must skip results')
api.nvim_set_current_win(query)
assert(r.row == q.row + q.height + 1, 'Input and list must share one separator')
assert(q.col == r.col and q.width == r.width)
api.nvim_buf_set_lines(view.query.buf, 0, -1, false, { 'keep query' })
for _, columns in ipairs({ 240, 100, 240 }) do
  vim.o.columns = columns
  view.resize()
  for _ = 1, 2 do
    view.toggle_preview()
    assert(view.preview_pane())
    local p = api.nvim_win_get_config(view.preview_pane().win)
    local list_config = api.nvim_win_get_config(results)
    local stacked = p.row > list_config.row
    assert(p.border[1] == (stacked and '├' or '┌') and p.border[6] == '─')
    assert(list_config.border[6] == (stacked and '' or '─'))
    assert(not p.title)
    view.toggle_preview()
    assert(not view.preview_pane())
    assert(closed == 0, 'Removing preview must not close the popup')
    assert(view.query.win == query and api.nvim_win_is_valid(query))
    assert(view.results.win == results and api.nvim_win_is_valid(results))
    assert(view.query_text() == 'keep query')
    assert(#api.nvim_list_wins() == original_windows + 3)
  end
  q = api.nvim_win_get_config(query)
  r = api.nvim_win_get_config(results)
  assert(r.row == q.row + q.height + 1)
  assert(q.col == r.col and q.width == r.width)
  assert(r.focusable == false)
end
api.nvim_win_close(results, true)
assert(closed == 1, 'Closing an owned pane must close the popup')
assert(#api.nvim_list_wins() == original_windows)
local grep = require('plugins.explorer.picker.view').open('Grep', function() end, config)
assert(prompt_text(grep.query.buf) == ' Grep ')
grep.close()
assert(#api.nvim_list_wins() == original_windows)
print(
  'PASS picker view: mode prompts, joined input/list, no titles, resize, preview toggle and close'
)
vim.cmd('qa!')

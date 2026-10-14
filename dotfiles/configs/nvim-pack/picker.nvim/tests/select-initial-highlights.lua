vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.env.POPUP_NVIM_PATH or '../popup.nvim')
for _, custom in ipairs({ false, true }) do
  local instance
  require('picker').setup()
  require('picker').select({ 'Apple', 'Banana' }, {
    on_instance = function(value)
      instance = value
    end,
    view = custom and {
      format = function(_, context)
        return { content = { { context.text, 'Title' } } }
      end,
    } or nil,
  }, function() end)
  local list = assert(instance:pane('list'))
  local input = assert(instance:pane('input'))
  local ns = vim.api.nvim_get_namespaces().PickerList
  local function item_marks()
    local result = {}
    for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(list.buf, ns, 0, -1, { details = true })) do
      if mark[2] >= 0 then
        result[#result + 1] = { mark[2], mark[3], mark[4].end_col, mark[4].hl_group }
      end
    end
    return result
  end
  local original = item_marks()
  assert(#original == 2, 'initial mount discarded formatted highlights')
  assert(original[1][4] == (custom and 'Title' or 'Comment'))
  local function query(text, count)
    vim.api.nvim_buf_set_lines(input.buf, 0, -1, false, { text })
    vim.api.nvim_exec_autocmds('TextChangedI', { buffer = input.buf })
    assert(vim.wait(1000, function()
      return vim.api.nvim_buf_line_count(list.buf) == count
    end))
  end
  query('\t', 1)
  query('', 2)
  assert(vim.deep_equal(item_marks(), original), 'filter restoration changed row highlights')
  vim.fn.maparg('<Esc>', 'i', false, true).callback()
  assert(vim.wait(1000, function()
    return #vim.api.nvim_list_wins() == 1
  end))
end
print('PASS public Select initial and restored default/custom segment highlights agree')

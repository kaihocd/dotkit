vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.env.POPUP_NVIM_PATH or '../popup.nvim')
local path = vim.fn.tempname() .. '.lua'
local line = '\tlocal 中文 = "needle"'
vim.fn.writefile({ '-- header', line }, path)
local first = assert(line:find('needle', 1, true)) - 1
package.loaded['picker.picker.backend.fff'] = {
  grep = function()
    return {
      search = function()
        return {
          status = 'ready',
          total = 1,
          items = {
            {
              path = path,
              display = 'fixture.lua',
              line = 2,
              col = first + 1,
              content = line,
              content_matches = { { first, first + 6 } },
            },
          },
        }
      end,
    }
  end,
}
require('picker').setup()
local picker = require('picker')
for _, highlight in ipairs({ 'Search', 'IncSearch' }) do
  local instance
  picker.open({
    mode = 'grep',
    on_instance = function(value)
      instance = value
    end,
    view = { icon = false, presentation = { row = { match = highlight } } },
  })
  assert(instance)
  local namespaces = vim.api.nvim_get_namespaces()
  local input, list, preview
  input = instance:pane('input')
  list = instance:pane('list')
  assert(input and list)
  local prefix =
    vim.api.nvim_buf_get_extmarks(input.buf, namespaces.PickerInput, 0, -1, { details = true })
  assert(prefix[1][4].virt_text[2][1] == ' Grep ', 'public grep resolved the files prefix')
  local rows = vim.api.nvim_buf_get_lines(list.buf, 0, -1, false)
  assert(rows[2]:find('needle', 1, true), 'public grep rendered a filename instead of the hit')
  vim.fn.maparg('<C-o>', 'i', false, true).callback()
  preview = instance:pane('preview')
  assert(preview)
  assert(vim.wait(2000, function()
    return vim.api.nvim_buf_get_lines(preview.buf, 1, 2, false)[1] == line
  end))
  local marks = vim.api.nvim_buf_get_extmarks(
    preview.buf,
    namespaces.PickerPreviewMatches,
    0,
    -1,
    { details = true }
  )
  assert(
    #marks == 1 and marks[1][2] == 1 and marks[1][3] == first and marks[1][4].end_col == first + 6
  )
  assert(marks[1][4].hl_group == highlight, 'preview and list match styles diverged')
  vim.fn.maparg('<Esc>', 'i', false, true).callback()
  assert(vim.wait(2000, function()
    return #vim.api.nvim_list_wins() == 1
  end))
end
vim.fn.delete(path)
print('PASS public grep prefix, hit formatting and preview byte ranges/style with tabs and Unicode')

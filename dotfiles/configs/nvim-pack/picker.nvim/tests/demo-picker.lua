-- Fixed-data harness for the internal Picker Session; no personal config or fff.
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.env.POPUP_NVIM_PATH or '../popup.nvim')
require('picker').setup()
local Session = require('picker.picker.panel')
vim.o.mouse = 'a' -- Demo only; the plugin never changes the user's mouse option.

local function open()
  ---@type picker.picker.Entry[]
  local entries = {}
  for index = 1, 237 do
    local path = ('src/module-%03d/一个较长的目录/components/example-%03d.lua'):format(
      index,
      index
    )
    entries[index] = { path = '/' .. path, display = path }
  end
  ---@type picker.picker.PageSource
  local source = {
    search = function(query, size, _, page)
      local filtered = {}
      for _, entry in ipairs(entries) do
        if entry.display:lower():find(query:lower(), 1, true) then
          filtered[#filtered + 1] = entry
        end
      end
      local items = {}
      for index = page * size + 1, math.min(#filtered, (page + 1) * size) do
        items[#items + 1] = filtered[index]
      end
      return { status = 'ready', items = items, total = #filtered }
    end,
  }
  local session = Session.new(source, function(entry)
    if entry then
      print('Demo choice (not opened): ' .. entry.path)
    end
  end)
  session:open()
end

vim.api.nvim_create_user_command('PickerDemo', open, {})
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  'Picker integration demo — fixed data, no fff, no file opening.',
  '237 entries. Type to filter; C-n/p or arrows move; C-d/u move half a page.',
  'Enter prints the chosen path; Esc cancels; :PickerDemo opens again.',
  'C-o toggles an empty preview pane; resize preserves the selected logical file.',
  'Preview content and the public backend entry are not implemented yet.',
})
open()

local api = vim.api
local config = require('plugins.explorer.picker.config')
config.search.grep_modes = { 'regex', 'fuzzy', 'plain' }
local modes = {}
package.loaded['plugins.explorer.picker.search.grep'] = {
  new = function()
    return {
      search = function(_, _, mode)
        modes[#modes + 1] = mode
        return {
          status = 'ready',
          total = 1,
          items = {
            {
              path = '/tmp/example.lua',
              display = 'example.lua',
              line = 1,
              col = 0,
              content = 'text',
            },
          },
        }
      end,
    }
  end,
}
require('plugins.explorer.picker').open({
  mode = 'grep',
  get_icon = function()
    return nil
  end,
})
local query = api.nvim_get_current_buf()
local function status()
  local marks = api.nvim_buf_get_extmarks(
    query,
    api.nvim_create_namespace('NativeInputList'),
    0,
    -1,
    { details = true }
  )
  for _, mark in ipairs(marks) do
    if mark[1] == 2 then
      return mark[4].virt_text[1][1]
    end
  end
end
local function key(value)
  vim.fn.maparg(value, 'i', false, true).callback()
end
assert(modes[1] == 'regex', 'Configured first mode must reach the backend')
key('<Tab>')
assert(status():find('regex', 1, true) and status():find('1 selected', 1, true))
for _, mode in ipairs({ 'fuzzy', 'plain', 'regex' }) do
  key('<C-l>')
  assert(modes[#modes] == mode and status():find(mode, 1, true))
  assert(status():find('1 selected', 1, true), 'Mode changes must preserve marks')
end
key('<Esc>')
assert(vim.wait(1000, function()
  return not api.nvim_buf_is_valid(query)
end))
print('PASS Picker query flow')
vim.cmd('qa!')

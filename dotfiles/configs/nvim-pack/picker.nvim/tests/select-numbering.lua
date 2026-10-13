vim.opt.runtimepath:prepend(vim.fn.getcwd())
require('picker').setup()
local List = require('picker.select.list')
local items = {}
for i = 1, 12 do
  items[i] = 'item ' .. i
end
items[2] = 'Banana\noriginal'
local list = List.new(items)
assert(list:texts()[1] == ' 1. item 1')
assert(list:texts()[12] == '12. item 12')
list:set_query('banana')
assert(list:texts()[1] == ' 2. Banana original')
assert(list:entries()[1].full_text == 'Banana\noriginal')
local item, index = list:choice()
assert(item == items[2] and index == 2)
list:set_query('12')
assert(list:entries()[1].index == 12 and list:texts()[1] == '12. item 12')
local custom = List.new(items, {
  view = {
    format = function(_, context)
      return { content = { { 'custom:' .. context.index } } }
    end,
  },
})
assert(custom:texts()[1] == 'custom:1' and custom:entries()[1].full_text == 'custom:1')
local config = assert(require('picker.select.config').options())
assert(config.padding.left == 2 and config.padding.right == 1)
print('PASS Select stable original numbering, unnumbered detail, custom replacement and padding')

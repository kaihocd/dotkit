package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local PickerInput = require('picker.picker.input')
local text = ''
local delivered = 0
local input = PickerInput.new(function()
  return text
end, function(value)
  text = value
end)

local function deliver()
  delivered = delivered + 1
end

input:set_value('中文')
assert(input:value() == '中文')
input:changed(deliver)
input:changed(deliver)
assert(vim.wait(200, function()
  return delivered == 1
end))
print('PASS Input coalesces changes and preserves raw Unicode text')

input:changed(deliver)
text = 'latest'
assert(input:flush() == 'latest')
vim.wait(80, function()
  return false
end)
assert(delivered == 1)
print('PASS Input flush reads the latest text and invalidates delayed delivery')

input:changed(deliver)
input:close()
vim.wait(80, function()
  return false
end)
assert(delivered == 1)
print('PASS Input close cancels pending debounce without editor event ownership')

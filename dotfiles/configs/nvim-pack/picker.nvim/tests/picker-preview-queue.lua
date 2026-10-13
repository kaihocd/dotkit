vim.opt.runtimepath:prepend(vim.fn.getcwd())
require('picker').setup()
local Content = require('picker.picker.preview.content')
local path = vim.fn.tempname()
vim.fn.writefile({ 'preview' }, path)
local original = vim.uv.fs_open
local opens = 0
rawset(vim.uv, 'fs_open', function(...)
  opens = opens + 1
  return original(...)
end)
local content = Content.new(64, require('picker.config').resolve('picker').preview)
local deliveries = {}
for index = 1, 100 do
  content:request(path, function()
    deliveries[#deliveries + 1] = index
  end)
end
assert(opens == 1, 'only one read may be in flight')
assert(vim.wait(2000, function()
  return #deliveries > 0
end))
assert(opens == 1, 'last waiting request should reuse the completed snapshot')
assert(vim.deep_equal(deliveries, { 100 }))
content:request(path, function()
  error('closed reader delivered')
end)
content:request(path, function()
  error('closed pending reader delivered')
end)
content:close()
vim.wait(100)
assert(opens == 1, 'cached requests and close must not open files')
rawset(vim.uv, 'fs_open', original)
vim.fn.delete(path)
print('PASS single-flight disk reads, latest pending request and close drops queued work')

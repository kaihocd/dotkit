local module = require('plugins.explorer.picker.preview.content')
local path = vim.fn.tempname()
vim.fn.writefile({ 'content' }, path)
local failure
local reader = module.new(
  { max_bytes = 100, max_cached_files = 2, max_cached_bytes = 200, max_prefetch = 2 },
  function(err)
    failure = err
  end
)
reader.request(path, function()
  error('delivery failed')
end)
assert(vim.wait(1000, function()
  return failure ~= nil
end))
assert(tostring(failure):find('delivery failed', 1, true))
local delivered = false
reader.request(path, function()
  delivered = true
end)
vim.wait(30)
assert(not delivered, 'Delivery failure must close the reader')
vim.fn.delete(path)
print('PASS content delivery failure cleanup')

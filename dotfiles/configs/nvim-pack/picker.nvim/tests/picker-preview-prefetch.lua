vim.opt.runtimepath:prepend(vim.fn.getcwd())
local Content = require('picker.picker.preview.content')
local root = vim.fn.tempname()
vim.fn.mkdir(root, 'p')
for _, name in ipairs({ 'a', 'b', 'c', 'd' }) do
  vim.fn.writefile({ name }, root .. '/' .. name)
end
local original = vim.uv.fs_open
local opened = {}
rawset(vim.uv, 'fs_open', function(path, ...)
  opened[#opened + 1] = vim.fs.basename(path)
  return original(path, ...)
end)
local content = Content.new(128)
local current
content:request(root .. '/a', function(lines)
  current = lines
end)
content:prefetch({ root .. '/b', root .. '/b', root .. '/c' })
assert(vim.wait(2000, function()
  return current and #opened == 3 and not content._active
end))
assert(vim.deep_equal(opened, { 'a', 'b', 'c' }))
current = nil
content:request(root .. '/b', function(lines)
  current = lines
end)
assert(vim.wait(2000, function()
  return current ~= nil
end))
assert(current and current[1] == 'b' and #opened == 3)
content:prefetch({ root .. '/d', root .. '/missing' })
content:invalidate()
current = nil
content:request(root .. '/a', function(lines)
  current = lines
end)
assert(vim.wait(2000, function()
  return current ~= nil
end))
assert(#opened == 4 and opened[4] == 'd', 'invalidated speculative work must not start')
content:close()
rawset(vim.uv, 'fs_open', original)
vim.fn.delete(root, 'rf')
print('PASS neighboring prefetch deduplicates, warms cache and drops obsolete queued reads')

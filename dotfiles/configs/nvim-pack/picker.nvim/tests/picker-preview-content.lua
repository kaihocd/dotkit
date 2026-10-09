vim.opt.runtimepath:prepend(vim.fn.getcwd())
local Content = require('picker.picker.preview.content')
local directory = vim.fn.tempname()
vim.fn.mkdir(directory, 'p')
local path = directory .. '/text'
vim.fn.writefile({ 'one', 'two' }, path)
local content = Content.new(64)
local function request(file)
  local done, result, problem = false, nil, nil
  content:request(file, function(lines, message)
    result, problem, done = lines, message, true
  end)
  assert(vim.wait(2000, function()
    return done
  end))
  return result, problem
end
local lines = request(path)
assert(vim.deep_equal(lines, { 'one', 'two' }))
vim.fn.writefile({ string.rep('x', 65) }, directory .. '/large')
local _, message = request(directory .. '/large')
assert(message == 'File too large to preview')
vim.fn.writefile({ 'a\nb' }, directory .. '/binary', 'b')
_, message = request(directory .. '/binary')
assert(message == 'Binary file')
_, message = request(directory .. '/missing')
assert(message and message:find('Unable to open', 1, true))
print('PASS async preview disk reading, limits, binary and missing files')
local buf = vim.fn.bufadd(path)
vim.fn.bufload(buf)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'unsaved' })
assert(vim.deep_equal(request(path), { 'unsaved' }))
local stale = false
content:request(path, function()
  stale = true
end)
local latest = false
content:request(path, function()
  latest = true
end)
assert(vim.wait(2000, function()
  return latest
end))
assert(not stale)
content:request(path, function()
  stale = true
end)
content:close()
vim.wait(30)
assert(not stale)
vim.api.nvim_buf_delete(buf, { force = true })
vim.fn.delete(directory, 'rf')
print('PASS loaded-buffer content, superseded delivery and close invalidation')

vim.opt.runtimepath:prepend(vim.fn.getcwd())
local Content = require('picker.picker.preview.content')
local path = vim.fn.tempname()
vim.fn.writefile({ 'old' }, path)
local original = vim.uv.fs_read
local reads = 0
rawset(vim.uv, 'fs_read', function(fd, size, offset, callback)
  reads = reads + 1
  return original(fd, size, offset, function(err, data)
    if reads == 1 then
      -- Change the file after collecting bytes but before the main-loop delivery.
      local writer = assert(vim.uv.fs_open(path, 'w', 438))
      assert(vim.uv.fs_write(writer, 'new longer content\n', 0))
      assert(vim.uv.fs_close(writer))
    end
    callback(err, data)
  end)
end)
local content = Content.new(128)
local result
content:request(path, function(lines)
  result = lines
end)
assert(vim.wait(2000, function()
  return result ~= nil
end))
assert(reads == 2 and vim.deep_equal(result, { 'new longer content' }))
rawset(vim.uv, 'fs_read', original)
local buf = vim.fn.bufadd(path)
vim.fn.bufload(buf)
result = nil
content:request(path, function(lines)
  result = lines
end)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'edited before delivery' })
assert(vim.wait(2000, function()
  return result ~= nil
end))
assert(vim.deep_equal(result, { 'edited before delivery' }))
content:close()
vim.api.nvim_buf_delete(buf, { force = true })
vim.fn.delete(path)
print('PASS disk changes and buffer changedtick invalidate reads before delivery')

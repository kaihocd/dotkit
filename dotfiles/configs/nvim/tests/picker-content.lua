local content_module = require('plugins.explorer.picker.preview.content')
local api = vim.api
local root = vim.fn.tempname()
vim.fn.mkdir(root, 'p')
local path = root .. '/sample'
vim.fn.writefile({ 'disk' }, path)
local content = content_module.new({
  max_bytes = 32,
  max_cached_files = 2,
  max_cached_bytes = 64,
  max_prefetch = 2,
})
local function request()
  local done, result, message
  content.request(path, function(lines, err)
    done, result, message = true, lines, err
  end)
  assert(vim.wait(1000, function()
    return done
  end))
  return result, message
end
local first = request()
assert(first[1] == 'disk')
assert(request() == first, 'Cache hit reuses content')
vim.fn.writefile({ 'changed on disk' }, path)
assert(request()[1] == 'changed on disk', 'Disk version invalidates cached content')
local buf = api.nvim_create_buf(true, false)
api.nvim_buf_set_name(buf, path)
api.nvim_buf_set_lines(buf, 0, -1, false, { 'unsaved' })
assert(request()[1] == 'unsaved', 'Loaded buffer takes precedence over cached disk')
api.nvim_buf_set_lines(buf, 0, -1, false, { 'edited again' })
assert(request()[1] == 'edited again', 'Changedtick invalidates content')
api.nvim_buf_set_lines(buf, 0, -1, false, { string.rep('x', 40) })
local lines, message = request()
assert(not lines and message == 'File too large to preview')
content.close()
assert(
  api.nvim_buf_is_valid(buf) and vim.bo[buf].modified,
  'Source ownership remains outside content module'
)
api.nvim_buf_delete(buf, { force = true })
vim.fn.delete(root, 'rf')
print('PASS content cache and source versions')

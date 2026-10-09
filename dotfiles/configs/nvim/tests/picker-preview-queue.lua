local api = vim.api
require('plugins.explorer.picker.config').view.preview.enabled = true
vim.o.columns = 180
local preview_module = require('plugins.explorer.picker.preview')
local view_module = require('plugins.explorer.picker.view')
local view = view_module.open(
  'Files',
  function() end,
  require('plugins.explorer.picker.config').view
)
local reader = require('plugins.explorer.picker.preview.content').new({
  max_bytes = 1024 * 1024,
  max_cached_files = 32,
  max_cached_bytes = 8 * 1024 * 1024,
  max_prefetch = 4,
})
local preview = preview_module.new(
  view.preview_pane,
  reader,
  { match_highlight = 'Search', match_priority = 200 }
)
local uv = vim.uv
local original_open, original_read, original_close = uv.fs_open, uv.fs_read, uv.fs_close
local reads, opened, active, maximum, closed = {}, {}, 0, 0, 0
uv.fs_open = function(path, _, _, callback)
  active = active + 1
  maximum = math.max(maximum, active)
  opened[#opened + 1] = path
  callback(nil, #opened)
  return {}
end
uv.fs_read = function(fd, _, _, callback)
  reads[opened[fd]] = callback
  return {}
end
uv.fs_close = function(_, callback)
  active, closed = active - 1, closed + 1
  callback()
  return {}
end
local function finish(path)
  local callback = assert(reads[path])
  reads[path] = nil
  callback(nil, path)
  vim.wait(30)
end
local function show(path)
  preview.show({ path = path })
  vim.wait(30)
end
show('/missing/first')
preview.prefetch({ { path = '/missing/prefetch' } })
show('/missing/obsolete')
show('/missing/latest')
assert(#opened == 1, 'Current requests must share the single reader')
finish('/missing/first')
assert(opened[2] == '/missing/latest', 'Newest current item has priority')
finish('/missing/latest')
assert(api.nvim_buf_get_lines(view.preview_pane().buf, 0, 1, false)[1] == '/missing/latest')
show('/missing/closing')
preview.prefetch({ { path = '/missing/never' } })
preview.close()
finish('/missing/closing')
assert(maximum == 1 and active == 0 and closed == 3, 'Every active fd must close')
assert(#opened == 3, 'Close must discard queued work')
uv.fs_open, uv.fs_read, uv.fs_close = original_open, original_read, original_close
view.close()
print('PASS Preview single-reader lifecycle')
vim.cmd('qa!')

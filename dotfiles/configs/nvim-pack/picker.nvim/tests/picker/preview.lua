-- Preview readers and the content queue.
--
-- Both are callback-driven and touch the filesystem, so every case waits on the
-- delivery it expects instead of assuming the work already finished.

local Content = require('picker.picker.preview.content')
local Reader = require('picker.picker.preview.reader')

local root

local function path(name)
  return root .. '/' .. name
end

local function write(name, lines)
  vim.fn.writefile(lines, path(name))
  return path(name)
end

local function write_bytes(name, bytes)
  local fd = assert(vim.uv.fs_open(path(name), 'w', 438))
  assert(vim.uv.fs_write(fd, bytes, -1))
  assert(vim.uv.fs_close(fd))
  return path(name)
end

---@param target string
---@param limit integer
local function load(target, limit)
  local result
  Reader.load(target, limit or 4096, function(lines, message)
    result = { lines = lines, message = message }
  end)
  vim.wait(500, function()
    return result ~= nil
  end)
  return assert(result, 'reader never reported')
end

---@param content picker.picker.PreviewContent
local function request(content, target)
  local result
  content:request(target, function(lines, message)
    result = { lines = lines, message = message }
  end)
  vim.wait(500, function()
    return result ~= nil
  end)
  return result
end

return function(test)
  test('reads a file as normalized lines', function()
    root = vim.fn.tempname()
    vim.fn.mkdir(root, 'p')
    local target = write_bytes('plain.txt', 'one\r\ntwo\n')
    local result = load(target)

    assert(result.message == nil, tostring(result.message))
    assert(#result.lines == 2, 'trailing blank dropped: ' .. #result.lines)
    assert(result.lines[1] == 'one' and result.lines[2] == 'two', table.concat(result.lines, '|'))
  end)

  test('reports a binary file instead of decoding it', function()
    root = vim.fn.tempname()
    vim.fn.mkdir(root, 'p')
    local result = load(write_bytes('binary.bin', 'head\0tail'))

    assert(result.lines == nil, 'no lines for binary data')
    assert(result.message == 'Binary file', tostring(result.message))
  end)

  test('refuses a file above the byte limit', function()
    root = vim.fn.tempname()
    vim.fn.mkdir(root, 'p')
    local result = load(write('long.txt', { string.rep('x', 64) }), 8)

    assert(result.lines == nil, 'no lines above the limit')
    assert(result.message == 'File too large to preview', tostring(result.message))
  end)

  test('reports a missing file without raising', function()
    root = vim.fn.tempname()
    vim.fn.mkdir(root, 'p')
    local result = load(path('absent.txt'))

    assert(result.lines == nil, 'no lines')
    assert(
      tostring(result.message):find('Unable to open file', 1, true),
      tostring(result.message)
    )
  end)

  test('prefers a loaded buffer over the bytes on disk', function()
    root = vim.fn.tempname()
    vim.fn.mkdir(root, 'p')
    local target = write('edited.txt', { 'on disk' })
    local buf = vim.fn.bufadd(target)
    vim.fn.bufload(buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'unsaved edit' })

    local result = load(target)

    assert(result.lines[1] == 'unsaved edit', tostring(result.lines[1]))
    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  test('delivers content for a foreground request', function()
    root = vim.fn.tempname()
    vim.fn.mkdir(root, 'p')
    local target = write('deliver.txt', { 'alpha', 'beta' })
    local content = Content.new(4096, { max_files = 2, max_bytes = 4096, max_prefetch = 2 })

    local result = request(content, target)

    assert(result.lines[1] == 'alpha' and result.lines[2] == 'beta', table.concat(result.lines, '|'))
    assert(result.message == nil, tostring(result.message))
    content:close()
  end)

  test('a foreground request outranks queued prefetches', function()
    root = vim.fn.tempname()
    vim.fn.mkdir(root, 'p')
    local speculative = write('speculative.txt', { 'speculative' })
    local foreground = write('foreground.txt', { 'foreground' })
    local content = Content.new(4096, { max_files = 4, max_bytes = 4096, max_prefetch = 2 })

    local delivered = {}
    content:prefetch({ speculative })
    content:request(foreground, function(lines)
      delivered[#delivered + 1] = lines[1]
    end)
    vim.wait(500, function()
      return delivered[1] ~= nil
    end)

    assert(delivered[1] == 'foreground', tostring(delivered[1]))
    content:close()
  end)

  test('closing stops delivery', function()
    root = vim.fn.tempname()
    vim.fn.mkdir(root, 'p')
    local target = write('closed.txt', { 'content' })
    local content = Content.new(4096, { max_files = 2, max_bytes = 4096, max_prefetch = 2 })

    local delivered
    content:request(target, function(lines)
      delivered = lines
    end)
    content:close()
    vim.wait(200)

    assert(delivered == nil, 'a closed reader must not deliver')
  end)
end

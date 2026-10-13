vim.opt.runtimepath:prepend(vim.fn.getcwd())
local root = assert(vim.uv.fs_realpath(vim.fn.getcwd()))
local ready, wrong = false, false
local calls = {}
package.loaded.fff = {
  file_search = function(query, options)
    calls[#calls + 1] = { query = query, options = options }
    return {
      items = { { relative_path = 'a.lua', match_ranges = { { 0, 1 } }, git_status = 'modified' } },
      total_matched = 17,
    }
  end,
}
package.loaded['fff.rust'] = {
  health_check = function()
    return { file_picker = { base_path = wrong and '/' or root } }
  end,
  wait_for_initial_scan = function(wait)
    assert(wait == 0)
    return ready
  end,
}
local content_calls = 0
package.loaded.fff.content_search = function(query, options)
  content_calls = content_calls + 1
  assert(query == 'needle' and options.mode == 'regex')
  assert(options.page_size == 7 and options.file_offset == 42 and options.wait_for_index_ms == 0)
  return {
    items = {
      {
        relative_path = 'a.lua',
        line_number = 3,
        col = 2,
        line_content = '  needle',
        match_ranges = { { 2, 8 } },
      },
    },
    next_file_offset = 99,
  }
end
require('picker').setup()
local backend = require('picker.picker.backend.fff')
local source = backend.files(root, root .. '/a.lua')
assert(source.search('a', 5, nil, 2).status == 'indexing' and #calls == 1)
ready, wrong = true, true
assert(source.search('a', 5, nil, 2).status == 'indexing' and #calls == 2)
wrong = false
local result = source.search('a', 5, nil, 2)
assert(#calls == 4 and result.status == 'ready' and result.total == 17)
assert(result.items[1].path == root .. '/a.lua')
assert(calls[3].options.cwd == root and calls[4].options.cwd == nil)
assert(calls[4].options.page == 2 and calls[4].options.max_results == 5)
assert(calls[4].options.current_file == 'a.lua' and calls[4].options.wait_for_index_ms == 0)
assert(not pcall(backend.files, root .. '/nonexistent-directory'))
print('PASS fff adapter preserves root guard, nonblocking scan checks and second search')
local grep = backend.grep(root)
ready = false
assert(grep.search('needle', 7, 'regex', 42).status == 'indexing' and content_calls == 0)
ready = true
assert(#grep.search('', 7, nil, 0).items == 0 and content_calls == 0)
local matches = grep.search('needle', 7, 'regex', 42)
assert(content_calls == 1 and matches.more and matches.next_offset == 99 and matches.total == 1)
assert(
  matches.items[1].path == root .. '/a.lua'
    and matches.items[1].line == 3
    and matches.items[1].col == 2
)
assert(vim.deep_equal(matches.items[1].content_matches, { { 2, 8 } }))
print('PASS grep index guard, empty query, mode/offset forwarding and match coordinates')

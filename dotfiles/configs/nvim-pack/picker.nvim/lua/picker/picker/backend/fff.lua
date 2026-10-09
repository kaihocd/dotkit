local M = {}

---@param path string
---@return string?
local function canonical(path)
  return vim.uv.fs_realpath(vim.fn.fnamemodify(path, ':p'))
end

---fff owns a shared index. Keep its root/readiness compatibility checks here.
---@param directory string
---@param current_file? string
---@return picker.picker.PageSource
function M.files(directory, current_file)
  local root = canonical(directory)
  if not root or vim.fn.isdirectory(root) ~= 1 then
    error('picker: cwd must be an existing directory: ' .. directory, 0)
  end

  local fff = require('fff')
  local rust = require('fff.rust')
  local relative_file = current_file
      and current_file ~= ''
      and vim.fs.relpath(root, canonical(current_file) or current_file)
    or nil

  return {
    search = function(query, size, _, page)
      -- Never wait synchronously for initial scanning or enter fff's own UI.
      fff.file_search(query, {
        cwd = root,
        page = page,
        current_file = relative_file,
        max_results = size,
        wait_for_index_ms = 0,
      })

      local health = rust.health_check(root)
      local index = health.file_picker
      if not index or canonical(index.base_path) ~= root or not rust.wait_for_initial_scan(0) then
        return { status = 'indexing', items = {}, total = 0 }
      end

      -- A background root swap may finish between the first search and health check.
      local result = fff.file_search(query, {
        page = page,
        current_file = relative_file,
        max_results = size,
        wait_for_index_ms = 0,
      })
      local items = {}
      for _, item in ipairs(result.items) do
        items[#items + 1] = {
          path = vim.fs.joinpath(root, item.relative_path),
          display = item.relative_path:gsub('[\r\n]', ' '),
          match_ranges = item.match_ranges,
          git_status = item.git_status,
        }
      end

      return { status = 'ready', items = items, total = result.total_matched }
    end,
  }
end

---Reuse the files adapter's shared-index guard before content searches.
---@param directory string
---@param current_file? string
---@return picker.picker.PageSource
function M.grep(directory, current_file)
  local files = M.files(directory, current_file)
  local root = canonical(directory)
  if not root then
    error('picker: cwd disappeared while preparing grep: ' .. directory, 0)
  end

  return {
    search = function(query, size, mode, offset)
      local index = files.search('', 1, nil, 0)
      if index.status ~= 'ready' then
        return index
      end
      if query == '' then
        return { status = 'ready', items = {}, total = 0 }
      end

      local result = require('fff').content_search(query, {
        mode = mode or 'plain',
        page_size = size,
        file_offset = offset,
        max_matches_per_file = 50,
        max_file_size = 1024 * 1024,
        time_budget_ms = 50,
        wait_for_index_ms = 0,
      })
      local items = {}
      for _, item in ipairs(result.items) do
        items[#items + 1] = {
          path = vim.fs.joinpath(root, item.relative_path),
          display = item.relative_path:gsub('[\r\n]', ' '),
          line = item.line_number,
          col = item.col or 0,
          content = item.line_content:gsub('[\r\n]', ' '),
          content_matches = item.match_ranges,
        }
      end

      return {
        status = 'ready',
        items = items,
        total = result.total_matched or #items,
        more = (result.next_file_offset or 0) > 0,
        next_offset = result.next_file_offset or 0,
      }
    end,
  }
end

return M

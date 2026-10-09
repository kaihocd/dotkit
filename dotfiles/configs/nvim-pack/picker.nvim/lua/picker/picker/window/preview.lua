local matches_namespace = vim.api.nvim_create_namespace('PickerPreviewMatches')

---Owns presentation state, never the pane lifetime or content reader.
---@class picker.picker.PreviewPane
---@field _viewport? table<string, integer>
---@field _number boolean
---@field _syntax_buf? integer
---@field _filetype? string
local PreviewPane = {}
PreviewPane.__index = PreviewPane

---@return picker.picker.PreviewPane
function PreviewPane.new()
  return setmetatable({ _number = false }, PreviewPane)
end

---@param pane popup.pane
function PreviewPane:save(pane)
  self._viewport = vim.api.nvim_win_call(pane.win, vim.fn.winsaveview)
end

---@param pane popup.pane
function PreviewPane:restore(pane)
  vim.wo[pane.win].wrap = false
  vim.wo[pane.win].number = self._number
  vim.wo[pane.win].relativenumber = false
  if self._viewport then
    vim.api.nvim_win_call(pane.win, function()
      vim.fn.winrestview(self._viewport)
    end)
  end
end

---Scrolling never transfers focus or changes business selection.
---@param pane popup.pane
---@param lines? integer
---@param direction? integer
function PreviewPane:scroll(pane, lines, direction)
  local height = vim.api.nvim_win_get_height(pane.win)
  local delta = lines or (direction or 1) * math.max(1, math.floor(height / 2))
  if delta == 0 then
    return
  end
  vim.api.nvim_win_call(pane.win, function()
    local state = vim.fn.winsaveview()
    local last = math.max(1, vim.api.nvim_buf_line_count(pane.buf) - height + 1)
    state.topline = math.max(1, math.min(last, state.topline + delta))
    state.lnum = math.max(state.topline, math.min(state.lnum, state.topline + height - 1))
    vim.fn.winrestview(state)
  end)
end

---@param pane popup.pane
---@param lines string[]
---@param line? integer
---@param path? string
function PreviewPane:content(pane, lines, line, path)
  self:matches(pane)
  vim.bo[pane.buf].modifiable = true
  vim.api.nvim_buf_set_lines(pane.buf, 0, -1, false, lines)
  vim.bo[pane.buf].modifiable = false
  local filetype = path and vim.filetype.match({ filename = path, buf = pane.buf }) or nil
  -- Syntax definitions belong to the buffer/filetype, not an individual hit.
  if self._syntax_buf ~= pane.buf or self._filetype ~= filetype then
    vim.api.nvim_buf_call(pane.buf, function()
      vim.cmd('syntax clear')
      vim.b.current_syntax = nil
      if filetype and filetype:match('^[%w_]+$') then
        vim.cmd('runtime! syntax/' .. filetype .. '.vim')
      end
    end)
    self._syntax_buf, self._filetype = pane.buf, filetype
  end
  -- Messages have no file line numbers.
  self._number = path ~= nil
  vim.wo[pane.win].wrap = false
  vim.wo[pane.win].number = self._number
  vim.wo[pane.win].relativenumber = false
  self:position(pane, line)
end

---@param pane popup.pane
---@param line? integer
function PreviewPane:position(pane, line)
  local target = math.max(1, math.min(line or 1, vim.api.nvim_buf_line_count(pane.buf)))
  vim.api.nvim_win_set_cursor(pane.win, { target, 0 })
  vim.api.nvim_win_call(pane.win, function()
    vim.cmd('normal! zz')
  end)
  self:save(pane)
end

---Hit changes do not rewrite content or reset the viewport.
---@param pane popup.pane
---@param entry? picker.picker.Entry
function PreviewPane:matches(pane, entry, highlight)
  vim.api.nvim_buf_clear_namespace(pane.buf, matches_namespace, 0, -1)
  if
    not entry
    or not entry.line
    or entry.line < 1
    or entry.line > vim.api.nvim_buf_line_count(pane.buf)
  then
    return
  end
  local text = vim.api.nvim_buf_get_lines(pane.buf, entry.line - 1, entry.line, false)[1]
  for _, range in ipairs(entry.content_matches or {}) do
    local first, last = math.max(0, range[1]), math.min(#text, range[2])
    if last > first then
      vim.api.nvim_buf_set_extmark(pane.buf, matches_namespace, entry.line - 1, first, {
        end_col = last,
        hl_group = highlight or 'Search',
        priority = 200,
      })
    end
  end
end

return PreviewPane

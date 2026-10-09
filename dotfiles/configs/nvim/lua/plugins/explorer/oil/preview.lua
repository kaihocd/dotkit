local api = vim.api
local Preview = {}
Preview.__index = Preview

-- Owns the preview popup and scratch buffer, never the displayed file buffers.
function Preview.new(create_popup, on_hidden)
  return setmetatable({ create_popup = create_popup, on_hidden = on_hidden }, Preview)
end

function Preview:is_visible()
  return self.popup ~= nil
end

function Preview:open()
  if self.popup then
    return
  end
  self.empty = self.empty or api.nvim_create_buf(false, true)
  local popup = self.create_popup(self.empty)
  self.popup = popup
  popup:on('close', function()
    if self.popup ~= popup then
      return
    end
    self.popup = nil
    self.on_hidden()
  end)
end

-- Hiding keeps the scratch buffer for the next toggle.
function Preview:hide()
  local popup = self.popup
  self.popup = nil
  if popup then
    popup:close()
  end
end

function Preview:render(rect)
  if not self.popup then
    return
  end
  self.popup:update(function(node)
    node.row, node.col = rect.row, rect.col
    node.width, node.height = rect.width, rect.height
  end)
  if self.popup:is_open() then
    self.popup:render()
  else
    self.popup:open()
  end
end

function Preview:show(path)
  if not self.popup then
    return
  end
  local buf = path and vim.fn.bufadd(path) or self.empty
  local pane = self.popup:pane('preview')
  if pane and pane.buf == buf then
    return
  end
  if path then
    vim.fn.bufload(buf)
  end
  self.popup:set_pane_buf('preview', buf)
  self.popup:render()
end

function Preview:scroll(direction)
  local pane = self.popup and self.popup:pane('preview')
  if not pane or not api.nvim_win_is_valid(pane.win) then
    return
  end
  local key = direction == 'down' and '<C-f>' or '<C-b>'
  api.nvim_win_call(pane.win, function()
    vim.cmd.normal({ api.nvim_replace_termcodes(key, true, false, true), bang = true })
  end)
end

function Preview:close()
  local ok, err = pcall(self.hide, self)
  -- Still release our scratch buffer if closing the window failed.
  local empty = self.empty
  self.empty = nil
  local deleted, delete_err = pcall(function()
    if empty and api.nvim_buf_is_valid(empty) then
      api.nvim_buf_delete(empty, { force = true })
    end
  end)
  if not ok then
    error(err, 0)
  end
  if not deleted then
    error(delete_err, 0)
  end
end

return Preview

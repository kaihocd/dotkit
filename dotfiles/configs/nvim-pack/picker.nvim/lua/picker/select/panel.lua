-- One Select interaction; child objects own candidates, UI and editor events.
local SelectList = require('picker.select.list')
local SelectWindow = require('picker.select.window')
local bindings = require('picker.select.bindings')
local config = require('picker.config')

---Own completion and route user intent without managing display resources.
---@class picker.select.SelectPanel<T>
---@field _closed boolean
---@field _started boolean
---@field _origin integer
---@field _complete fun(item: T?, index: integer?)
---@field bindings picker.select.SelectBindings
---@field list picker.select.SelectList<T>
---@field window picker.select.SelectWindow
---@field on_instance? fun(instance: popup.instance)
---@field query string Last raw input, before normalization.
local SelectPanel = {}
SelectPanel.__index = SelectPanel

---Prepare a session without opening windows.
---@generic T
---@param items T[]
---@param options picker.select.Options<T>
---@param on_choice fun(item: T?, index: integer?)
---@return picker.select.SelectPanel<T>?
function SelectPanel.new(items, options, on_choice)
  local resolved, settings = pcall(config.resolve, 'select', {
    view = options.view,
    keymaps = options.keymaps,
  })
  if not resolved then
    vim.notify('picker.select: ' .. tostring(settings), vim.log.levels.WARN)
    on_choice(nil, nil)
    return nil
  end

  local list = SelectList.new(items, {
    format_item = options.format_item,
    view = settings.view,
    normalize = vim.fn.tolower,
  })
  local texts = list:texts()

  local editor_bindings = bindings.new(settings.keymaps)

  -- Geometry failures happen before opening; native window validation happens on open.
  local prepared, window = pcall(
    SelectWindow.new,
    options.prompt or 'Select an item',
    texts,
    list:current_index(),
    settings.view,
    list:rows()
  )
  if not prepared then
    vim.notify('picker.select: unable to prepare view: ' .. tostring(window), vim.log.levels.WARN)
    on_choice(nil, nil)
    return nil
  end

  return setmetatable({
    list = list,
    window = window,
    on_instance = options.on_instance,
    _closed = false,
    _started = false,
    _origin = vim.api.nvim_get_current_win(),
    _complete = on_choice,
    bindings = editor_bindings,
    query = '',
  }, SelectPanel)
end

---Claim completion before any editor or popup cleanup can reenter.
---@generic T
---@param self picker.select.SelectPanel<T>
---@param item T?
---@param index integer?
function SelectPanel.close(self, item, index)
  if self._closed then
    return
  end
  self._closed = true
  self.bindings:detach()

  -- Completion can reopen Select; destroy this invocation before calling it.
  vim.schedule(function()
    local focused = self.window:focused(true)
    if focused then
      vim.cmd.stopinsert()
    end
    local ok, problem = pcall(self.window.close, self.window)
    if focused and vim.api.nvim_win_is_valid(self._origin) then
      vim.api.nvim_set_current_win(self._origin)
    end
    if not ok then
      vim.notify('picker.select: ' .. tostring(problem), vim.log.levels.WARN)
    end
    self._complete(item, index)
  end)
end

---Confirm only when a visible item is selected.
---@generic T
---@param self picker.select.SelectPanel<T>
function SelectPanel.confirm(self)
  if self._closed then
    return
  end

  SelectPanel.refresh(self)
  if self._closed then
    return
  end
  local item, index = self.list:choice()
  if index ~= nil then
    self:close(item, index)
  end
end

---Update the input hint from selection and resolved mappings.
---@generic T
---@param self picker.select.SelectPanel<T>
function SelectPanel.update_hint(self)
  local index = self.list:current_index()
  local entry = index and self.list:entries()[index]
  self.window:hint(self.bindings:detail_key(), entry and entry.text or nil)
end

---Apply the latest buffer text before rendering or confirming.
---@generic T
---@param self picker.select.SelectPanel<T>
function SelectPanel.refresh(self)
  if self._closed then
    return
  end

  local query = self.window:query()
  if query == nil then
    self:close()
    return
  end

  -- Raw edits can leave detail even when normalization keeps the same query.
  local input_changed = query ~= self.query
  self.query = query
  local query_changed = self.list:set_query(query)
  if not query_changed then
    if input_changed then
      SelectPanel.leave_detail(self)
    end
    SelectPanel.update_hint(self)
    return
  end

  -- A new result set must not restore the previous list's scroll position.
  local texts = self.list:texts()
  local rows = self.list:rows()
  local ok, problem = pcall(self.window.render, self.window, texts, self.list:current_index(), rows)
  if not ok then
    vim.notify('picker.select: unable to refresh view: ' .. tostring(problem), vim.log.levels.WARN)
    self:close()
    return
  end
  SelectPanel.update_hint(self)
end

---Move through the list and update the visible cursor.
---@generic T
---@param self picker.select.SelectPanel<T>
---@param delta integer
function SelectPanel.move(self, delta)
  if self._closed then
    return
  end

  SelectPanel.refresh(self)
  if self._closed then
    return
  end
  SelectPanel.leave_detail(self)
  if self._closed then
    return
  end
  self.list:move(delta)
  self.window:select(self.list:current_index())
  SelectPanel.update_hint(self)
end

---Translate a mouse row into model identity without entering the list.
---@generic T
---@param self picker.select.SelectPanel<T>
function SelectPanel.click(self)
  if self._closed then
    return
  end

  local mouse = vim.fn.getmousepos()

  local row = self.window:hit(mouse.screenrow, mouse.screencol)
  if row then
    if self.window:detail_active() then
      return
    end
    local entry = self.list:entries()[row]
    if entry then
      self.list:select(entry.index)
      self.window:select(self.list:current_index())
      SelectPanel.update_hint(self)
    end
  elseif not self.window:focused(true) or mouse.winid ~= vim.api.nvim_get_current_win() then
    self:close()
    if mouse.winid ~= 0 and vim.api.nvim_win_is_valid(mouse.winid) then
      vim.api.nvim_set_current_win(mouse.winid)
    end
  end
end

---Cancel only after focus has actually left both panes.
---@generic T
---@param self picker.select.SelectPanel<T>
function SelectPanel.check_focus(self)
  if self._closed then
    return
  end

  if not self.window:focused() then
    self:close()
  end
end

---Move half a visible list page, excluding the prompt row.
---@generic T
---@param self picker.select.SelectPanel<T>
---@param direction integer
function SelectPanel.page(self, direction)
  if self._closed then
    return
  end

  -- Detail replaces list in the default layout, so it has no list page size.
  if self.window:detail_active() then
    self.window:scroll_detail(direction)
    return
  end
  local size = self.window:page_size()
  if not size then
    self:close()
    return
  end

  local step = math.max(1, math.floor(size / 2))
  SelectPanel.move(self, direction * step)
end

---Return to the original list, restoring its scroll position and updating the hint.
---@generic T
---@param self picker.select.SelectPanel<T>
function SelectPanel.leave_detail(self)
  local ok, problem = pcall(self.window.leave_detail, self.window)
  if not ok then
    vim.notify('picker.select: unable to leave detail: ' .. tostring(problem), vim.log.levels.WARN)
    self:close()
    return
  end
  SelectPanel.update_hint(self)
end

---Toggle the full formatted text of the selected item.
---@generic T
---@param self picker.select.SelectPanel<T>
function SelectPanel.toggle_detail(self)
  if self._closed then
    return
  end

  SelectPanel.refresh(self)
  if self._closed then
    return
  end
  if self.window:detail_active() then
    SelectPanel.leave_detail(self)
    return
  end

  local index = self.list:current_index()
  local entry = index and self.list:entries()[index]
  if entry and self.window:clipped(entry.text) then
    local ok, problem = pcall(self.window.show_detail, self.window, entry.full_text)
    if not ok then
      vim.notify('picker.select: unable to show detail: ' .. tostring(problem), vim.log.levels.WARN)
      self:close()
      return
    end
    SelectPanel.update_hint(self)
  end
end

---Expose commands, not session state, to keymap callbacks.
---@generic T
---@param self picker.select.SelectPanel<T>
---@return picker.select.Actions<T>
function SelectPanel.commands(self)
  return {
    toggle_detail = function()
      SelectPanel.toggle_detail(self)
    end,
    confirm = function()
      SelectPanel.confirm(self)
    end,
    cancel = function()
      self:close()
    end,
    move = function(delta)
      SelectPanel.move(self, delta)
    end,
    page = function(direction)
      SelectPanel.page(self, direction)
    end,
    choice = function()
      if self._closed then
        return nil, nil
      end
      SelectPanel.refresh(self)
      if self._closed then
        return nil, nil
      end
      return self.list:choice()
    end,
  }
end

---Layout failures cancel through the same completion boundary as opening failures.
---@generic T
---@param self picker.select.SelectPanel<T>
function SelectPanel.resize(self)
  if self._closed then
    return
  end
  local ok, problem = pcall(self.window.resize, self.window)
  if not ok then
    vim.notify('picker.select: unable to resize view: ' .. tostring(problem), vim.log.levels.WARN)
    self:close()
    return
  end
  SelectPanel.update_hint(self)
end

---Bind before opening so partial mounting belongs to the same close protocol.
---@generic T
---@param self picker.select.SelectPanel<T>
function SelectPanel.open(self)
  if self._started or self._closed then
    return
  end
  self._started = true
  local opened, problem = pcall(function()
    self.bindings:attach(self.window.popup, SelectPanel.commands(self), {
      active = function()
        return not self._closed
      end,
      click = function()
        SelectPanel.click(self)
      end,
      refresh = function()
        SelectPanel.refresh(self)
      end,
      focus = function()
        SelectPanel.check_focus(self)
      end,
      resize = function()
        SelectPanel.resize(self)
      end,
    })

    -- Group policies may close us, so completion must already be bound.
    if self.on_instance then
      self.on_instance(self.window.popup)
    end
    if not self._closed then
      self.window:open()
      SelectPanel.refresh(self)
    end
  end)
  if not opened then
    vim.notify('picker.select: unable to open view: ' .. tostring(problem), vim.log.levels.WARN)
    self:close()
    return
  end
  if not self._closed then
    SelectPanel.update_hint(self)
    vim.cmd.startinsert()
  end
end

return SelectPanel

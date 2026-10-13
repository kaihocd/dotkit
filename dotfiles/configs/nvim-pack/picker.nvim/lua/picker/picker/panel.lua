local PickerInput = require('picker.picker.input')
local PickerList = require('picker.picker.list')
local PickerSelection = require('picker.picker.selection')
local PickerWindow = require('picker.picker.window')
local Preview = require('picker.picker.preview')
local bindings = require('picker.picker.editor.bindings')

---One invocation. Owns close/completion and coordinates independently owned components.
---@class picker.picker.PickerPanel
---@field selection picker.picker.PickerSelection
---@field list picker.picker.PickerList
---@field window picker.picker.PickerWindow
---@field preview picker.picker.Preview
---@field _closed boolean
---@field _started boolean
---@field _origin integer
---@field _save? fun()
---@field _complete fun(entry: picker.picker.Entry?, result: picker.picker.Completion?)
---@field input picker.picker.PickerInput
---@field _result picker.picker.Page Last page applied to Selection, for presentation only.
---@field bindings picker.picker.PickerBindings
---@field _keymaps picker.picker.Keymaps
---@field _query string Query of the page applied to Selection; not raw input or pending work.
---@field _settings picker.PickerConfig
---@field _grep boolean
local PickerPanel = {}
PickerPanel.__index = PickerPanel

---Internal source injection supports deterministic tests, not arbitrary public Sources.
---@param source picker.picker.PageSource
---@param on_choice fun(entry: picker.picker.Entry?, result: picker.picker.Completion?)
---@param options? picker.picker.ViewOptions
---@param keymaps? picker.picker.Keymaps
---@param grep? boolean
---@param settings? picker.PickerConfig
---@return picker.picker.PickerPanel
function PickerPanel.new(source, on_choice, options, keymaps, grep, settings)
  local view
  if settings then
    assert(options, 'resolved view is required with session settings')
    ---@cast options picker.picker.ResolvedView
    view = vim.deepcopy(options)
  else
    local invocation
    invocation, settings = require('picker.picker.options').resolve({
      view = options,
      keymaps = keymaps,
      mode = grep and 'grep' or 'files',
    })
    view = invocation.view
  end
  local resolved = vim.deepcopy(settings)
  local list = PickerList.new(source, grep or false, resolved.search)
  local window = PickerWindow.new(view, grep and 'grep' or 'files')
  local input = PickerInput.new(function()
    return window:query()
  end, function(text)
    window:restore_query(text, false)
  end, resolved.search.debounce_ms)

  return setmetatable({
    selection = PickerSelection.new(),
    list = list,
    _grep = grep or false,
    window = window,
    input = input,
    preview = Preview.new(resolved.preview),
    _settings = resolved,
    _closed = false,
    _started = false,
    _origin = vim.api.nvim_get_current_win(),
    _complete = on_choice,
    _result = { status = 'ready', items = {}, total = 0 },
    bindings = bindings.new(),
    _query = '',
    _keymaps = resolved.keymaps,
  }, PickerPanel)
end

---Claim completion before any cleanup can reenter through popup close events.
---@param entry? picker.picker.Entry
---@param result? picker.picker.Completion
function PickerPanel:close(entry, result)
  if self._closed then
    return
  end
  self:interrupt_restore()
  self._closed = true

  -- Capture resume state before closing the input and result owners.
  local save = self._save
  self._save = nil
  if save then
    local ok, problem = pcall(save)
    if not ok then
      vim.notify('picker: unable to save session: ' .. tostring(problem), vim.log.levels.ERROR)
    end
  end

  -- Stop producers and detach editor events before scheduled UI destruction.
  self.input:close()
  self.list:close()
  self.preview:close()
  self.bindings:detach()

  vim.schedule(function()
    local focused = self.window:focused()
    if focused then
      vim.cmd.stopinsert()
    end

    local left, leave_problem = pcall(self.window.popup.leave_group, self.window.popup)
    self.window:close()
    if focused and vim.api.nvim_win_is_valid(self._origin) then
      vim.api.nvim_set_current_win(self._origin)
    end

    -- Completion may open another Picker; old resources must already be gone.
    local ok, problem = pcall(self._complete, entry, result)
    if not left then
      vim.notify('picker: ' .. tostring(leave_problem), vim.log.levels.ERROR)
    end
    if not ok then
      vim.notify('picker: ' .. tostring(problem), vim.log.levels.ERROR)
    end
  end)
end

---One error boundary for editor callbacks and backend application.
---@param operation fun()
function PickerPanel:run(operation)
  if self._closed then
    return
  end
  local ok, problem = pcall(operation)
  if not ok then
    self:close()
    vim.notify('picker: ' .. tostring(problem), vim.log.levels.ERROR)
  end
end

---Register capture only after a successful public open.
---@param save fun()
function PickerPanel:save_on_close(save)
  if not self._closed then
    self._save = save
  end
end

---Resume captures values while input and selection are still available.
---@return picker.picker.SnapshotState
function PickerPanel:snapshot_state()
  return {
    position = self.list:snapshot(),
    coherent = self:query_is_current(),
    query = self.input:value(),
    match_mode = self:match_mode(),
    preview = self.window:preview_requested(),
    index = self.selection:current_index(),
    current = self.selection:current(),
    marks = self.selection:marked_items(),
  }
end

---Explicit interaction takes ownership from automatic restoration.
function PickerPanel:interrupt_restore()
  self.list:interrupt_restore()
end

---@param reuse? boolean
function PickerPanel:refresh(reuse)
  if self._closed then
    return
  end
  local query = self.input:flush()
  local result, target = self.list:load(query, self.window:page_size(), reuse)
  self.selection:replace(result.items, query == self._query and not reuse, target)
  self._query = query
  self._result = result
  self.window:render(
    self.selection:entries(),
    self.selection:current_index(),
    result.status,
    self._grep
  )
  self:decorate()
  self:update_preview()
  self.list:continue_loading(result, function()
    self:run(function()
      self:refresh()
    end)
  end)
end

---@return boolean
function PickerPanel:query_is_current()
  return self.input:value() == self._query
end

---@return string
function PickerPanel:match_mode()
  return self.list:match_mode()
end

---Changing match semantics starts a fresh continuation chain, not a fresh invocation.
function PickerPanel:cycle_match_mode()
  if self._closed or not self._grep then
    return
  end
  self.list:cycle_match_mode()
  self:refresh()
end

function PickerPanel:update_preview()
  self.preview:update(self.window:preview_display(), self.selection:current(), function(operation)
    self:run(operation)
  end, self.selection:nearby(self._settings.preview.radius))
end

---Refresh only model-driven decorations; marking does not rerun the search.
function PickerPanel:decorate()
  self.window:marks(self.selection:entries(), function(entry)
    return self.selection:is_marked(entry)
  end)
  self.window:status(
    self._result,
    self.selection:marked_count(),
    self._grep and self.list:match_mode() or nil
  )
end

---Input invalidates pending polling/prefetch now, not when the debounce expires.
function PickerPanel:query_changed()
  if self._closed then
    return
  end
  self.list:invalidate()
  self.window:status(
    self._result,
    self.selection:marked_count(),
    self._grep and self.list:match_mode() or nil
  )
  self.input:changed(function()
    self:run(function()
      self:refresh()
    end)
  end)
end

function PickerPanel:update_selection()
  self.window:select(self.selection:current_index())
end

---@param delta integer
function PickerPanel:move(delta)
  self:interrupt_restore()
  if self._closed then
    return
  end
  if not self:query_is_current() then
    self:refresh()
  end
  local index = self.selection:current_index()
  if not index then
    return
  end
  local changed, target = self.list:move(index, delta)
  if changed then
    self:refresh(true)
  elseif target then
    self.selection:move(target - index)
    self:update_selection()
    self:update_preview()
  end
end

---Translate the displayed half-page into an item movement before requesting a page.
---@param direction integer
function PickerPanel:page(direction)
  if self._closed then
    return
  end
  if not self:query_is_current() then
    self:refresh()
  end
  local delta = direction * math.max(1, math.floor(self.window:page_size() / 2))
  if self._grep then
    delta = self.window:page_delta(self.selection:current_index(), direction)
  end
  self:move(delta)
end

---@param toggle? boolean
function PickerPanel:resize(toggle)
  self:interrupt_restore()
  if self._closed then
    return
  end
  local index = self.selection:current_index() or 1
  if toggle then
    self.window:toggle_preview()
  else
    self.window:resize()
  end
  local target = self.list:resize(self.window:page_size(), index)
  -- Width-only changes must repaint without resetting the current item.
  self:refresh(target ~= nil)
end

---@param mode? picker.picker.OpenMode
function PickerPanel:confirm(mode)
  self:interrupt_restore()
  if self._closed then
    return
  end
  if not self:query_is_current() then
    self:refresh()
  end
  local entry = self.selection:current()
  if entry then
    self:close(entry, { mode = mode or 'edit', entries = { vim.deepcopy(entry) } })
  end
end

---Marks remain Selection-owned; completion takes a snapshot before closing.
function PickerPanel:quickfix()
  self:interrupt_restore()
  if self._closed then
    return
  end
  if not self:query_is_current() then
    self:refresh()
  end
  local entries = self.selection:marked_items()
  if #entries == 0 then
    local current = self.selection:current()
    if current then
      entries = { current }
    end
  end
  if #entries > 0 then
    self:close(nil, { mode = 'quickfix', entries = vim.deepcopy(entries) })
  end
end

---@param direction integer
function PickerPanel:mark(direction)
  if self._closed then
    return
  end
  if not self:query_is_current() then
    self:refresh()
  end
  self.selection:toggle_mark()
  self:move(direction)
  self:update_selection()
  self:decorate()
end

---Mouse selection changes the model without confirming or entering the list.
function PickerPanel:click()
  self:interrupt_restore()
  if self._closed then
    return
  end
  local mouse = vim.fn.getmousepos()
  if not self:query_is_current() then
    self:refresh()
  end
  local index = self.window:hit(mouse.screenrow, mouse.screencol)
  local current = self.selection:current_index()
  if index and current and self.selection:entries()[index] then
    self.selection:move(index - current)
    self:update_selection()
    self:update_preview()
  elseif not self.window:contains(mouse.screenrow, mouse.screencol) then
    self:close()
    if mouse.winid ~= 0 and vim.api.nvim_win_is_valid(mouse.winid) then
      vim.api.nvim_set_current_win(mouse.winid)
    end
  end
end

---Install before open so partial opening also belongs to this invocation.
---@private
function PickerPanel:bind()
  local function action(operation)
    return function()
      self:run(operation)
    end
  end
  local cancel = function()
    self:close()
  end
  local actions = require('picker.picker.editor.actions').create({
    confirm = function(mode)
      self:confirm(mode)
    end,
    cancel = function()
      self:close()
    end,
    quickfix = function()
      self:quickfix()
    end,
    mark = function(step)
      self:mark(step)
    end,
    move = function(delta)
      self:move(delta)
    end,
    page = function(step)
      self:page(step)
    end,
    scroll_preview = function(lines, step)
      self.window:scroll_preview(lines, step)
    end,
    cycle_match_mode = function()
      self:cycle_match_mode()
    end,
    toggle_preview = function()
      self:resize(true)
    end,
  }, function(operation)
    self:run(operation)
  end)
  local mappings = bindings.resolve(self._keymaps, actions, function(operation)
    self:run(operation)
  end, function()
    self:click()
  end)
  bindings.attach(self.window.popup, mappings)
  self.window.popup:on('close', cancel)
  self.window.popup:on('open', function()
    if self._closed then
      return
    end
    local input = self.window:pane('input')
    if not input then
      self:close()
      return
    end
    self.bindings:attach(input, {
      changed = action(function()
        self:query_changed()
      end),
      outside = function()
        if not self.window:focused() then
          self:close()
        end
      end,
      theme = action(function()
        self:decorate()
      end),
      resize = action(function()
        self:resize()
      end),
    })
  end)
end

---@param on_instance? fun(instance: popup.instance)
---@param snapshot? picker.picker.Snapshot
function PickerPanel:open(on_instance, snapshot)
  if self._started or self._closed then
    return
  end
  self._started = true
  self:run(function()
    self:bind()
    if on_instance then
      on_instance(self.window.popup)
    end
    if self._closed then
      return
    end
    self.window:open()
    if self._closed then
      return
    end
    if snapshot then
      self._query = snapshot.query
      self.selection:restore_marks(snapshot.marks)
      self.input:set_value(snapshot.query)
      if snapshot.preview ~= self.window:preview_requested() then
        self.window:toggle_preview()
      end
      self.list:restore(snapshot)
    end
    self:refresh()
    if snapshot then
      -- startinsert is deferred; restore_query placed the cursor first.
      vim.cmd('startinsert!')
    else
      vim.cmd.startinsert()
    end
  end)
end

return PickerPanel

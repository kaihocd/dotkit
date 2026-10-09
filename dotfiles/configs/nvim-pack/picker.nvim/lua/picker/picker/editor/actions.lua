---Builds the public, validated Actions boundary without owning Session state.
local M = {}

---@param value unknown
---@param name string
local function integer(value, name)
  if
    type(value) ~= 'number'
    or value ~= value
    or math.abs(value) == math.huge
    or value % 1 ~= 0
  then
    error('picker: ' .. name .. ' must be a finite integer', 0)
  end
end

---@param value unknown
---@param name string
---@param stationary boolean
local function direction(value, name, stationary)
  integer(value, name)
  if value ~= -1 and value ~= 1 and not (stationary and value == 0) then
    error('picker: ' .. name .. ' must be ' .. (stationary and '-1, 0 or 1' or '-1 or 1'), 0)
  end
end

---@param operation fun()
---@param run fun(operation: fun())
---@return fun()
local function guarded(operation, run)
  return function()
    run(operation)
  end
end

---@param operations {confirm: fun(mode?: picker.picker.OpenMode), cancel: fun(), quickfix: fun(), mark: fun(integer), move: fun(integer), page: fun(integer), scroll_preview: fun(integer?, integer?), cycle_match_mode: fun(), toggle_preview: fun()}
---@param run fun(operation: fun())
---@return picker.picker.Actions
function M.create(operations, run)
  return {
    confirm = guarded(function()
      operations.confirm()
    end, run),
    cancel = operations.cancel,
    open = function(mode)
      run(function()
        if mode ~= 'edit' and mode ~= 'split' and mode ~= 'vsplit' and mode ~= 'tab' then
          error('picker: open mode must be edit, split, vsplit or tab', 0)
        end
        operations.confirm(mode)
      end)
    end,
    quickfix = guarded(operations.quickfix, run),
    mark = function(step)
      run(function()
        direction(step, 'mark direction', true)
        operations.mark(step)
      end)
    end,
    move = function(delta)
      run(function()
        integer(delta, 'move delta')
        operations.move(delta)
      end)
    end,
    page = function(step)
      run(function()
        direction(step, 'page direction', false)
        operations.page(step)
      end)
    end,
    scroll_preview = function(lines, step)
      run(function()
        if lines ~= nil then
          integer(lines, 'scroll_preview lines')
        end
        if step ~= nil then
          direction(step, 'scroll_preview direction', false)
        end
        operations.scroll_preview(lines, step)
      end)
    end,
    cycle_match_mode = guarded(operations.cycle_match_mode, run),
    toggle_preview = guarded(operations.toggle_preview, run),
  }
end

return M

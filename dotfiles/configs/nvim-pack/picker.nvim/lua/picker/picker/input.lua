local config = require('picker.picker.config')

---Owns pending text delivery; the pane remains the source of raw input text.
---@class picker.picker.PickerInput
---@field private _read fun(): string
---@field private _write fun(text: string)
---@field private _generation integer
---@field private _closed boolean
local PickerInput = {}
PickerInput.__index = PickerInput

---@param read fun(): string
---@param write fun(text: string)
---@return picker.picker.PickerInput
function PickerInput.new(read, write)
  return setmetatable({
    _read = read,
    _write = write,
    _generation = 0,
    _closed = false,
  }, PickerInput)
end

---@return string
function PickerInput:value()
  return self._read()
end

---Immediate application supersedes any delayed delivery of the same input.
---@return string
function PickerInput:flush()
  self._generation = self._generation + 1
  return self:value()
end

---@param text string
function PickerInput:set_value(text)
  self._generation = self._generation + 1
  self._write(text)
end

---@param deliver fun()
function PickerInput:changed(deliver)
  if self._closed then
    return
  end

  self._generation = self._generation + 1
  local generation = self._generation

  vim.defer_fn(function()
    if not self._closed and generation == self._generation then
      deliver()
    end
  end, config.debounce_ms)
end

function PickerInput:close()
  self._closed = true
  self._generation = self._generation + 1
end

return PickerInput

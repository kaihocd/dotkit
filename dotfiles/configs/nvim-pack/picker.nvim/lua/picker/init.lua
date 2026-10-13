local M = {}

---Replace configured preferences atomically; existing sessions retain their snapshots.
---@param options? picker.SetupOptions
function M.setup(options)
  require('picker.config').setup(options)
end

---Open the plugin's Select UI without replacing vim.ui.select.
---@generic T
---@param items T[]
---@param options? picker.select.Options<T>
---@param on_choice fun(item: T?, index: integer?)
function M.select(items, options, on_choice)
  require('picker.config').assert_setup()
  require('picker.select').open(items, options, on_choice)
end

---Open file search without installing mappings or changing personal configuration.
---@param options? picker.picker.Options
function M.open(options)
  require('picker.config').assert_setup()
  require('picker.picker').open(options)
end

---Re-search the most recently closed Picker invocation.
---@param options? picker.picker.ResumeOptions
function M.resume(options)
  require('picker.config').assert_setup()
  require('picker.picker').resume(options)
end

return M

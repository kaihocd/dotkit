-- Painting for the Select window: prompt, rows, current row and input hint.
--
-- Reads a popup instance plus a resolved view and writes only buffer contents,
-- extmarks and window options. Window lifetime and detail transitions stay in
-- `picker.select.window`.

local list_renderer = require('picker.ui.list')
local pane_guard = require('picker.ui.pane')

local prefix_namespace = vim.api.nvim_create_namespace('PickerSelect')
local hint_namespace = vim.api.nvim_create_namespace('PickerSelectHint')
local prompt_namespace = vim.api.nvim_create_namespace('PickerSelectPrompt')

local M = {}

---Apply static styling once both panes exist.
---@param instance popup.instance
---@param config picker.select.ResolvedView
function M.decorate(instance, config)
  local input = pane_guard.get(instance, 'input')
  local list = pane_guard.get(instance, 'list')
  local detail = pane_guard.get(instance, 'detail')
  if not input or not list then
    return
  end

  vim.bo[input.buf].buftype = 'prompt'
  -- The visible prefix is an extmark, not part of the editable query.
  vim.fn.prompt_setprompt(input.buf, '')
  vim.bo[input.buf].filetype = 'picker-select-input'
  vim.bo[list.buf].filetype = 'picker-select'
  if detail then
    vim.bo[detail.buf].filetype = 'picker-select-detail'
    vim.wo[detail.win].wrap = false
    vim.wo[detail.win].cursorline = false
  end

  vim.wo[input.win].wrap = false
  vim.wo[list.win].wrap = false
  vim.wo[list.win].winhighlight = 'CursorLine:' .. config.highlights.current

  vim.api.nvim_buf_set_extmark(input.buf, prefix_namespace, 0, 0, {
    virt_text = {
      { string.rep(' ', config.prefix.margin[1]) },
      { config.prefix.text, config.prefix.highlight },
      { string.rep(' ', config.prefix.margin[2]) },
    },
    virt_text_pos = 'inline',
    right_gravity = false,
  })
end

---@param instance popup.instance
---@param prompt string
---@param config picker.select.ResolvedView
local function paint_prompt(instance, prompt, config)
  local title = assert(pane_guard.get(instance, 'prompt'))
  vim.bo[title.buf].modifiable = true
  vim.api.nvim_buf_set_lines(title.buf, 0, -1, false, vim.split(prompt, '\n', { plain = true }))
  vim.bo[title.buf].modifiable = false
  vim.wo[title.win].wrap = true
  vim.wo[title.win].linebreak = false
  vim.api.nvim_buf_clear_namespace(title.buf, prompt_namespace, 0, -1)
  for row, line in ipairs(vim.api.nvim_buf_get_lines(title.buf, 0, -1, false)) do
    if #line > 0 then
      vim.api.nvim_buf_set_extmark(title.buf, prompt_namespace, row - 1, 0, {
        end_col = #line,
        hl_group = config.highlights.prompt,
      })
    end
  end
end

---@param texts string[]
---@param formatted? picker.list.Row[]
---@return picker.list.Row[]
local function rows_for(texts, formatted)
  local rows = {}
  for index, text in ipairs(texts) do
    rows[#rows + 1] = formatted and formatted[index] or { content = { { text } } }
  end
  return rows
end

---Compose the prompt and the item rows for the shared list renderer.
---@param instance popup.instance
---@param prompt string
---@param texts string[]
---@param current_index integer?
---@param config picker.select.ResolvedView
---@param formatted? picker.list.Row[]
function M.render(instance, prompt, texts, current_index, config, formatted)
  paint_prompt(instance, prompt, config)
  local pane = pane_guard.get(instance, 'list')
  if not pane then
    return
  end
  list_renderer.render(pane, rows_for(texts, formatted), {
    padding = { left = config.padding.left, right = config.padding.right },
  })
  M.select(instance, current_index, config.highlights.current)
end

---@param instance popup.instance
---@param current_index integer?
---@param highlight string
function M.select(instance, current_index, highlight)
  local pane = pane_guard.get(instance, 'list')
  if pane then
    list_renderer.select(pane, current_index, highlight)
  end
end

---Whether the row is too wide for the list pane; hints reuse this rule.
---@param instance popup.instance
---@param config picker.select.ResolvedView
---@param text string
---@return boolean
function M.clipped(instance, config, text)
  local pane = pane_guard.get(instance, 'list')
  return pane ~= nil
    and list_renderer.is_clipped(text, vim.api.nvim_win_get_width(pane.win), {
      padding = { left = config.padding.left, right = config.padding.right },
    })
end

---Keep the input hint clear of the query and its insertion cursor.
---@param instance popup.instance
---@param config picker.select.ResolvedView
---@param key string?
---@param text string?
---@param detail boolean
function M.hint(instance, config, key, text, detail)
  local input = pane_guard.get(instance, 'input')
  if not input then
    return
  end
  vim.api.nvim_buf_clear_namespace(input.buf, hint_namespace, 0, -1)
  if not key then
    return
  end
  if not detail and not M.clipped(instance, config, text or '') then
    return
  end

  local hint = key .. (detail and ': back ' or ': full text ')
  local query = vim.api.nvim_buf_get_lines(input.buf, 0, 1, false)[1] or ''
  local occupied = vim.fn.strdisplaywidth(config.prefix.text)
    + vim.fn.strdisplaywidth(query)
    + config.prefix.margin[1]
    + config.prefix.margin[2]
  local available = vim.api.nvim_win_get_width(input.win)
  -- Reserve a cell for the insertion cursor and a gap before the hint.
  if occupied + 2 + vim.fn.strdisplaywidth(hint) > available then
    return
  end

  vim.api.nvim_buf_set_extmark(input.buf, hint_namespace, 0, 0, {
    virt_text = { { hint, config.highlights.hint } },
    virt_text_pos = 'right_align',
    right_gravity = false,
  })
end

return M

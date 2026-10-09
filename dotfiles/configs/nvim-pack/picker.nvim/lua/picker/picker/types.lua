---@meta

---@class picker.picker.ListHighlight
---@field first integer Zero-based byte offset in display text.
---@field last integer Exclusive byte offset in display text.
---@field group string Highlight group name.
---@field priority integer

---@class picker.picker.ListItemContext
---@field mode 'files'|'grep'
---@field width integer Available text width after outer padding.
---@field git_status? string
---@field icon? string
---@field icon_highlight? string

---@alias picker.picker.FormatItem fun(entry: picker.picker.Entry, context: picker.picker.ListItemContext): picker.list.Row

---@class picker.picker.RowStyleOptions
---@field match? string
---@field current? string

---@class picker.picker.PresentationOptions
---@field format? picker.picker.FormatItem Pure entry-to-row override; no Session/View access.
---@field prefix? picker.picker.TextStyleOptions
---@field row? picker.picker.RowStyleOptions
---@field marker? picker.picker.TextStyleOptions
---@field messages? {empty?: string, indexing?: string}
---@field status? picker.picker.StatusOptions

---@class picker.picker.TextStyleOptions
---@field text? string
---@field highlight? string
---@field margin? { [1]: integer, [2]: integer }

---@class picker.picker.StatusOptions
---@field highlight? string
---@field selected_suffix? string
---@field separator? string
---@field trailing_space? string

---@class picker.picker.StatusPresentation: picker.picker.StatusOptions
---@field highlight string
---@field selected_suffix string
---@field separator string
---@field trailing_space string

---@class picker.picker.TextStyle: picker.picker.TextStyleOptions
---@field text string
---@field highlight string

---Runtime configuration for a new resumed instance; not saved in snapshots.
---@class picker.picker.ResumeOptions
---@field on_instance? fun(instance: popup.instance) Configure before opening; previous invocation hooks are not replayed.

---@class picker.picker.Options
---@field mode? 'files'|'grep' Defaults to files; grep starts with plain matching.
---@field cwd? string Defaults to the current working directory.
---@field on_instance? fun(instance: popup.instance) Configure the popup instance before opening.
---@field view? picker.picker.ViewOptions
---@field keymaps? picker.picker.Keymaps

---Commands for one invocation; no Session, window or mutable selection access.
---@class picker.picker.Actions
---@field confirm fun()
---@field open fun(mode: picker.picker.OpenMode)
---@field quickfix fun()
---@field mark fun(direction: -1|0|1) Mark then move; 0 stays on the current item.
---@field cancel fun()
---@field move fun(delta: integer)
---@field page fun(direction: -1|1)
---@field toggle_preview fun()
---@field cycle_match_mode fun() Cycles plain/regex/fuzzy in grep; no-op in files.
---@field scroll_preview fun(lines?: integer, direction?: -1|1) Signed lines; omitted lines scroll half a preview window.

---@alias picker.picker.Keymaps table<string, table<string, string|false|fun(actions: picker.picker.Actions)>>

return {}

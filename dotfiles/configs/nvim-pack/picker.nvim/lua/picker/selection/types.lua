---@meta

---Keys identify entries across result updates.
---@alias picker.selection.Key string|number

---Options used to construct one Selection<T>.
---@class picker.selection.Options<T>
---@field key fun(item: T): picker.selection.Key Return a stable, unique key for each item.

---Options controlling how a new result set replaces the current one.
---@class picker.selection.ReplaceOptions
---@field preserve_current? boolean Preserve the current item by key when possible.

---Mutable state owned by one Selection<T>.
---@class picker.selection.State<T>
---@field items T[] Current selectable items in display order.
---@field index_by_key table<picker.selection.Key, integer> Current key-to-index lookup.
---@field current_index integer? Current item index, or nil for no items.
---@field marked table<picker.selection.Key, T> Marked items by stable key.
---@field mark_order picker.selection.Key[] Marked keys in selection order.

---Public facade for the selection state and operations.
---@class picker.Selection<T>
---@field _get_key fun(item: T): picker.selection.Key Stable identity function supplied by the caller.
---@field _state picker.selection.State<T> Mutable state owned by the selection.
---@field replace fun(self: picker.Selection<T>, items: T[], options?: picker.selection.ReplaceOptions)
---@field items fun(self: picker.Selection<T>): T[]
---@field count fun(self: picker.Selection<T>): integer
---@field current fun(self: picker.Selection<T>): T?
---@field current_index fun(self: picker.Selection<T>): integer?
---@field current_key fun(self: picker.Selection<T>): picker.selection.Key?
---@field select fun(self: picker.Selection<T>, key: picker.selection.Key): boolean
---@field can_move fun(self: picker.Selection<T>, delta: integer): boolean
---@field move fun(self: picker.Selection<T>, delta: integer): boolean
---@field toggle_mark fun(self: picker.Selection<T>): boolean
---@field is_marked fun(self: picker.Selection<T>, key: picker.selection.Key): boolean
---@field marked_count fun(self: picker.Selection<T>): integer
---@field marked_items fun(self: picker.Selection<T>): T[]
---@field clear_marks fun(self: picker.Selection<T>)
---@field replace_marks fun(self: picker.Selection<T>, items: T[])

return {}

---@meta

---Entry formatting and query normalization.
---@class picker.select.Options<T>
---@field prompt? string Prompt shown above the list.
---@field view? picker.select.ViewOptions
---@field on_instance? fun(instance: popup.instance) Configure the popup instance before opening.
---Mode-local overrides; Select action names or native popup actions. False disables a key.
---@field keymaps? table<string, table<string, string|false|fun(actions: picker.select.Actions<T>)>>
---Defaults to tostring.
---@field format_item? fun(item: T): string
---Defaults to string.lower; use vim.fn.tolower for Unicode.
---@field normalize? fun(text: string): string

---Select sizing policy and native popup overrides. All fields have defaults.
---@class picker.select.LayoutPanes
---@field prompt popup.node.pane Wrapped, noninteractive title. Always retain this pane.
---@field input popup.node.pane
---@field list popup.node.pane
---@field detail popup.node.pane Full original text with native wrap; use instead of list when context.detail is true.

---@class picker.select.LayoutContext
---@field width integer
---@field height integer
---@field detail boolean Full-text mode, not capability. Callback runs initially, on resize and on mode changes. Retain input plus the active list/detail pane.

---@class picker.select.ViewOptions
---@field format? fun(item: any, context: {index: integer, text: string}): picker.list.Row
---@field min_items? integer Minimum visible items; default 1.
---@field max_items? integer Maximum visible items; default 8.
---@field min_width? integer Minimum content width; default 20.
---@field max_width? integer Maximum content width; default 60.
---@field prefix? { text?: string, highlight?: string, margin?: { [1]: integer, [2]: integer } } Margin is { left, right }, outside the prefix highlight.
---@field highlights? { prompt?: string, current?: string, hint?: string }
---@field padding? { left?: integer, right?: integer } Insets in display cells; default left 3, right 1.
---@field layout? fun(panes: picker.select.LayoutPanes, context: picker.select.LayoutContext): popup.node Custom pane composition; callback must reuse supplied panes.

---Public commands for one Select invocation. No window or Session internals.
---@class picker.select.Actions<T>
---@field toggle_detail fun()
---@field confirm fun()
---@field cancel fun()
---@field move fun(delta: integer)
---@field page fun(direction: integer)
---@field choice fun(): T?, integer?

return {}

-- Shared popup type definitions used across the layout, rendering, and
-- instance layers. Spec-specific types remain in spec.lua.

---@alias popup.border
---| string[]
---| 'none'
---| 'single'
---| 'double'
---| 'rounded'
---| 'solid'
---| 'shadow'

---@class popup.rect
---@field row integer
---@field col integer
---@field width integer
---@field height integer

---@class popup.border_info
---@field chars string[]
---@field width { top: integer, right: integer, bottom: integer, left: integer }

---@class popup.resolved_rect
---@field visual_rect popup.rect
---@field content_rect popup.rect
---@field border popup.border_info

---@alias popup.size
---| { flex: integer }
---| { fixed: integer }

---@class popup.win_config
---@field external? boolean
---@field fixed? boolean
---@field focusable? boolean
---@field footer? string|string[]
---@field footer_pos? 'center'|'left'|'right'
---@field hide? boolean
---@field mouse? boolean
---@field relative? 'cursor'|'editor'|'laststatus'|'mouse'|'tabline'|'win'
---@field style? ''|'minimal'
---@field noautocmd? boolean
---@field vertical? boolean
---@field win? integer
---@field zindex? integer
---@field anchor? 'NW'|'NE'|'SW'|'SE'
---@field bufpos? integer[]
---@field split? 'left'|'right'|'above'|'below'
---@field title? string|string[]
---@field title_pos? 'center'|'left'|'right'
---@field _cmdline_offset? integer

---@alias popup.node
---| popup.node.pane
---| popup.node.row
---| popup.node.col

---@class popup.node.pane
---@field id? string
---@field type 'pane'
---@field size? popup.size
---@field border popup.border
---@field enter boolean
---@field win_config popup.win_config
---@field content? string[]
---@field buf? integer

---@class popup.node.row
---@field type 'row'
---@field size? popup.size
---@field gap integer
---@field children popup.node[]

---@class popup.node.col
---@field type 'col'
---@field size? popup.size
---@field gap integer
---@field children popup.node[]

---@class popup.node.root
---@field type 'root'
---@field row integer
---@field col integer
---@field width integer
---@field height integer
---@field border popup.border
---@field enter boolean
---@field win_config popup.win_config
---@field zindex integer
---@field layout? popup.node

---@class popup.config.pane
---@field type 'pane'
---@field id? string
---@field rect popup.rect
---@field border popup.border
---@field enter boolean
---@field win_config popup.win_config
---@field content? string[]
---@field buf? integer

---@class popup.config.row
---@field type 'row'
---@field rect popup.rect
---@field gap integer
---@field children popup.config.child[]

---@class popup.config.col
---@field type 'col'
---@field rect popup.rect
---@field gap integer
---@field children popup.config.child[]

---@class popup.config.root
---@field type 'root'
---@field rect popup.rect
---@field border popup.border
---@field enter boolean
---@field win_config popup.win_config
---@field zindex integer
---@field layout? popup.config.child
---@field content? string[]
---@field buf? integer

---@alias popup.config.child
---| popup.config.pane
---| popup.config.row
---| popup.config.col

---@alias popup.render.node
---| popup.config.root
---| popup.config.pane
---| popup.config.row
---| popup.config.col

---@class popup.pane
---@field win? integer
---@field buf? integer
---@field id? string
---@field scratch boolean

---@class popup.instance
---@field _node popup.node.root
---@field _config? popup.config.root
---@field _root? popup.pane
---@field _panes { list: popup.pane[], map: table<string, popup.pane> }
---@field _closing boolean
---@field _listeners table<string, fun(...)[]>
---@field _group? popup.group
---@field open fun(self: popup.instance): popup.instance
---@field hide fun(self: popup.instance): popup.instance
---@field close fun(self: popup.instance): popup.instance
---@field update fun(self: popup.instance, fn: fun(node: popup.node.root)): popup.instance
---@field render fun(self: popup.instance): popup.instance
---@field root fun(self: popup.instance): popup.pane?
---@field panes fun(self: popup.instance): popup.pane[]
---@field pane fun(self: popup.instance, id: string): popup.pane?
---@field is_open fun(self: popup.instance): boolean
---@field set_pane_buf fun(self: popup.instance, id: string, buf: integer): popup.instance
---@field use fun(self: popup.instance, plugin: popup.plugin): popup.instance
---@field on fun(self: popup.instance, event: popup.event, callback: fun(...)): popup.instance
---@field off fun(self: popup.instance, event: popup.event, callback: fun(...)): popup.instance
---@field emit fun(self: popup.instance, event: popup.event, ...): popup.instance
---@field join_group fun(self: popup.instance, name: string): popup.instance
---@field leave_group fun(self: popup.instance): popup.instance

---@class popup.plugin.table
---@field name? string
---@field opts? table
---@field apply fun(instance: popup.instance, opts: table)

---@alias popup.plugin fun(instance: popup.instance) | popup.plugin.table

---@alias popup.builtin_event
---| 'open'
---| 'close'
---| 'hide'
---| 'update'
---| 'render'

---@alias popup.event popup.builtin_event | string

---@class popup.group.config
---@field on_join? fun(instance: popup.instance, group: popup.group)
---@field on_leave? fun(instance: popup.instance, group: popup.group)

---@class popup.group
---@field name string
---@field instances popup.instance[]
---@field config popup.group.config
---@field add fun(self: popup.group, instance: popup.instance)
---@field remove fun(self: popup.group, instance: popup.instance)

return {}

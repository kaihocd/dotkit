-- Shared popup type definitions used across the layout, rendering, and
-- instance layers. Spec-specific types remain in spec.lua.

---Named border style or custom border characters in Neovim's border order.
---@alias popup.border
---| string[]
---| 'none'
---| 'single'
---| 'double'
---| 'rounded'
---| 'solid'
---| 'shadow'

---Rectangle measured in screen cells.
---@class popup.rect
---@field row integer Zero-based top edge.
---@field col integer Zero-based left edge.
---@field width integer Horizontal extent in cells.
---@field height integer Vertical extent in cells.

---Normalized border characters and occupied space on each side.
---@class popup.border_info
---@field chars string[] Eight border segments, starting at the top-left corner.
---@field width { top: integer, right: integer, bottom: integer, left: integer } Per-side border thickness.

---Geometry before and after subtracting the border.
---@class popup.resolved_rect
---@field visual_rect popup.rect Outer rectangle including the border.
---@field content_rect popup.rect Inner rectangle available for buffer content.
---@field border popup.border_info Normalized border used to calculate the inner rectangle.

---Size along the parent's main axis: a flex weight or a fixed cell count.
---@alias popup.size
---| { flex: integer }
---| { fixed: integer }

---Native window options forwarded to Neovim; layout geometry is managed separately.
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

---Unresolved layout child: a window pane or a horizontal/vertical container.
---@alias popup.node
---| popup.node.pane
---| popup.node.row
---| popup.node.col

---Pane declaration before layout resolves its position and dimensions.
---@class popup.node.pane
---@field id? string
---@field type 'pane'
---@field size? popup.size
---@field border popup.border
---@field enter boolean
---@field win_config popup.win_config
---@field content? string[]
---@field buf? integer

---Horizontal container allocating width among its children.
---@class popup.node.row
---@field type 'row'
---@field size? popup.size
---@field gap integer
---@field children popup.node[]

---Vertical container allocating height among its children.
---@class popup.node.col
---@field type 'col'
---@field size? popup.size
---@field gap integer
---@field children popup.node[]

---Top-level declaration owning the popup geometry and optional layout tree.
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

---Pane configuration with geometry resolved by the layout engine.
---@class popup.config.pane
---@field type 'pane'
---@field id? string
---@field rect popup.rect
---@field border popup.border
---@field enter boolean
---@field win_config popup.win_config
---@field content? string[]
---@field buf? integer

---Resolved horizontal container and its positioned children.
---@class popup.config.row
---@field type 'row'
---@field rect popup.rect
---@field gap integer
---@field children popup.config.child[]

---Resolved vertical container and its positioned children.
---@class popup.config.col
---@field type 'col'
---@field rect popup.rect
---@field gap integer
---@field children popup.config.child[]

---Resolved root configuration consumed by the renderer.
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

---Any resolved child in the configuration tree.
---@alias popup.config.child
---| popup.config.pane
---| popup.config.row
---| popup.config.col

---Any resolved node, including the root, that rendering may visit.
---@alias popup.render.node
---| popup.config.root
---| popup.config.pane
---| popup.config.row
---| popup.config.col

---Runtime window/buffer handles and buffer ownership for a rendered pane.
---@class popup.pane
---@field win? integer Neovim window handle, when available.
---@field buf? integer Neovim buffer handle, when available.
---@field id? string Identifier used for pane lookup.
---@field scratch boolean Whether popup owns the scratch buffer.

---Popup lifecycle controller holding the declaration, resolved layout and live panes.
---@class popup.instance
---@field _node popup.node.root
---@field _config? popup.config.root
---@field _root? popup.pane
---@field _panes { list: popup.pane[], map: table<string, popup.pane> }
---@field _closing boolean
---@field _listeners table<string, fun(...)[]>
---@field _group? popup.group
---@field _group_membership? table Unique identity for a reentrant group membership.
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

---Extension descriptor installed through instance:use().
---@class popup.plugin.table
---@field name? string Extension name.
---@field opts? table Options passed to the apply callback.
---@field apply fun(instance: popup.instance, opts: table) Install behavior or lifecycle listeners.

---Extension expressed as an installer function or a descriptor with options.
---@alias popup.plugin fun(instance: popup.instance) | popup.plugin.table

---Lifecycle event names emitted by the popup instance.
---@alias popup.builtin_event
---| 'open'
---| 'close'
---| 'hide'
---| 'update'
---| 'render'

---Built-in lifecycle event or a caller-defined custom event name.
---@alias popup.event popup.builtin_event | string

---Optional callbacks for changes to group membership.
---@class popup.group.config
---@field on_join? fun(instance: popup.instance, group: popup.group) Observes established membership. Errors roll back this join unless the hook has left/rejoined.
---@field on_leave? fun(instance: popup.instance, group: popup.group) Observes completed removal. Errors propagate without restoring membership; rejoining is allowed.

---Named collection of popup instances with membership callbacks.
---@class popup.group
---@field name string Group identifier.
---@field instances popup.instance[] Current group members.
---@field config popup.group.config Membership callbacks.
---@field add fun(self: popup.group, instance: popup.instance) Add an instance to the group.
---@field remove fun(self: popup.group, instance: popup.instance) Remove an instance from the group.

return {}

# Picker / Select 统一 Layout 重构 TODO

> Select detail 的最新交互和实施步骤由 [select-detail-transition-todo.md](select-detail-transition-todo.md) 接管：仅截断项可进入全文，默认在原 list 区域切换，使用 Neovim 原生 wrap。本文后续旧侧边弹窗规则已废弃；新行为尚待实施。

状态：实施中。阶段证据见 [layout-refactor-acceptance.md](layout-refactor-acceptance.md)；未勾选项不得视为已经完成。

实施补充：Select 默认布局初始只挂载 input/list，全文动作临时挂载独立 detail，退出后恢复；自定义布局省略 detail 时不自动插入 pane。此规则取代旧的复用 list 及 render→restore 顺序。

## 目标与不可变决策

- Picker 与 Select 统一使用单一公共布局入口：`view.layout(panes, context)`。
- 不保留兼容层；项目仍在开发阶段，旧公共布局字段直接删除。
- 删除公共 `view.root`、`view.input`、`view.list`、`view.preview`、`view.detail`。
- `layout` callback 只负责组合 Window 已创建的 pane，不创建 pane、不创建 buffer、不修改 buffer、不拥有生命周期。
- Picker 提供 `panes.input`、`panes.list`、可用时的 `panes.preview`。
- Select 提供 `panes.input`、`panes.list`、`panes.detail`。
- Window 是 popup、pane、buffer、root geometry、layout tree mount/validation 的唯一 owner。
- Panel 只协调业务状态和用户动作；不得知道 border、buffer、layout tree 或低层 popup 资源。
- 不复制 PickerPanel 给 Select，不引入通用 LayoutController、事件总线或 speculative framework。
- 默认布局必须保持当前用户可见行为；自定义布局是新增/统一 API，不改变过滤、选择、preview/detail、callback、group、mouse/focus 语义。

## 目标公共 API

```lua
picker.open({
  view = {
    layout = function(panes, context)
      local main = popup.col({
        children = { panes.input, panes.list },
      })
      return popup.row({
        gap = 1,
        children = { main, panes.preview },
      })
    end,
  },
})

picker.select(items, {
  view = {
    layout = function(panes, context)
      local main = popup.col({
        children = { panes.input, panes.list },
      })
      return popup.row({
        gap = 1,
        children = { main, panes.detail },
      })
    end,
  },
}, on_choice)
```

`layout` callback约束：

- 只接收稳定 pane 和只读语义上的 `{ width, height }` context。
- 只能返回 popup 原生 `pane`、`row`、`col` tree。
- 必须使用 Window 提供的 pane 对象。
- 禁止调用 `popup.pane()`。
- 禁止替换 `panes.input/list/preview/detail`。
- 禁止写入或替换 `pane.buf`。
- 不允许重复引用同一个 pane。
- 必需 pane 缺失时，Window 在 mount 前报错并清理资源。

---

## Phase 0：冻结、基线与半成品隔离

### 实施

- [ ] 记录当前 `git status --short`，标记与本任务无关的修改，禁止 reset 或 checkout 整棵工作树。
- [ ] 确认 `lua/picker/picker-bak/` 和 `lua/picker/select-bak/` 存在。
- [ ] 对两个 backup 分别运行 `diff -qr`，确认 backup 与对应重构开始前版本一致。
- [ ] 保存 backup 文件 SHA-256 清单，并在每个最终阶段复验。
- [ ] 记录当前工作实现中已完成且要保留的对象化重构：PickerPanel、PickerWindow、PickerSelection、PickerBindings、SelectPanel、SelectWindow、SelectList、SelectBindings。
- [ ] 将当前尚未完成的单一 layout 半成品视为废弃设计，不在其上继续做局部修补。
- [ ] 保留 `select-bak`/`picker-bak` 只作对照；运行代码、测试和 demo 不得 require backup。

### 基线命令与证据

```sh
node tests/picker.ts
node tests/select.ts
node tests/select-ui.ts
node tests/selection.ts
node tests/check-lua.ts
node tests/picker-types.ts
node tests/selection-types.ts
node_modules/.bin/stylua --check lua tests
git diff --check
```

- [ ] 每条命令保存输出；失败必须记录为基线失败，不得伪装为迁移结果。
- [ ] 记录 Picker/Select 默认布局实际 pane、窗口尺寸、mouse/focus、preview/detail 行为。
- [ ] 在 `docs/layout-refactor-acceptance.md` 建立证据表；最终只在证据真实取得后勾选。

### 阶段出口

- [ ] backup hash 可复验。
- [ ] 基线状态和无关修改已记录。
- [ ] 当前半成品 layout 的文件范围明确，未把 backup 当工作代码修改。

---

## Phase 1：先建立统一契约，不改行为实现

### 类型

- [ ] 在 `lua/picker/picker/config.lua` 保留 `ViewOptions` 中的 `layout?`、`icon?`、`presentation?`；删除 `root/input/list/preview` 字段。
- [ ] 在 `lua/picker/select/types.lua` 的 `ViewOptions` 中保留 Select-specific 的显示/过滤字段和 `layout?`；删除 `root/input/list/detail` 字段。
- [ ] 明确定义 `LayoutPanes` 和 `LayoutContext`，注释说明 pane ownership 与 callback 禁止事项。
- [ ] 检查返回类型与 popup 类型定义，必要时用现有 LuaLS cast/workaround；不关闭诊断、不伪造通过。

### 配置验证

- [ ] Picker options 只校验 `view` 是 table、`view.layout` 是 nil/function，以及 icon/presentation 等非布局字段。
- [ ] Select config 只校验 Select-specific 字段和 `view.layout`；删除对旧 pane/root 字段的默认 merge。
- [ ] 对旧字段显式报错而不是静默忽略：`view.root/input/list/preview/detail is no longer supported; use view.layout`。
- [ ] 明确 layout callback 返回非法 tree 的错误归属为 Window/layout builder。

### 文档

- [ ] 更新 README 和 picker/select API 注释，只展示单一 layout 示例。
- [ ] 明确 `layout` 只组合 supplied panes；禁止创建 pane、buffer 和访问内部生命周期。
- [ ] 将旧字段内容标记为历史迁移资料，不再作为当前 API 示例。

### 阶段出口

- [ ] 两个公共类型都只暴露单一 layout 入口。
- [ ] 旧配置字段有明确错误，不存在静默兼容。
- [ ] 此阶段不改变默认运行时布局；类型/验证测试已更新并通过。

---

## Phase 2：Picker 全量迁移到 layout-only

### Picker Window/layout

文件范围：

```text
lua/picker/picker/window/layout.lua
lua/picker/picker/window/init.lua
lua/picker/picker/options.lua
lua/picker/picker/config.lua
lua/picker/picker/types.lua
```

- [ ] 重写 `window/layout.lua`，使其只拥有：root 默认几何、默认 pane factory、default layout、layout tree validation、build。
- [ ] `build` 接收已解析的 layout callback/必要状态和 Window-owned buffers，不再读取 `options.root/input/list/preview`。
- [ ] 内部创建稳定 pane：input、list；preview 根据 Picker 当前 preview 状态创建或不创建。
- [ ] 默认 pane spec 只在 layout builder 中定义一次：input/list/preview 的默认 size、border、win_config、enter。
- [ ] 默认 layout 也通过同一 callback/validation 路径构造，不绕过校验。
- [ ] layout callback 的 context 使用实际 root width/height。
- [ ] validation 检查 node 类型、重复 node、pane identity、pane buffer identity、必需 pane。
- [ ] layout callback 错误、非法 tree、缺 pane、重复 pane、替换 pane/buffer 时，在 mount 前完整释放资源。
- [ ] `PickerWindow.resize()` 重新 build layout tree，但保留 buffer/pane 语义与 preview viewport。
- [ ] `toggle_preview()` 只改变 preview 状态并重新 build，不让 Panel 操作 layout 细节。
- [ ] `PickerWindow:pane(id)`、`focused()`、`hit()`、`contains()`、`page_size()` 全按 pane ID 和实际窗口工作。
- [ ] 删除 Window 对旧 options pane/root 字段的所有读取。

### Picker Panel 与调用链

- [ ] `PickerPanel.new()` 只把 resolved `view.layout` 传给 Window；不把旧 pane/root 配置作为 Window override。
- [ ] Panel 保持 selection/list/input/preview 的业务 ownership，不读取 layout tree。
- [ ] Preview 的显示 capability 继续通过 Window 提供的窄接口传递。
- [ ] close、resize、preview toggle、group replacement 的行为与基线一致。

### Picker 测试

- [ ] 删除旧 `view.root/input/list/preview` override 测试。
- [ ] 增加 layout callback 正例：默认布局、左右布局、上下布局、嵌套 row/col。
- [ ] 增加 pane identity/ID/context 测试。
- [ ] 增加非法返回值、缺 input、缺 list、重复 pane、创建新 pane、替换 pane、callback 抛错测试。
- [ ] 增加 layout failure 的 buffer/popup 清理测试。
- [ ] 增加 resize、preview toggle、preview viewport、mouse/focus/group 测试。
- [ ] 更新 demo 和测试注释，不再使用旧字段。

### 阶段出口

- [ ] Picker 运行代码无旧字段读取。
- [ ] Picker layout-only 测试通过。
- [ ] Picker 完整测试、LuaLS、StyLua、diff check 通过。
- [ ] Picker backup 未修改。

---

## Phase 3：Select 全量迁移到 layout-only

### Select Window/layout

文件范围：

```text
lua/picker/select/window/layout.lua
lua/picker/select/window/init.lua
lua/picker/select/window/detail.lua
lua/picker/select/config.lua
lua/picker/select/types.lua
```

- [ ] 删除 Select config 中 root/input/list/detail 的公共配置默认值和校验；保留非布局配置。
- [ ] `window/layout.lua` 只包含可读的概念函数：`measure`、`make_input_pane`、`make_list_pane`、`make_detail_pane`、`default_layout`、`validate_layout`、`root_geometry`、`build`。
- [ ] 默认 border、size、win_config 只在 layout builder 的 pane factory 定义一次。
- [x] input/list/detail buffers 由 SelectWindow 统一创建、登记、清理。
- [ ] layout callback 接收 input/list/detail stable pane；默认 layout 只组合 input/list。
- [ ] detail 不再使用 `single` 的临时特殊默认；默认视觉 border 与 list 保持明确一致。
- [x] detail 成为真正独立 pane：独立 buffer、window、内容、wrap、cursorline、viewport。
- [x] `DetailPane` 只操作 detail pane，不再接收或修改 list pane。
- [ ] `show_detail()` 使用 `pane('detail')`；`leave_detail()` 恢复 detail state 并保持 list 内容/selection 不变。
- [ ] detail 是否在布局中出现由 layout tree 决定；Window 不以 pane 位置猜测身份。
- [ ] `query`、hint、page size、hit test、focus、scroll 全按 pane ID 和实际窗口工作。
- [ ] layout callback 错误、非法 tree、缺 pane、重复 pane 时释放全部 Window-owned buffers。
- [ ] 删除 `geometry()` 与 `build()` 重复/模糊的旧接口，只保留一个清晰的 build 流程。

### Select Panel/Bindings

- [ ] SelectPanel 只传递 `view.layout` 给 SelectWindow，不保存 pane/root/detail spec。
- [ ] Panel 只协调 list、window、bindings、close/completion 和 detail 用户动作。
- [ ] SelectBindings 继续独占 autocmd IDs/configured actions，不依赖 layout 内部。
- [ ] callback reopen、group replacement、close-once、late event 行为保持基线。

### Select 测试

- [ ] 删除旧 `view.root/input/list/detail` override 测试。
- [ ] 增加默认布局正例。
- [ ] 增加自定义左右布局、上下布局、嵌套布局。
- [ ] 增加 layout callback 收到正确 pane IDs/context 的测试。
- [ ] 增加非法 layout、缺 input/list、重复 pane、创建新 pane、替换 pane、callback 抛错测试。
- [ ] 增加独立 detail buffer 测试，确认 detail 不修改 list 内容。
- [ ] 增加 detail scroll、viewport restore、过滤退出 detail、selection identity 保持测试。
- [ ] 增加自定义布局下 mouse hit、focus cancel、resize、group、callback reopen 测试。
- [ ] 保留并通过原有 literal filter、numeric original index、duplicate labels、false-valued item 测试。
- [ ] 更新 `tests/select-ui.lua`、`tests/select-objects.lua`、demo 和注释。

### 阶段出口

- [ ] Select 运行代码无旧字段读取。
- [ ] Select 不再有 working `session/`、Controller、Lifecycle 路径。
- [ ] Select layout-only 和 detail 独立 pane 测试通过。
- [ ] Select 完整测试、LuaLS、StyLua、diff check 通过。
- [ ] Select backup 未修改。

---

## Phase 4：旧代码、测试、文档彻底清理

### 运行代码扫描

```sh
rg -n 'view\.(root|input|list|preview|detail)' lua tests README.md docs --glob '!**/*-bak/**'
rg -n 'options\.(root|input|list|preview|detail)' lua tests --glob '!**/*-bak/**'
rg -n 'config\.(root|input|list|preview|detail)' lua/picker/picker lua/picker/select
rg -n 'popup\.pane\(' lua/picker/picker lua/picker/select
rg -n 'picker\.select\.session' lua tests --glob '!**/*-bak/**'
rg -n 'Controller|Lifecycle' lua/picker/select tests --glob '!**/*-bak/**'
```

- [ ] 运行代码不再读取旧布局字段。
- [ ] 用户测试/demo 不再使用旧字段。
- [ ] `popup.pane()` 只存在于 PickerWindow/SelectWindow layout builder，不出现在 layout callback 示例或公共代码路径。
- [ ] Select working `session/` 不存在；backup 中的 session 只作为冻结历史命中。
- [ ] Select working Controller/Lifecycle 名称不存在；Picker 历史文档命中必须明确标记为历史。
- [ ] 不修改、不格式化、不重命名 backup 内容。

### 文档

- [ ] 新增/更新统一 layout 使用文档：Picker 和 Select 各给默认、左右、上下、嵌套示例。
- [ ] 说明 pane ID、context、合法 tree、ownership 和禁止事项。
- [ ] 更新 `README.md`、Picker/Select architecture review、plan、acceptance、TODO。
- [ ] 旧字段说明改为“已删除的开发期 API”，不保留可复制的旧代码示例。
- [ ] 记录为什么没有共享 PickerPanel、为什么只共享 layout contract。

### 阶段出口

- [ ] 工作代码、测试、demo、当前文档只描述 layout-only API。
- [ ] 允许命中的旧词只在 backup 或明确历史记录中出现。

---

## Phase 5：完整自动化验证

在插件目录执行：

```sh
node tests/picker.ts
node tests/select.ts
node tests/select-ui.ts
node tests/selection.ts
node tests/check-lua.ts
node tests/picker-types.ts
node tests/selection-types.ts
node_modules/.bin/stylua --check lua tests
git diff --check
```

- [ ] 全部命令实际执行并保存日志。
- [ ] Picker 默认行为通过。
- [ ] Picker 自定义 layout 通过。
- [ ] Select 默认行为通过。
- [ ] Select 自定义 layout 通过。
- [ ] detail 独立 pane、scroll、viewport restore 通过。
- [ ] selection identity、filtering、numeric query、false item、duplicate labels 通过。
- [ ] mouse/focus/group/reopen/cleanup 通过。
- [ ] LuaLS 正例通过；已知 LuaLS limitation 明确输出，不改成虚假 PASS。
- [ ] StyLua 和 `git diff --check` 通过。
- [ ] backup hash 复验通过。
- [ ] 静态依赖图检查无新增循环。

---

## Phase 6：人工终端验收

自动化不能替代本阶段。

- [ ] 运行 Picker demo，检查默认布局。
- [ ] 运行 Picker 左右 layout，检查 input/list/preview 的真实位置和尺寸。
- [ ] 运行 Picker 上下 layout，检查 resize、preview scroll、focus。
- [ ] 运行 Select demo，检查默认布局。
- [ ] 运行 Select 左右 layout，检查 input/list/detail border 和尺寸一致性。
- [ ] 运行 Select 上下/嵌套 layout，检查 list 点击、input focus、detail scroll。
- [ ] 检查长文本、Unicode、clipping、hint、prompt。
- [ ] 检查过滤期间 detail 退出和 viewport 恢复。
- [ ] 检查外部点击、外部 focus、Esc、group replacement、callback reopen。
- [ ] 检查窄终端/小屏幕下错误提示和资源清理。
- [ ] 将人工结果记录到 `docs/layout-refactor-acceptance.md`，不要只口头宣布完成。

---

## 最终完成标准

只有同时满足以下条件，才能宣布完成：

- [ ] Picker 和 Select 的公共布局 API 都只有 `view.layout`。
- [ ] 旧 root/input/list/preview/detail 公共字段已删除，无兼容 adapter。
- [ ] Window 独占 pane、buffer、popup、geometry、mount 和清理。
- [ ] layout callback 只组合 supplied panes。
- [ ] Select detail 是独立 pane，不复用 list pane。
- [ ] 默认视觉和既有交互行为保持不变。
- [ ] 全部自动化命令、结构扫描、格式检查、backup hash 通过。
- [ ] 文档和测试只描述新 API。
- [ ] 人工终端验收完成并记录。

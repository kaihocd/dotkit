# Select 全文原位切换：实施 TODO

状态：已实现核心原位切换、截断动作门槛、context.detail、原生 wrap，自动化通过；人工验收待执行。本文接管统一 layout 计划中 Select detail 的交互、布局状态和恢复部分；取代临时右侧弹窗方案。不是完成记录。

## 原始换行修复

- 修复真实调用链中 list 单行投影丢失全文换行的问题：Entry 分别保存 `text` 与 `full_text`，Panel 将后者交给 detail。
- 公共 select() + formatter + 映射回调回归验证连续空行、末尾换行、长行与 resize 内容保持不变。
- Select/UI、LuaLS、public types 通过：`/tmp/detail-newlines.log`、`/tmp/detail-newlines-checks.log`。原生 wrap 仍负责视觉折行，不插入宽度相关换行。

## 本轮实施证据

- 修改前完整快照保存在 `/tmp/picker-detail-before-*`。
- 删除右侧拼树/扩宽 root/临时 detail 标记，Window 统一 rebuild。
- 新增 context false→true→false、几何不变、短项动作无效、buffer 不变和返回选择回归。
- 原 UI/对象测试迁移为独立 buffer + 原位替换，不再假定两个 pane 同时挂载。
- 全套 Picker/Select/UI/Selection/LuaLS/types：`/tmp/detail-transition-full.log`，通过；类型推断局限仍明确输出。
- demo-select 展示可复制的状态化 layout；docs/layout.md 与类型注释已更新。
- 人工终端体验尚未验收；以下清单未逐项核实的部分保持未勾选。

## 一、已确认的行为契约

- 默认普通状态：input + list；全文状态：input + detail。
- detail 占用原 list 区域；root 位置、宽高不变，input 窗口、buffer、query 不变。
- list/detail 使用独立 buffer，不把全文写入 list。
- 只有当前选中项在列表实际渲染中被截断，才允许进入全文。
- 未截断或无选中项：不显示全文提示，全文动作无效。
- 输入区域容纳不下提示时隐藏提示，但截断项仍可用全文动作。
- 全文状态下全文动作始终返回列表，不再次检查截断。
- 默认键为 `<C-l>`；判断适用于 `toggle_detail` 动作本身，包括自定义映射调用。
- 返回列表保留选择、光标和 viewport；查询变化、移动、确认继续遵守已有 Panel 行为，不增加第二套 selection。
- 长行由 Neovim `wrap` 视觉折行；禁止按显示宽度拆字符串或插入换行。
- 原文本的真实换行按 buffer API 写入真实行，不增删文本换行。
- 自定义布局通过 `context.detail` 决定树；Window 不额外插入 pane 或扩宽 root。

## 二、公共 layout 契约

```lua
view = {
  -- Initially, on resize, and whenever full-text mode changes.
  layout = function(panes, context)
    return require('popup').col({
      children = {
        panes.input,
        -- Replace the list region, not an additional popup.
        context.detail and panes.detail or panes.list,
      },
    })
  end,
}
```

- `context.detail: boolean`：当前是否处于全文模式，不表示 capability。
- `context.width/height`：root 可用预算；callback 不修改 root 几何。
- input 始终必需；普通模式 list 必需；全文模式 detail 必需。
- callback 可以显式同时包含 list/detail，但默认和推荐示例为原位切换。
- 所有 supplied pane（包括未挂载的 pane）仍校验原始身份、ID、类型和 buffer。
- 拒绝缺少当前必需角色、重复节点、循环、非法 children 和 nil/false 返回。
- 不改 Picker 的 LayoutContext 或 preview 行为。

## 三、实施顺序

### Phase 0：记录当前状态与删除边界

- [ ] 阅读当前 Window/layout/detail、Panel、Bindings、types、renderer 和相关测试，不依赖旧汇报推断代码。
- [ ] 保存本次修改前 status/相关文件快照；保留无关工作树修改。
- [ ] 复验 `picker-bak/` 和 `select-bak/` hash；禁止修改 backup。
- [ ] 记录当前测试结果，区分已有失败和本次引入失败。
- [ ] 列明需删除的旧行为：`show_detail()` 扩宽 root、右侧 popup.row、`_temporary_detail` 及临时布局恢复分支。

出口：有可追溯起点，无需重做 Picker 或非布局对象重构。

### Phase 1：先固定新契约与回归断言

- [ ] 在 `select/types.lua` 的 LayoutContext 注释中加入 `detail`，明确 callback 执行时机。
- [ ] 更新 ResolvedView/layout callback 注释，保证 public/resolved 类型一致。
- [ ] 编写失败回归：短项目无提示且全文动作无效；截断项能进入。
- [ ] 编写失败回归：原位替换后 root/input 几何不变，input win/buf/query 不变。
- [ ] 编写失败回归：list buffer 未修改，返回后 selection/cursor/viewport 恢复。
- [ ] 编写失败回归：callback 依次看到 false→true→false；resize 收到当前模式。
- [ ] 迁移旧测试的布局契约，不删除列表内容、装饰、身份和资源断言来获取通过。

出口：新测试明确复现当前侧边模型与目标的差异。

### Phase 2：建立唯一的布局状态与更新路径

主要文件：`select/window/init.lua`、`select/window/layout.lua`。

- [ ] Window 明确拥有全文状态；避免 bool、Detail.active、文本缓存各自决定模式而不同步。
- [ ] layout.build 接收全文状态，并放入 callback context。
- [ ] 默认 layout 使用 `context.detail and panes.detail or panes.list`。
- [ ] list/detail 默认 size/border 保持一致，默认值只有一处来源。
- [ ] 根据当前模式验证必需角色；保留未挂载 pane 身份与 buffer 校验。
- [ ] 首次创建、进入、退出、resize 共用清晰的布局构建/更新流程。
- [ ] 切换使用当前 root 预算和锚点，不因全文长度重新测量、不扩宽 root。
- [ ] 切换前保存 list viewport；返回时先确保 list 挂载及必要渲染完成，再恢复 viewport。
- [ ] 保留 input 原有 window/buffer，不能重新装饰导致 prefix extmark 重复。
- [ ] 保留原 list buffer 和 renderer 状态，确认 popup 卸载窗口不会删除 Window-owned buffer。
- [ ] 删除 `_temporary_detail`、右侧拼树、旧 root 扩宽及废弃恢复代码，不保留兼容分支。
- [ ] callback/mount/update 失败经 Panel 取消一次；Bindings detach，Window 清理所有已登记资源。

出口：Window 不再含隐藏的业务布局拼接；默认 detail 精确占用原 list 区域。

### Phase 3：统一截断判定、提示和动作

主要文件：`select/window/init.lua`、`select/panel.lua`、共享 list renderer（仅必要时修改）。

- [ ] 提供窄接口判断当前文本是否在实际 list pane 中截断，复用 renderer 的 width/padding/文本测量规则。
- [ ] 禁止把“候选不在 viewport 内”误判为“文本被截断”。
- [ ] Panel 先 refresh，再根据当前选中项判断；refresh 已关闭时立即退出。
- [ ] 未截断/无选项时 toggle_detail 不构建布局、不改变状态。
- [ ] hint 和 toggle_detail 使用同一个判定结果/规则，不维护两套近似逻辑。
- [ ] 全文状态只提供返回动作，不依赖已卸载 list 的宽度重新判断。
- [ ] resize 返回普通状态后基于实际新宽度更新提示。
- [ ] 过滤、移动、确认、取消沿用既有语义；明确经过 leave_detail 的路径不误恢复过期结果的 viewport。
- [ ] 验证任意映射调用 `actions.toggle_detail()` 也不能绕过截断门槛。

出口：能打开的项目与提示条件一致（提示空间不足除外）。

### Phase 4：Neovim 原生折行与详情渲染

主要文件：`select/window/detail.lua`。

- [ ] renderer 仅写入原始全文，设置 detail 显示选项及滚动；不操作 list/layout。
- [ ] 真实换行转换为 buffer 行；验证连续空行和末尾换行的保存语义。
- [ ] 长单行保持一个 buffer 行，启用 `wrap`，不按字数、字节或列宽硬折行。
- [ ] 明确配置影响折行的窗口选项，避免依赖用户全局配置造成测试与使用行为不一致。
- [ ] 使用 Neovim 显示行滚动，不自行模拟折行位置。
- [ ] resize 后由 Neovim 重新视觉折行，buffer 内容不变；恢复有效的 detail viewport。
- [ ] 删除旧“恢复 list 的 wrap/装饰”代码与误导注释。

出口：内容与显示职责分离，原始文本不因显示宽度变化而改变。

### Phase 5：完整测试与调用方迁移

- [ ] `select-layout.lua`：新 context、原位切换、状态化角色验证、上下/左右自定义布局。
- [ ] `select-ui.lua`：短项/截断项、hint 空间不足、Unicode、C-l 返回、鼠标、输入焦点。
- [ ] `select-objects.lua`：list 内容和 extmarks 不变，原选择与 viewport 恢复，callback reopen。
- [ ] 覆盖原始多行、空行、末尾换行、长单行与 resize 内容不变。
- [ ] 覆盖过滤/移动离开全文、确认原始 index、重复标签和 false item。
- [ ] 覆盖进入/退出/resize callback 失败，部分挂载失败与资源清理。
- [ ] 覆盖重复开关及关闭后的 late resize/action，确保无重复 callback。
- [ ] 更新所有 Select layout 测试 callback，支持当前必需角色；同时保留显式双 pane 自定义案例。
- [ ] 更新 Select demo：提供短项、截断长项和原位 layout 示例，可实际操作 C-l。

### Phase 6：注释、文档与验收记录

- [ ] `select/types.lua`：编辑器补全可见每个 pane/context 字段的含义、必需角色和执行时机。
- [ ] `docs/layout.md`：原位切换示例、截断门槛、原生 wrap、尺寸预算与 ownership。
- [ ] README 链接/示例与当前实现一致。
- [ ] 删除或明确标记旧“右侧临时 detail”“省略 detail 永远无法全文”说明。
- [ ] 更新统一 layout TODO/acceptance：本文接管 detail，旧通过记录为历史证据，不能证明新行为通过。
- [ ] 记录本轮真实命令、结果与日志，未运行项不勾选。

## 四、自动化出口

在插件目录执行并保存输出：

```sh
node tests/picker.ts
node tests/select.ts
node tests/select-ui.ts
node tests/selection.ts
node tests/check-lua.ts
node tests/picker-types.ts
node tests/selection-types.ts
```

- [ ] 全套通过，LuaLS 已知 inference limitation 仍单独报告。
- [ ] 从仓库根使用 `node_modules/.bin/stylua --check` 检查插件 lua/tests，不修改 backup。
- [ ] `git diff --check` 通过。
- [ ] backup hash 通过；运行模块无 backup require、循环或 Select→Picker 依赖。
- [ ] 静态检查 `show_detail` 不再扩宽 root 或自行构造 row/col。
- [ ] Picker 行为无变化；若触碰共享 popup/renderer，补跑真实 fff 搜索与 resume 集成。

## 五、人工终端出口

- [ ] 短项按 C-l 无效果，无全文提示。
- [ ] 截断项按 C-l 在原列表处显示，输入区和整体窗口不移动。
- [ ] 长行自然折行、上下滚动符合 Neovim 行为。
- [ ] 返回后原选择和滚动位置不变。
- [ ] 自定义布局从示例复制可用，resize/鼠标/焦点行为正常。
- [ ] 小屏幕和失败退出无残留窗口、不抢外部焦点。

只有代码、测试、注释和文档均符合新契约才能宣布实现完成；人工验收单独标记，不用 headless 结果代替。

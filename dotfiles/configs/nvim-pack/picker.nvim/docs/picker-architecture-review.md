# Picker 对象重构方案

状态：运行时迁移已实施。实际字段、旧代码映射与内部签名差异见 [实现核对与验收](picker-refactor-acceptance.md)；执行清单见 [picker-refactor-todo.md](picker-refactor-todo.md)。人工终端验收尚未完成。

本方案替代此前围绕 Session 的 Invocation / QueryState / ResultCoordinator 方案。
用户确认使用 `PickerList`，不使用 `PickerResults`。

## 范围与原则

- 先重构整个 files/grep Picker：公共入口、配置、backend、运行对象、列表、选择、窗口、预览、恢复和完成行为。
- Picker 专属模块全部位于 `lua/picker/picker/`，不占用共享 `picker.list`、`picker.selection` 的路径。
- 本轮不重构 Select、不迁移个人配置、不扩展公共 Source API。Picker 稳定后再评估 Select 的复用边界。
- 按对象状态和行为迁移，不先改名搬目录，不按行数拆文件，不引入仅转发的类。
- 有状态的领域概念使用对象；配置解析、格式化、命令执行等可以保留函数模块，不强行类化。
- 保持公共 open/resume/select、Actions 和 presentation 契约。

## 对象、方法与旧代码归属

以下为目标内部接口；实施时可收紧签名，但不得改变状态所有权。

| 对象/模块        | 主要方法                                                                                                                                                                   | 唯一职责与原代码来源                                                                                                                                                           |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Picker 公共入口  | `open(options)`、`resume()`                                                                                                                                                | 校验并复制配置、创建新 backend/Panel、保存最近一次值快照。来自 `picker/init.lua`、`snapshot.lua`；顶层 `picker/init.lua` API 保持不变                                          |
| PickerPanel      | `open()`、`close()`、`move(delta)`、`mark(direction)`、`confirm(mode)`、`quickfix()`、`resize()`；内部 `on_input_changed()`、`on_list_changed()`、`on_selection_changed()` | 一次 Picker 交互；组装对象、路由用户意图、一次性关闭与完成时序。来自 `session/init.lua` 和 `session/lifecycle.lua`，不保留搜索/绘制/调度实现                                   |
| PickerInput      | `value()`、`set_value(text)`、`changed(text)`、`flush()`、`close()`                                                                                                        | 最新原始查询、输入 debounce、待交付输入。来自 `Session:query_changed()` 和查询刷新判断。通过 InputPane 读写文本，不自行管理 buffer 或 autocmd                                  |
| PickerList       | `load(query)`、`move(index,delta)`、`resize(size,index)`、`cycle_match_mode()`、`restore(position)`、`interrupt_restore()`、`snapshot()`、`close()`                        | 已提交查询及其列表、分页、请求 generation、indexing retry、列表预取和位置恢复。来自 `session/search.lua`、`session/restore.lua` 及 Session refresh/resize/restore 中的列表逻辑 |
| PickerSelection  | `replace(entries,target)`、`current()`、`index()`、`can_move(delta)`、`move(delta)`、`toggle_mark()`、`marked_items()`、`restore_marks()`、`nearby()`                      | Picker Entry 身份适配；current/ordered marks 仍由其内部唯一的共享 Selection 实例保存。来自 `session/controller.lua`，不复制共享 Selection 状态                                 |
| PickerWindow     | `open()`、`close()`、`resize()`、`page_size()`、`show_list(page,selection_state)`、`show_selection(state)`、`focused()`、`hit()`、`toggle_preview()`                       | popup、buffers、pane 资源及布局；内部组合 InputPane/ListPane/PreviewPane。来自 `session/view.lua`、`session/view/` 和 `config.layout()`                                        |
| PickerPreview    | `show(entry,nearby)`、`invalidate()`、`close()`                                                                                                                            | 预览请求和新鲜度、内容交付；组合 Content/Cache，向 PreviewPane 交付。来自 `session/preview/` 和 `Session:update_preview()`，不接收完整 Window                                  |
| PickerCompletion | `execute(result,origin)`                                                                                                                                                   | edit/split/vsplit/tab/quickfix 的 Neovim 操作，保持函数模块即可。来自 `session/completion.lua`；Panel 在清理完成后调用，不由 Completion 关闭 Panel                             |
| PickerBindings   | `attach()`、`detach()`                                                                                                                                                     | mappings/autocmd 的注册、句柄及释放；将事件转为窄回调。来自 `session/bindings.lua` 和 `Session:bind()`。部分注册失败也必须可清理                                               |
| Actions 边界模块 | `create(operations,run)`                                                                                                                                                   | 保留公开命令参数校验及受保护执行；来自 `session/actions.lua`，不强造有状态类                                                                                                   |

### 必须消除的重复所有权

- Input 保存最新原始查询及 debounce；List 保存已提交查询和列表任务 generation。这是两种不同状态，不共用或互相修改 revision。
- TextChanged 等 autocmd 只由 Bindings 注册；Input 处理传入的文本变化，不再自行 watch。
- InputPane/ListPane/PreviewPane 只放在 Window 子域。Input 使用 InputPane 窄接口；Preview 使用 PreviewPane 窄接口。
- List 独占 retry/continuation/prefetch 调度。内部 Restore 只推进恢复步骤，不另建重试循环。
- Selection 是 current/marks 的唯一事实来源；Window 只持有用于显示的行映射，List 只提供建议 target。
- Panel 独占 started/closed/completion-once 和清理协议。不会再同时有 Panel 与独立 Lifecycle 保存相同状态。
- Window 独占 UI 资源释放；Panel 负责何时调用各对象 close，而非亲自删除 buffers。

## 依赖与事件流

```text
公共入口 → options/backend/snapshot → PickerPanel
PickerPanel → Input / List / Selection / Window / Preview / Bindings / Completion
PickerList → files/grep 分页实现 → fff backend
PickerSelection → 共享 picker.selection
PickerWindow → InputPane / ListPane / PreviewPane → popup、共享 picker.list
PickerPreview → Content → Cache
PickerInput → InputPane 窄接口
PickerPreview → PreviewPane 窄接口
```

Bindings 只得到资源注册接口与回调，不得到整个 Panel。所有子对象都不得读取 Panel 私有字段。

流程：

1. 输入事件 → Input 更新原始查询并 debounce → Panel 收到查询 → List 加载。
2. List 交付页面及 target → Panel 更新 Selection → Window 呈现值状态 → Preview 请求当前项。
3. 页内移动只更新 Selection；跨页移动向 List 请求页面；List 不修改 Selection。
4. 确认/标记/分页等需要最新查询的操作，先同步 flush 输入；具体延续行为保持现有测试语义。
5. close：先标记关闭防重入，趁输入仍存在捕获值快照，停止 Input/List/Preview，解绑事件，释放 Window，恢复 origin，最后完成一次回调。保留现有调度和 group 重入保护。

不引入通用事件总线。对象通过少量显式回调交付数据和错误；Panel 提供统一错误关闭边界。

## 目标目录

路径均相对 `lua/picker/picker/`；这不是要求预先创建的空文件清单。

```text
init.lua                 # 公共 open/resume 和最近快照
options.lua              # 公共参数解析、校验、复制
config.lua               # 非 UI 的默认值
presentation.lua         # UI 配置解析
snapshot.lua             # 值快照，不读取 Panel 私有对象
panel.lua                # PickerPanel、关闭协议
selection.lua            # PickerSelection
completion.lua           # 完成命令
backend/fff.lua
input.lua                # PickerInput
list/
  init.lua               # PickerList 与任务调度
  pages.lua              # 共同页缓存、交付、pending target、预取 freshness
  files.lua              # files 逻辑位置
  grep.lua               # grep continuation（匹配模式由 List 持有）
  restore.lua            # 有界位置恢复
window/
  init.lua               # PickerWindow 和资源所有权
  input.lua              # InputPane
  list.lua               # ListPane、映射与装饰
  preview.lua            # PreviewPane、viewport
  layout.lua             # 实际布局声明/计算，非转发
  format.lua             # 默认 files/grep 行格式化
  row.lua                # 自定义 formatter 调用、隔离与校验
  icons.lua
  signs.lua
  syntax.lua             # grep 命中行的 snippet 高亮
preview/
  init.lua               # PickerPreview
  content.lua
  cache.lua
  defaults.lua
editor/
  bindings.lua
  actions.lua
types.lua
```

现有 `session/syntax.lua` 服务于 grep 行格式化，不应误迁为预览文件语法 owner。预览 scratch syntax/viewport 归 PreviewPane。
现有 `session/list/init.lua` 的格式化校验与 `session/format.lua` 归 Window 的行格式化边界，不进入负责后端列表的 PickerList。
共享 `lua/picker/list.lua` 和 `lua/picker/selection/` 保持原路径和契约。

## 验收

- 删除原 Session 的全能 refresh；不得仅改名为 Panel 后保留同样状态和算法。
- List 可不创建 popup 测试分页、恢复和取消；Input 可独立测试 debounce/flush；Window 可用固定页面测试呈现。
- 移动、marks、最新查询确认、resume、group replacement、错误清理及预览行为不变。
- 新增 grep 分页行为只改 List 子域；修改外观只改 Window 子域，不为假想 Source 类型建设公共框架。
- 完成以实际迁移和验证为准；历史通过记录不等于本轮验证。

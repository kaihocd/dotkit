# Picker 重构执行 TODO

方案：[picker-architecture-review.md](picker-architecture-review.md)。

状态：运行时迁移、逐项架构核对及最终自动化完成；仅人工终端验收开放。此前旧 Session 拆分完成结论仍撤回，不作为本轮依据。实际映射/状态/签名差异与人工步骤见 [实现核对与验收](picker-refactor-acceptance.md)。
按以下顺序执行，每阶段记录实际改动、验证命令和遗留问题，通过后再勾选。不按行数验收，不先搬空目录。

## 0. 归档方案与范围

- [x] 将 PickerResults 改为 PickerList，归档类的方法、旧代码映射、依赖和状态所有权。
- [x] Picker 专属对象限定在 `lua/picker/picker/`；保留共享 List renderer、Selection 及 Select 路径。
- [x] Pane 统一归 Window；Bindings 独占事件注册；Input 独占 debounce；List 独占列表任务调度；Panel 独占关闭协议。
- [x] 记录旧清单尚未完成的行为验证，不沿用旧的“全部完成”标记。

## 1. 核对全域代码和建立基线

- [x] 已核对公共边界及原 27 文件的当前归属；实际字段、调用与测试映射归档到 picker-refactor-acceptance.md。
- [x] 测试导入新对象；旧测试名称保留用于追溯；共享 renderer/Selection 和 Select 路径未被覆盖。
- [x] 确认整个插件当前未跟踪；将 `lua/picker/picker/` 原样移动为同级 `picker-bak/`，再复制为新 `picker/` 工作起点。27 个文件经 `diff -qr` 确认一致。不依赖 git checkout 恢复。
- [x] 后续仅修改工作实现与测试/文档；备份未作为写入目标。LuaLS ignoreDir 排除重复类型；全目录格式检查只读备份，测试不加载备份。
- [x] 运行 Picker、Select、Select UI、Selection、类型、Hint、格式基线；全部通过。Hint 基线 83 文件；inline formatter 返回类型与 Selection 数组类型限制仍存在。`.luarc.json` 排除冻结备份，防止重复类型定义，未关闭诊断。

## 2. PickerList：迁移行为，不只是改名

- [x] List 统一外部接口；continue_loading 在成功应用页面后调用，交付 Page + optional target。
- [x] 从 Search 迁移 files 页缓存、逻辑位置及 grep continuation；files.lua/grep.lua 各自拥有分页坐标，pages.lua 保留缓存/交付与 pending target。
- [x] 将 Session refresh 中列表 generation、indexing retry、prefetch、restore continuation 迁入 List。新 `list/init.lua` 已接入运行路径；输入 debounce 已另迁 Input。
- [x] Restore 只推进位置恢复；唯一列表调度循环由 List 拥有。增加不加载 popup 的 List polling/invalidate/close 测试。
- [x] 接入现有运行对象，让其只消费页面、target、状态和错误，不读取分页内部字段。移除 Session.search；move/resize 经 List，snapshot 经 List:snapshot() 获取复制的位置数据。
- [x] 旧 Search/Restore 路径及转发层已删除。ListPages 负责共同页交付/缓存，FilePages/GrepPages 独占各自分页坐标，Restore 留在 List 内部。
- [x] 分离后 Picker 全套及真实 fff resume 再次通过：实际批次/offset、resize、预取、retry、取消、有界恢复和中断。

## 3. PickerInput：输入与已提交查询分离

- [x] 接入 PickerInput 的 value/set_value/changed/flush/close；pane 是原始文本唯一来源，Input 拥有 debounce generation，避免重复存储文本。
- [x] Input 仅接收 read/write 能力，经 Window 到 InputPane；不持有 Window、不注册 autocmd或管理 buffer。
- [x] 接入输入回调与最新查询 flush，删除运行对象内的 debounce/revision 逻辑。
- [x] Input/scheduling/session/resume 用例通过：debounce、close失效、动作前 flush、UTF-8 cursor 与重复恢复。真实终端插入观感另列。

## 4. PickerSelection：明确唯一选择状态

- [x] Controller 迁为 PickerSelection；共享 Selection 实现和路径不变，旧模块路径已删除。Panel 字段已改为 selection。
- [x] current/marks 只在共享 Selection 实例保存；List 交付 target，Window 只做投影。
- [x] 页内移动与跨页请求分开；维护 ordered marks 和 Entry 身份转换。
- [x] controller/grep-session/session/completion 用例通过，覆盖 marks、身份、鼠标、移动与完成顺序。

## 5. PickerWindow：统一 UI 所有权

- [x] UI 资源迁入 PickerWindow；实际 layout 声明/计算/验证迁入 window/layout.lua，config 不再执行布局。
- [x] InputPane/ListPane/PreviewPane 只在 window/ 下各保留一个实现。
- [x] ListPane 对象独占 built rows/entry-row 映射，提供 render/select/marks/hit/page_delta；Window 不再读取映射内部字段。
- [x] row.lua 负责 formatter 隔离/校验，format.lua 负责默认行；icons/signs/snippet syntax 均归 Window。
- [x] Window 接收 entries/index/is_marked 等投影输入，不读取 List/Selection 私有字段。
- [x] 工作路径中已删除旧 view/presenter，无兼容转发实现。
- [x] view/session/theme/presentation/format 用例通过：布局、鼠标、焦点、clipping 和无搜索重绘。
- [x] 补 tests/picker-viewport.lua，独立 Window 验证 preview 隐藏/恢复及 resize 的 viewport preservation；已通过并注册全套。

## 6. PickerPreview：内容交付与 Pane 分离

- [x] Content/Cache/Preview 保留成熟读队列与缓存边界；状态及旧路径映射已归档。
- [x] Preview 只接收 visible/content/matches 显示能力，不接收完整 Window/Panel。
- [x] nearby 由 Selection 生成，经 Panel 传给 Preview，无反向依赖。
- [x] preview-content/queue/version/cache/prefetch/ui 全部通过，覆盖读取边界和 hit-only 更新。

## 7. PickerPanel、Bindings 与 Completion：完成运行对象替换

- [x] Panel 已接入独立 Input/List/Selection/Window/Preview；原调度、分页、恢复与绘制实现不在 Panel。
- [x] Panel 保留组装、用户流程、已应用页面上下文、值快照及关闭协议；_query/_result 与 List 任务状态的区别已归档。
- [x] Panel 独占 started/closed/save/completion；删除 Lifecycle，关闭协议保持 capture → cancel → deferred cleanup → completion。
- [x] PickerBindings 拥有事件句柄及 attach/detach；Panel 不再存储事件 ID，注册接收 pane 与窄回调，不接收完整 Panel。
- [x] Actions 保持参数验证和 guarded execution；不是业务状态 owner。
- [x] 补部分事件注册失败清理测试；注册逐项记录句柄，异常时回滚已注册事件。
- [x] Completion 保留命令执行模块；Panel 清理 UI 后恢复 origin/调用完成。
- [x] action-errors/presentation/group-errors/replacement/completion 用例通过，覆盖错误、重入及资源释放。

## 8. 公共入口、快照与目录收尾

- [x] options.lua 集中校验/复制，分配 backend/UI 前完成；每次 open/resume 创建新 backend/Panel。
- [x] snapshot 从 Panel:snapshot_state() 数据接口捕获，不遍历 Panel 的子对象；最终快照只保留复制的 options/位置/marks，不保存缓存内容。
- [x] 公共签名保持；公开类型、options、resume、Select 回归通过。
- [x] public resume 测试先真实 Tab 标记，再修改调用方配置；重复 resume 断言 PickerMarks 实际绘制原 marker。
- [x] public resume 测试切换空结果/indexing，断言 list buffer 实际显示复制的 empty/indexing messages。
- [x] 工作目录旧 session/ 已删除；扫描工作代码及测试无 picker.picker.session 引用，无兼容转发模块。计划文档旧路径明确标记为历史记录。
- [x] README 更新目录与职责、formatter 单行/无 tab/宽度/UTF-8 范围/priority 限制，以及 LuaLS inline formatter 返回类型限制。
- [x] 更新 picker-plan.md：明确下文仅为历史记录，本方案取代旧 Session 拆分结论；历史路径和终端反馈不代表当前实现/验收。

## 9. 最终验证与架构复审

- [x] Picker 全套：分页、恢复、输入、Selection、Window、Preview、Presentation、完成与错误清理。Panel 翻页方法整理后重新通过，日志 /tmp/picker-panel-review.log。
- [x] 最终 Select、Select UI、共享 Selection 回归通过，未同时重构 Select。
- [x] 最终两套类型正反探针及 Hint92 通过支持项；inline formatter/数组元素 LIMITATION 如实保留。
- [x] StyLua 全目录检查及 git diff --check 通过；未跟踪 Lua 内容由 StyLua 实际读取检查，不能用 git diff 代替。
- [x] Panel 翻页方法整理后，使用 `FFF_NVIM_PATH=/Users/qihao/.local/share/nvim/site/pack/core/opt/fff` 再跑 integration/resume，两项通过。
- [ ] 新终端验收：输入、分页、preview scroll、resize、mouse、focus、resume、group replacement。需要用户实际操作；本轮 headless fff 通过不替代此项。
- [x] 完成复读：状态/依赖/调用映射见实现核对文档；ListPages 与策略拥有真实状态，无通用角色层；Panel 无搜索/调度/绘制实现。
- [x] 唯一待验收项为人工终端交互，步骤已归档；通过后再另立 Select 评估，不混入本轮。

## 验证命令

在插件目录运行：

```sh
node tests/picker.ts
node tests/select.ts
node tests/select-ui.ts
node tests/selection.ts
node tests/check-lua.ts
node tests/picker-types.ts
node tests/selection-types.ts
```

每阶段跑相关测试和 Picker 回归；共享/API 边界变化时追加相应套件；最终完整执行以上命令。
真实 fff 命令见现有 tests 文档；执行时记录本机依赖路径及实际结果。

## 执行记录

- 最终连续收尾：复核原27文件归属、实际状态与调用接口，新增 picker-refactor-acceptance.md；共同分页对象命名 ListPages，Panel 已应用页面上下文加注释。最终 Picker/Select/Select UI/Selection/Hint92/两套类型探针/真实 fff integration+resume 全部执行通过（支持项），日志 `/tmp/picker-acceptance.log`。StyLua 全目录及 diff check 通过。既有 LIMITATION 保留；仅人工终端清单未验收。

- Panel 复读：将 bind 内的翻页计算迁至 page(direction)，绑定只连接回调；构造局部 View/view 改为 PickerWindow/window。Picker 全套、Hint92、StyLua、diff check、真实 fff integration/resume 再次通过。计划文档明确为历史记录，工作代码及测试扫描无旧 session require。未将尚未逐项复核的阶段清单批量勾选，终端验收仍开放。

- 本轮收尾：ListPane 独占行映射；Panel 字段 controller/view 改为 selection/window；resume marker/empty/indexing 实际绘制断言通过；README 已更新。最新全量 Picker、Select、Select UI、Selection、Hint92、两套类型探针、StyLua，以及真实 fff integration/resume 均重新通过，既有 LuaLS 限制保留。仍需按维护者视角完成 Panel 方法/构造/bind 流程最终复审及整理清单与计划文档；终端交互验收未做，不宣称全部 TODO 完成。

- 后续接入：Bindings 已独占事件句柄；snapshot 经 Panel 数据接口；独立 Window viewport 测试通过。最新完整 Picker 回归、Hint91（viewport 新测试加入前）、公开/Selection 类型及全目录 StyLua 通过。运行时工作树已无 session/；仍有 Panel 的旧 controller/view 字段命名、Window ListPane 状态封装、resume marker/messages 断言、README 与终端验收未完成。

- 连续迁移：files/grep 分页对象、Input、PickerSelection、Window/layout/行格式化、Preview 窄显示能力、Panel 关闭协议及 options 已接入。当前 Picker 全套、Select/Select UI/Selection、Hint91、公开类型通过（既有限制保留）；StyLua 已执行。真实 fff integration 通过，resume 首次暴露漏迁 require，修复后重新执行通过。仍需完成 Window/ListPane 对象边界、Bindings 句柄所有权、Panel 字段/方法可读性复审、值快照接口、剩余显示断言及终端验收；不能宣称完整重构完成。

- List 接口收拢：Session 不再持有 Search；List 接管 grep 页内/跨页判断、resize 与复制位置快照。分页/恢复迁入 list/，不留旧路径转发。新增 files 逻辑 resize、快照隔离、grep continuation 接口测试；Picker 全套、Hint85、类型探针（已知限制不变）、全目录 StyLua、diff check 通过。尚未宣称 List 阶段完成：内部 pages 仍待分离 files/grep。

- 方案归档：仅更新对象方案与本 TODO，未修改 Lua、未运行测试。
- 备份：已创建 `lua/picker/picker-bak/` 与内容完全一致的新 `picker/`；当时未改变 Lua 内容、未运行行为测试。共享 Selection、renderer 和 Select 未移动。
- List 第一部分：接管加载、匹配模式、恢复与调度并接入 Session。保留 `search = list.pages` 临时引用供现有 move/resize/snapshot 使用，尚未完成最终 List 边界，不标记阶段完成。新增独立 List 测试暴露 config 顶层依赖 popup，已将 require 延迟到实际 layout 计算；之后 Picker 全套、Hint85文件、全目录 StyLua 检查通过。

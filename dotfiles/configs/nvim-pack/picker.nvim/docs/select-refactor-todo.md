# Select 面向对象重构执行 TODO

方案：[select-architecture-review.md](select-architecture-review.md)。

> 布局统一迁移已由 [layout-refactor-todo.md](layout-refactor-todo.md) 接管：Picker 与 Select 均改为 layout-only 公共 API。本文涉及 layout 的旧条目以新文档为准，禁止在半成品实现上继续打补丁。

状态：SelectList/SelectWindow/SelectPanel/SelectBindings 已接入运行路径，旧 session 已删除；现有与新增对象回归通过。详细阶段勾选仍需逐项核对；尚未宣布重构验收完成。
路径除特别说明外，相对插件 `dotfiles/configs/nvim-pack/picker.nvim/`。

## 执行规则

- 按阶段顺序迁移，每个阶段必须让新对象参与实际运行；禁止先搬空 session 再补职责。
- 每阶段都做：实现 → 更新/新增测试 → 跑回归 → 复读状态所有权和调用顺序 → StyLua → 记录证据 → 勾选。
- 临时适配只允许存在于迁移期间；记录待删除位置，最终不保留旧 require 转发模块。
- 不按行数拆分，不添加通用 Controller、Lifecycle、事件总线、共享 Panel 框架。
- 不改 files/grep Picker、共享 Selection/renderer、popup 和个人配置来迁就本次设计。若确实需要跨边界修改，先说明原因并确认。
- 涉及既有公共行为改变时停下确认；普通对象迁移、测试补齐不需要逐项询问。
- 保留 Actions 泛型 T、原 item 引用和 original index；不向公共回调暴露对象、buffer 或窗口状态。
- 每阶段在本文件末尾记录实际命令/结果/遗留问题；完成实现但没验收的条目不要提前勾选。

## 0. 基线、备份与行为契约

### 0.1 基线和源码保护

- [ ] 读取方案及全部 `lua/picker/select/` 文件，确认当前目录与方案记录一致。
- [ ] 检查 git 状态；记录未跟踪文件与无关改动，不用 git checkout 作为未跟踪插件的恢复手段。
- [x] 已检查目标不存在后复制 select-bak，9文件 diff 与 hash 核对一致。
- [ ] `diff -qr` 确认备份一致；记录文件清单及内容 hash。之后只读备份，最终以 hash 验证未变。
- [x] ignoreDir 增加 select-bak，保留 picker-bak，不禁用诊断。
- [ ] 核对 `tests/check-lua.ts`、测试 runner、格式命令的发现规则：备份不参与运行或重复类型诊断，格式写入不得覆盖备份。
- [ ] 跑当前 Select、Select UI、Selection、Picker、Hint 和现有类型探针基线，保存日志。

### 0.2 把兼容要求转成可执行证据

- [ ] 建立现有测试断言映射：`select.lua` 的过滤/身份，`select-ui.lua` 的资源/布局/detail/hint/mouse/group/映射。
- [ ] 确认普通文本 query 是字面包含、数字 query 按 original index；归一化不变时保留当前项。
- [ ] 确认 raw query 改变但 normalized query 不变时仍退出 detail；补缺失断言。
- [ ] 确认公共 UI 当前使用 `vim.fn.tolower`，即使 Options 存在 normalize 字段；本次不顺手改变它，记录既有契约差异。
- [ ] 确认 caller 提供有效 buffer 时不得删除；root 自定义布局、pane 配置、固定几何策略保持现状。
- [ ] 对发现的未覆盖行为先加基线用例；若现有代码失败，明确是既有问题并决定是否需单独修复，不修改断言掩盖失败。

**阶段出口**：有可恢复的冻结源码、可重跑基线、明确的行为边界。

## 1. SelectList：候选集合、过滤与唯一选择状态

目标：`lua/picker/select/list.lua`，类 `picker.select.SelectList<T>`。

- [ ] 从 `session/controller.lua` 迁移 Entry<T> 类型和构造：item 原引用、original index、格式化 text、normalized search。
- [ ] 将 Controller 更名为 SelectList；字段明确为全部 entries、normalized query、normalize 函数、唯一共享 Selection 实例。
- [ ] 保留 `set_query/entries/current_index/select/move/choice` 的现有语义；不引入第二份 current/index 状态。
- [ ] 新增 `texts()` 返回可见文本的新数组；调用方修改数组不得改变内部 Entry 或之后返回的 texts。
- [ ] current_index 始终是过滤列表位置；select 接收 original index；choice 返回原 item 和 original index。
- [x] SelectList 已接入，字段 list，texts 投影循环移出运行对象；后续运行对象已替换成 Panel。
- [ ] 更新 `tests/select.lua` 的内部 require/对象名，保留现有用例；补 texts 隔离、false-valued item、重复显示文本的身份用例。
- [x] 旧 controller 模块已删除，测试引用新 SelectList，无兼容别名。
- [ ] 跑 Select、Select UI、Selection、Hint；复读泛型推导与状态所有权。

**阶段出口**：不创建 popup 即可测试过滤与选择；Session 不再处理 Entry 到 texts 的投影。

## 2. SelectWindow：真正收回 UI 所有权

目标：`window/init.lua`、`window/layout.lua`、`window/detail.lua`。不要先创建无状态 pane 包装类。

### 2.1 布局与资源

- [ ] 将 view 内 border_size/measure/geometry 迁到 `window/layout.lua`，实际计算留在这里，不转发到旧 view。
- [ ] 保持 prompt/input/border 所占高度、below-or-above placement、root overrides 和屏幕约束。
- [ ] 构造时按初始全部候选测量；后续过滤/render 不重新定位或缩放。
- [ ] 建立 SelectWindow 对象，独占 popup、resolved view、prompt、owned buffers、DetailPane。
- [ ] 资源获取时立即登记到 `_buffers`；将 `prepare_buffers` 返回释放闭包改为 Window 的资源管理方法。
- [ ] caller 有效 buffer 不进入 `_buffers`；已有 content 初始化和 native layout 支持保持。
- [ ] 构造失败清理已分配 buffer；包括 popup 创建、buffer 创建/初始化、open listener 安装失败。
- [ ] `Window:close()` 幂等：退出 group、关闭 popup、释放 owned buffers；即使 group hook 报错也不能跳过资源清理，错误向 Panel 边界报告。

### 2.2 窄显示接口

实现以下行为；最终签名写入验收映射，不要求机械逐字采用示例。

- [ ] `open()` 打开并初始化 prefix、filetype、wrap、winhighlight 和首屏。
- [ ] `query()` 读取 input，缺失 pane 用明确返回值交给 Panel 关闭，不让 Panel 直接读 buffer。
- [ ] `render(texts,index)` 构造 prompt+items 行并选择；不读取 SelectList 或 Panel。
- [ ] `select(index)` 在内部完成 index → buffer row +1。
- [ ] `hit(screenrow,screencol)` 在内部完成屏幕行 → 可选位置；prompt 不返回有效条目位置。
- [ ] `focused()` 保持“任一 pane 中仍视为内部”的焦点语义；关闭恢复焦点所需的 input-focused 判断与它分开。
- [ ] 封装 click 外部/输入判断所需的最小能力，不把原始 pane 交回 Panel 做行号或几何运算。
- [ ] `page_size()` 返回扣除 prompt 后的条目容量；半页用户动作可以由 Panel 计算，窗口高度 API 不能泄漏到 Panel。
- [ ] `hint(key,text)` 在 Window 内检查 clipping、query 占宽和 detail 状态，保留 extmark 命名空间和留白规则。

### 2.3 DetailPane 与列表返回顺序

- [ ] Detail 迁到 `window/detail.lua`，命名 DetailPane；仅 Window 持有，不由 Panel 持有。
- [ ] 保留 pane、wrap/cursorline、winsaveview，clear_decorations 只清自己的装饰，不清外部 namespace。
- [ ] `show_detail(text)` 在当前 list pane 展示完整文本，保持不转移焦点。
- [ ] 区分两种退出：同结果返回列表需要 viewport 恢复；新查询结果替换需要丢弃旧 viewport。
- [ ] 把“Detail.close → render list → restore viewport”的完整顺序包进 Window，Panel 不接收 restore_view 闭包。
- [ ] Window 可以接收本次 texts/index 重绘，不另建业务选择模型；若保存显示快照，明确只用于投影。
- [ ] `detail_active/scroll_detail` 为动作提供能力；Panel 不操作 wrap、cursorline 或 winsaveview。

### 2.4 接入与测试

- [ ] 当前 Session 改用 window 对象；移除 popup/view_options/prompt/detail 的重复长期状态及直接 renderer/buffer/height 操作。
- [ ] 迁移期间旧 Lifecycle 若暂留，只负责完成时序并调用 Window.close；不再存 popup 或 release_buffers。记录阶段4将删除。
- [ ] 更新 `select-ui.lua` 针对旧 View.create 的错误注入到 Window 对应资源获取边界，保留“已经安装监听器后失败”的真实测试含义。
- [ ] 新增 `tests/select-window.lua`：固定 texts，无 Panel，测量/几何稳定、prompt hit 排除、prefix/hint、detail 返回 viewport、查询替换不恢复旧 viewport。
- [ ] 补构造部分失败、open 部分失败、caller buffer 存活、重复 Window.close 的资源断言。
- [ ] 将新测试加入 `tests/select-ui.ts` 或明确的新 runner，保证全套会执行。
- [ ] 删除 working `session/view.lua` 和 `session/detail.lua`；跑 Select UI、Select、Picker、Hint、格式检查。

**阶段出口**：改变显示或 detail 不需要修改 Panel；Window 单独创建/测试/释放 UI。

## 3. SelectBindings：事件注册不再转交释放闭包

目标：`lua/picker/select/bindings.lua`，类 SelectBindings。先于 Panel 最终替换，便于 Panel 只依赖成形对象。

- [ ] 保留映射解析、disabled false、native RHS、action name、custom callback 的现有优先级。
- [ ] 保存解析后的映射和 detail_key；hint 描述仍来自同一份解析结果，不能重新推测任意 callback 的含义。
- [ ] 对象独占 autocmd IDs 和 attached/closed 状态，提供 `attach/detach`；不再向 Lifecycle 返回 unbind 闭包。
- [ ] attach 仅接收 popup 注册能力、Actions、active/click/refresh/focus 等窄回调，不接收 Panel。
- [ ] popup 原生 keymap 和 open/close listener 的生命周期与 Window 一致；autocmd 由 Bindings 明确释放。
- [ ] 注册每个 autocmd 后立即登记 ID；第N个注册失败时回滚前N-1个。
- [ ] detach 幂等；对事件已被其他清理路径删除的情况安全处理。
- [ ] open 回调执行前检查 active/closed，避免关闭后的延迟 open 再安装事件。
- [ ] 重复 attach 不叠加监听器；如定义为一次性 attach，应有明确 guard 和测试。
- [ ] 新增 `tests/select-bindings.lua`：部分注册失败、重复 detach、close-before-open、迟到事件不调用业务、detail_key 一致性。
- [ ] 更新 Session 的临时接入与旧 Lifecycle 清理路由；删除 working `session/bindings.lua`。
- [ ] 跑 Select UI、Hint、格式；确认新增测试进入 runner。

**阶段出口**：事件句柄不出 Bindings，对象之外无 unbind 所有权接力。

## 4. SelectPanel：只保留交互与完成协议

目标：`lua/picker/select/panel.lua`，类 `SelectPanel<T>`；删除 Session/Lifecycle，不只是重命名。

### 4.1 构造和关闭

- [ ] 构造流程改为：解析配置 → SelectList → SelectWindow → SelectBindings → 组装 Panel；不在 new 中定义业务方法。
- [ ] 配置无效时不分配 UI；确认校验顺序改变是否影响 formatter 副作用/错误契约，遇到可观察冲突先确认。
- [ ] Panel 字段限定为 list/window/bindings、group、last raw query、started/closed、origin、on_choice；不保存 pane、buffers、viewport、render 配置。
- [ ] Panel 独占一次性完成状态；删除 Lifecycle.active/finish/complete/set_unbind/cancel 的对象层。
- [ ] `close(item,index)` 先 claim closed，再 detach，最后 schedule UI cleanup → 条件恢复 origin → 调用回调一次。
- [ ] callback 抛错不能阻止先前资源释放；callback reopen 时旧 Panel 不再改变新窗口焦点或 group 成员。
- [ ] 保持只在原 input 持有焦点时 stopinsert/恢复 origin 的既有行为，外部取消不抢焦点。
- [ ] 绑定、group join、open 失败都进入同一关闭边界；构造前失败和运行中失败不能分别重复调用 on_choice。
- [ ] 定义回调/formatter/group 错误传播与通知策略，优先保持现有行为；新增的异常兜底单独测试和记录，不能静默吞错。

### 4.2 用户流程逐个迁移

- [ ] refresh：Window.query → 比较 raw query → List.set_query；normalized 不变但 raw 改变时退出 detail；变更结果时丢弃旧 viewport并 render；最后 hint。
- [ ] confirm：先 refresh，再 List.choice；只有 original index 非 nil 才 close(item,index)，不能用 item truthiness 判定有效选择。
- [ ] move：先 refresh/退出 detail，再 List.move → Window.select → hint；保留 clamp。
- [ ] page：detail active 时滚 detail，否则用 Window.page_size 计算半页并 move。
- [ ] click：Window 提供命中位置，List 完成身份选择；detail active 时不把全文当列表项；外部点击关闭及目标焦点行为不变。
- [ ] check_focus：用 Window 内部焦点判断，不遍历 popup pane。
- [ ] toggle_detail/leave_detail：只路由当前文本和列表值到 Window，不执行任何底层恢复操作。
- [ ] commands：仅返回既有 Actions，choice 先处理最新 query；关闭后 commands 不再变更对象或复活 UI。
- [ ] open：started/closed guard → attach → join group → Window.open → hint/startinsert；每个可能重入的边界之后检查 closed。
- [x] 公共入口已改为 SelectPanel，外部签名不变。
- [x] working session 目录及 Lifecycle 已删除，无兼容 require。

### 4.3 Panel 回归

- [ ] 新增或补齐 `tests/select-panel.lua`：重复 open/close、close-before-open、确认一次、空结果取消、关闭后 Actions、callback reopen。
- [ ] 保留并扩展 group replacement/不存在 group/钩子错误的资源与回调次数断言。
- [ ] 快速改输入后立即 confirm/choice/move，验证读取最新文本，不确认旧项目。
- [ ] 建立错误路径资源统计：窗口、owned buffers、autocmd、group membership，既要证明释放，也要证明 caller buffer 未误删。
- [ ] 跑 Select、Select UI、Selection、Picker 全套和 Hint，复读 Panel：不允许 raw buffer/extmark/renderer/detail viewport 实现回流。

**阶段出口**：一个 Panel 表达一次交互；关闭协议不依赖另一个生命周期对象。

## 5. 公共契约、目录和文档收尾

- [ ] 扫描所有工作 Lua、测试及 demo 的 `picker.select.session` 引用；迁移测试注入，不保留旧路径转发。
- [ ] 扫描旧 Session/Controller/Lifecycle 类型名，工作类型改成对象名称；历史记录明确标为历史。
- [ ] 保留公开 Options/Actions 名字及配置字段；不把 SelectWindow 暴露成新的公共 API。
- [ ] 补 `tests/select-types.ts` 或在现有类型 runner 中增加 Select 专项：item T、choice/callback original index、format_item、映射 Actions 推导。
- [ ] 类型负例覆盖错误 item 操作/错误参数；LuaLS 无法拒绝的情况明确 LIMITATION，不通过消音或类型强转伪造 PASS。
- [ ] README 更新 Select 对象职责、目录、公共行为；normalize 的现状不能被描述成已修正。
- [ ] 新建 `docs/select-refactor-acceptance.md`：旧字段/方法 → 新 owner → 对应测试，一项不漏；包括原 create/release_buffers 和 Detail restore 闭包的消除。
- [ ] 实际接口与方案示例不一致时解释原因和所有权是否保持；修正文档，不用文档掩盖未实现边界。
- [ ] 备份 hash 复核未改；工作 `session/` 确认删除；Select 不 require `picker.picker.*`。

## 6. 最终验证与人工验收

### 6.1 自动化（必须是最终代码的新一轮）

- [ ] `node tests/select.ts`。
- [ ] `node tests/select-ui.ts`，包含 Window/Bindings/Panel 新用例或运行其独立 runner。
- [ ] `node tests/selection.ts`。
- [ ] `node tests/picker.ts`，证明 files/grep 未受影响。
- [ ] `node tests/check-lua.ts`，Hint 级别，无诊断；记录实际文件数。
- [ ] `node tests/picker-types.ts`、`node tests/selection-types.ts` 与新增 Select 类型探针；保留已知限制。
- [ ] 仓库根目录 StyLua 全插件只读检查；写格式只针对工作代码/测试。
- [ ] `git diff --check`，另确认未跟踪文件实际经过 formatter 和测试，不能只依赖 git diff。
- [ ] 静态内部 require 图无环；人工复读动态回调依赖，不能只凭静态扫描宣称无耦合。
- [ ] 建立最终日志，注明负向测试的预期错误输出；失败先修复再整轮重跑受影响套件。

### 6.2 结构验收

- [ ] SelectList 可脱离 popup 测试，SelectWindow 可脱离 Panel 测试。
- [ ] Panel 的字段能说明一次交互，无 UI 状态和完成状态的重复 owner。
- [ ] 修改 detail 显示只需 Window 子域；修改过滤只需 List；修改事件登记只需 Bindings。
- [ ] Window 独占 buffer 生命周期，Bindings 独占事件句柄，Panel 独占 completion-once。
- [ ] 没有为了保持小文件而增加的类，没有 Picker/Select 共用万能基类。
- [ ] 构造、用户动作和关闭流程能按顺序阅读；泛型注解、注释、空行与函数命名可读。

### 6.3 人工终端（不得用 headless 代替）

- [ ] 在隔离 demo 中确认光标附近上下布局、小屏边界、过滤期间位置/大小稳定。
- [ ] 输入/删除/数字定位/立即确认返回预期 original item/index。
- [ ] 长项 hint、detail 展开、半页滚动、退出恢复列表 viewport、输入变化退出 detail。
- [ ] 鼠标选项/点 prompt/外部点击、焦点离开取消；不误确认、不抢焦点。
- [ ] 自定义映射、禁用 detail 映射后 hint、group replacement、callback reopen。
- [ ] 记录用户反馈与命令；如暂时无法操作，明确“实现与自动化完成，人工验收待确认”，不勾整轮完成。

## 验证命令参考

插件目录：

```sh
node tests/select.ts
node tests/select-ui.ts
node tests/selection.ts
node tests/picker.ts
node tests/check-lua.ts
node tests/picker-types.ts
node tests/selection-types.ts
# Select 类型探针和独立新 runner 创建后，在此补上实际命令。
```

仓库根目录：

```sh
node_modules/.bin/stylua --check \
  dotfiles/configs/nvim-pack/picker.nvim/lua \
  dotfiles/configs/nvim-pack/picker.nvim/tests
git diff --check
```

## 执行记录

- 最新整轮日志 `/tmp/select-acceptance.log`：Select/Select UI/Selection/Picker/Hint93/公开与Selection类型探针支持项通过，备份hash全通过。随后增加 close-before-open、raw-only query退出detail、detached Bindings迟到open测试；首次用全局autocmd总数断言误包含popup自有事件，改为检查Select所拥有事件后通过，Select UI/Hint93重新通过。仍需完成剩余细项核账，未将整轮实现标为最终完成。

- 后续复读：Bindings 已收回 configured/detail_key，Panel 不再保存解析结果；refresh 导致关闭后的 move/confirm/choice/toggle 立即停止。新增 select-refactor-acceptance.md 记录真实映射及兼容差异。Select 类型两项负例对照冻结原实现也被 LuaLS 接受；对照整套命令在后续 Picker 用例阶段超时，不声称整套通过。最新 Select UI/Hint93 通过。
- 首轮迁移：冻结 select-bak（9文件），hash 清单 `/tmp/select-backup.sha256` 复验全部一致；LuaLS 排除备份。Select/Select UI 基线通过；随后 Selection/Picker 回归通过。
- SelectList 接管旧 Controller 并提供 copied texts；Window 接管资源、layout、query/hit、hint 与 detail 返回流程；Bindings 独占 IDs 并 rollback 部分注册失败；Panel 合入唯一 close 协议，删除旧 Session/Lifecycle，旧 session 目录已删除。
- 新增 select-objects.lua 并注册 select-ui.ts：false item、texts 隔离、独立 detail viewport/替换、重复 open/close、关闭后 Actions、callback reopen、部分绑定注册失败。Select UI/Picker 全套、Hint93 通过；StyLua 全目录和 diff check 通过。
- 公开类型探针新增 Select inferred Actions/callback 检查，发现 LuaLS 不拒绝错误 move 参数或错误 callback item 运算；明确输出 LIMITATION，不能认证泛型推导。既有 Picker/Selection 限制保留。需要进一步对照备份检查这一限制是否原已存在。
- 仍待收尾：Bindings mapping/detail_key 的字段所有权（目前仍由 Panel 保存）、所有错误/迟到事件路径逐项验收、配置校验与 formatter 调用顺序兼容核对、Select 类型限制对照、README/映射归档及人工终端。不能将旧目录删除等同整个 TODO 完成。

- 计划归档：已审阅 Select 全部9个源码文件，核对现有测试对 Controller/View/Bindings 的引用与 UI 错误注入。本次仅写计划，不修改运行代码、不运行测试。阶段2/3临时接入后，阶段4必须删除生命周期过渡层。

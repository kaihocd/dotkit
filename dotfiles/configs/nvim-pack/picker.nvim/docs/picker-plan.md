# Picker 重构与拓展计划

## 当前方案与历史记录的边界

本文件下文保留原实现的计划和逐批验证记录，**不是当前目录或最终验收清单**。
其中 Session/Search/View 的职责划分，以及“Session 拆分完成”的结论已被撤回，
由 [全域对象方案](picker-architecture-review.md) 和
[执行 TODO](picker-refactor-todo.md) 取代。历史终端反馈不能验收本轮重构。

当前运行对象为 PickerPanel，组合 Input、List、Selection、Window、Preview；
Bindings 管理事件句柄，Panel 管理一次性关闭/完成。List 管理已提交查询、分页和调度，
Input 管理 debounce；Window 下的 ListPane 独占行映射，PreviewPane 独占 viewport。
旧 `session/` 已删除；下文出现的旧路径只用于追溯历史，不是可导入路径。
最新自动化与真实 fff 结果以 TODO 的执行记录为准，终端交互验收仍未完成。

## 历史进度（重构前）

- 阶段：公开 open/resume、fff files/grep、原生popup布局/绑定/group、完成动作、预览内容与有界恢复已接通；进入最终收尾，不再按早期静态demo阶段描述。
- Selection拥有选择与有序marks；Session协调查询/匹配模式及生命周期；Search管理分页/continuation/缓存；View拥有呈现资源，Preview/Content管理交付/读取与缓存。
- 自动化最近记录：Picker57项全量通过，Hint74文件无诊断；真实fff公开UI三页恢复及确认位置通过。各套测试执行批次见下方记录，非同一轮全套验收。
- 用户终端验收：resume后继续输入、连续移动时预览、连续resize布局/焦点、长grep列表滚动后的鼠标命中均反馈无问题。未据此宣称量化性能达标或所有视觉/失败场景穷尽。
- 下一步：核对旧行为/测试映射和遗漏，整理公开API/默认值/使用说明及已知限制，再做一次完整验证。实施清单历史未勾选项需逐条依据证据校正，不等同于均未实现。
- 个人配置保持独立，不自动迁移；Select不拓展。Popup独立Hint仍有已记录的范围外诊断，不能由Picker Hint通过推导其全库通过。
- 本文件记录已确认需求、实施清单和验证结果；完成任务后同步更新，不将计划写成已实现能力。

## 实施原则

以旧 `dotfiles/configs/nvim/lua/plugins/explorer/picker/` 为行为与实现参考，迁移成熟逻辑并重构状态归属，不从零重写已验证算法。旧测试位于 `dotfiles/configs/nvim/tests/picker*.lua`（路径均相对仓库根目录）。

- 本次修改限定在新 picker.nvim；不迁移个人配置，不修改旧 Picker，不顺手继续重构 Select。
- 有独立持久状态的组件使用对象；无状态函数不强行类化。
- 目录体现归属，不机械拆文件；Session 协调场景，不堆积底层操作。
- 内部类型与实现 colocate，避免重复声明方法；公开配置与 Actions 类型可独立。
- 复用已有 Selection 和列表宽度/截断机制，共享实现而非状态。
- 使用原生 popup 布局、pane、keymap、group，不复建 InputList 或全局弹窗管理器。
- 默认值集中管理，不修改调用方配置；边界错误需明确，正常关闭状态不能依赖裸 assert。

## 已确认需求

### 来源与搜索

- 只允许 files、grep，不做通用 Source 框架。
- 首版后端为 fff；隔离后端细节，为将来 fd + rg 留边界，本次不实现该后端。
- 调用可传 cwd，默认当前工作目录。
- 保留索引状态、根目录切换保护和 grep plain/regex/fuzzy 切换。
- 保留旧搜索限制参数与防抖行为；具体默认值以迁移时核对的旧配置为基准。
- 旧搜索调用同步返回；schedule 仅推迟执行，不代表非阻塞搜索。

### 分页

- 按旧 Picker 方式分页，不做虚拟列表或连续追加列表。
- files：页大小跟随列表高度，逻辑位置导航，半页可跨页，resize 尽量保持逻辑位置，有界缓存与相邻页预取。
- grep：独立页大小、continuation 分页；单步到真实条目边缘才跨页；半页在本页按显示行移动并跳过文件标题。
- 页内移动轻量化；跨页复用窗口；旧查询与过时预取不得污染当前结果。

### 选择与动作

- Selection 为当前选中身份的唯一权威，窗口 cursor 只呈现选择。
- 支持 edit、split、vsplit、tab，均打开当前条目；grep 跳转行列。
- 多选仅用于 quickfix，无标记时使用当前条目。
- 标记跨页、跨查询保留，按标记顺序输出。
- 确认前同步最新输入；先完成清理再执行打开/quickfix。
- keymaps 支持动作名、false、原生 popup 动作、接收公开 Actions 的回调，不暴露 Session。
- 新打开映射：CR confirm、C-s split、C-v vsplit、C-t tab、C-q quickfix；在输入的普通和插入模式可用且允许覆盖，其余沿用旧习惯。

### 呈现与预览

- 保留图标、文件名/目录呈现、匹配高亮、Git 标记、多选标记。
- grep 保留文件分组标题、行列位置、片段语法与匹配高亮；标题与空占位不可选择。
- 使用 Select 同样的显示宽度、padding、单行尾部省略号规则；不做路径中间省略，不提供全文展开。
- 预览保留开关、滚动、定位、语法/匹配高亮。
- 优先读已加载 buffer（包括未保存内容），否则异步读取磁盘。
- 保留大小/二进制/失败提示、有界缓存、新鲜度检测和邻近预取。
- 最新选择优先，过时结果不得覆盖；同文件尽量复用内容与高亮；关闭后停止交付并释放资源。

### 布局与生命周期

- 原生 input、list、preview 三个 pane。
- 当前布局入口为 view.layout(panes, context)，详见 [layout.md](layout.md)；旧的独立 pane 配置已删除。
- view.layout(panes, context) 返回原生 popup 布局；context 提供可用宽高。
- input/list 必须各出现一次；预览关闭时 panes.preview 为 nil。
- 开窗、resize、预览切换时重新计算布局，尽量复用窗口；未指定时采用默认布局。
- root 几何与窗口配置使用 popup 风格；Picker 管 pane 身份、交互和生命周期。
- 接入原生 group，保证替换清理与焦点正确；不复制旧 active/pending 管理器。
- Select 将来可评估采用相同布局接口，本次不修改。

### 恢复

- 只保留最近一次会话快照，不做历史列表或按 cwd/mode 分组。
- open 创建新会话；resume 使用最近快照创建新会话，快照不是一次性消耗品。
- 保存 mode、cwd、查询、grep 模式、当前身份、标记、预览开关和当次配置覆盖。
- 重新搜索并尽量恢复位置，目标不存在则回退；不复活旧窗口、任务、监听器。
- 无快照时提示，不隐式打开其他模式。
- grep 深页恢复需要重新建立有效 continuation 链，不能直接信任旧 token；具体有界恢复策略在实现前落实。

## 目标状态归属（按实际实现校正，不预建空类）

| 组件                              | 所有权                                                  |
| --------------------------------- | ------------------------------------------------------- |
| Session                           | 会话上下文及场景协调                                    |
| Controller                        | Selection门面、条目身份与有序标记操作                   |
| Search                            | 当前查询的分页、continuation、缓存、请求版本与预取      |
| View                              | popup、pane、布局、显示行映射、自有窗口/buffer 的释放   |
| Preview / Content                 | 当前目标、预览呈现、读取队列、内容缓存                  |
| Session / Completion              | 一次性关闭协调、来源窗口与完成动作；无独立Lifecycle对象 |
| Backend                           | fff 调用与兼容逻辑，不依赖 UI                           |
| Public entry / Snapshot / Restore | 最近关闭快照存储、值复制、有界重搜任务；不复活旧Session |

## 实施清单

### 1. 契约与迁移准备

- [x] 建立关键旧行为映射（见下表；不宣称旧测试逐项等价）。
- [x] Entry身份、1-based行/0-based字节列、半开匹配区间和完成动作契约已实现并测试。
- [x] Selection跨页/跨查询marks及新增原子replace_marks恢复已验证。

### 2. 纯状态迁移

- [x] Controller 使用共享 Selection（页内选择、结果替换、跨页标记、邻近文件去重）。
- [x] 迁移 files/grep 分页、resize、三页 LRU 与过时预取保护。
- [x] 分页边界、查询变化、continuation、标记、indexing目标一次交付与Session重试已覆盖；真实fff公开UI三页恢复通过。

### 3. 原生 popup 静态闭环

- [x] 默认布局、自定义layout/pane、原生绑定/group、焦点取消、一次性清理与独立demo。
- [x] 无效布局/部分创建失败/替换不抢焦点回归；外部pane buffer明确拒绝，不作为支持能力。

### 4. fff files 闭环（首个可用里程碑）

- [x] fff files、cwd/当前文件、索引/root保护；防抖、分页、选择、状态与打开闭环。
- [x] 跨页/resize/最新查询确认及backend根目录与失败边界回归。

### 5. 呈现与动作

- [x] 文件行/可选图标/匹配/Git/marks、宽度截断与高亮裁剪。
- [x] 四种打开、quickfix、公开Actions、映射覆盖/禁用与配置隔离。

### 6. Preview

- [x] Preview/Content独立交付与读取、版本缓存/优先级/清理。
- [x] 渲染/滚动/同文件复用/布局切换，过时交付/未保存buffer/读取中关闭/预取与缓存回归。

### 7. grep

- [x] grep backend、匹配模式/限制/continuation。
- [x] 分组行映射、可选语法/匹配、标题跳过、行列定位及多命中身份/跨页/Unicode回归。

### 8. 恢复与最终验收

- [x] 最近快照、公开resume、fresh重搜/选择/marks/回退及独立demo。
- [x] README/API/限制说明；关键旧行为、资源失败与恢复回归。
- [x] 最终运行套件、Picker Hint、类型反例、StyLua及真实fff集成（见第六十三批）。
- [x] 用户确认续输/预览/resize/滚动鼠标命中无问题；group替换已有自动化覆盖，未宣称终端全部场景穷尽。
- 范围外保留：个人配置迁移、量化性能基准、旧测试穷尽等价、popup独立Hint剩余诊断和LuaLS已知数组推断限制。

## 迁移对照（收尾核查，非旧测试逐项全量认证）

| 旧行为/参考                                                                   | 新实现证据                                       | 结论                                                            |
| ----------------------------------------------------------------------------- | ------------------------------------------------ | --------------------------------------------------------------- |
| config.lua 默认C-l模式循环、C-o预览、C-b/f预览滚动、C-u/d半页、Tab标记/C-q    | bindings与grep-session/preview-ui/completion专项 | 已覆盖；C-r保持原生                                             |
| config.lua debounce40ms、poll100ms、grep请求100/单文件50/1MiB/50ms            | config/backend及backend/scheduling专项           | 已迁移；fff实际返回页长可超过100                                |
| picker-pages-model.lua continuation、query/mode重置、files resize、旧预取失效 | picker-search.lua与grep-session                  | 已有对应回归                                                    |
| picker-pages-retry.lua indexing后pending target只交付一次                     | picker-search.lua新增同类专项                    | 已补并通过                                                      |
| picker-session-retry.lua 缓存驱逐后前页indexing与Session恢复                  | picker-session-retry.lua                         | grep缓存驱逐前页重试与files resize indexing保留位置均已补测通过 |
| 旧配置可修改所有搜索/样式/缓存内部默认值                                      | 新Options只暴露mode/cwd/group/view/keymaps       | 有意收窄公开API，不承诺旧config直接兼容                         |
| files↔grep会话内切换                                                          | 已查旧config与入口未发现契约                     | 不列为本轮必补功能；grep匹配模式循环已保留                      |

## 定制点矩阵与边界

| 行为                        | 默认实现归属             | 首选覆盖方式                 | 覆盖函数边界                                 |
| --------------------------- | ------------------------ | ---------------------------- | -------------------------------------------- |
| 单条文件/grep item          | `session/list/`          | `presentation.format_item`   | `Entry + ListItemContext -> ListRow`，纯函数 |
| icon                        | `session/list/icons.lua` | `view.icon` provider         | path -> glyph/highlight                      |
| mark/Git marker             | `session/list/signs.lua` | presentation配置或纯resolver | Entry状态 -> TextStyle，不操作buffer         |
| prefix/status/messages      | `view/input.lua`         | 结构化配置，必要时纯文本函数 | 只返回文本，不操作输入buffer                 |
| layout tree                 | `view/layout.lua`        | `view.layout`函数            | panes/context -> native tree，受框架校验     |
| preview content             | `session/preview/`       | 本轮不开放替换               | 不暴露读取状态或View                         |
| Selection/Search/Completion | session owners           | 不开放覆盖                   | 保持业务不变量                               |

函数覆盖只在输入/输出是窄的纯值边界时提供；popup、buffer、extmark、Session、Controller和生命周期永不传给公共回调。配置保留给低成本的文本、颜色、符号和间距修改；若整段行为覆盖成本更低，再提供函数而不是继续增加字段。

第六十四批（定制契约草案）：

- 在 `picker/types.lua` 增加 ListHighlight、ListRow、ListItemContext、FormatItem、TextStyle 和 PresentationOptions 类型；暂未接入运行时，避免未完成的公共配置声明。
- 确认 `session/list/` 是结果行模型与默认格式化域，`view/list.lua` 是Neovim投影域；`session/init.lua` 后续参照Select拆Lifecycle/Actions/Bindings。
- 本批只修改类型/计划文档，未跑运行时套件；下一批先实现options解析与默认presentation配置，再迁移View。

## 验证记录

最终架构复审与收尾：

- Session 主体由 Lifecycle、Bindings、Actions、View/List/Input/Preview 分担真实边界；Session 保留搜索、restore、选择动作和呈现协调。
- `session/init.lua` 当前约470行，剩余方法共同操作 Session 业务状态；未按行数继续机械拆分，避免增加跨模块跳转和薄转发层。
- 全量 Picker/Select/Selection/Preview/Resume/Presentation 测试、公开类型探针、LuaLS Hint83文件与StyLua通过。真实fff与终端验收采用前序记录；LuaLS内联formatter限制仍有效。

呈现契约收尾验证：

- 区分TextStyleOptions/StatusOptions与完整样式类型，公开类型正例支持只覆盖grep prefix文本、marker高亮、status分隔符。
- 真实映射触发formatter抛错、多行文本、UTF-8内部字节范围；验证窗口、buffer、autocmd释放和一次完成。
- 公开resume测试验证重复恢复仍使用复制的prefix及formatter，修改调用方原表不会改变快照；尚未逐项断言恢复后的marker/messages外观。
- Picker全套通过；测试注解修正后Hint81文件通过；全lua/tests StyLua检查通过。新增prefix/status负例符合预期；LuaLS未拒绝内联formatter返回{text=1}，明确输出LIMITATION，不计作类型安全通过。

呈现契约修正（formatter与配置）：

- formatter改为files文件条目/grep命中行；heading使用默认文件格式。回调接收entry副本，返回row也复制；校验单行文本、highlight类型、范围边界与priority。
- Session移动、鼠标选择和标记更新定制行，不通过搜索刷新；默认formatter路径仍使用cursor投影。新增真实Session测试验证files/grep current/marked、heading与搜索调用计数、entry隔离。
- 新增ResolvedPresentation，公开入口在backend分配前解析呈现配置；校验未知字段、嵌套结构、单行字符串与marker单格宽度。移除未接入loading选项；input indexing文案接入messages。
- Picker全套（包含新picker-presentation）、Hint81文件、现有公开类型正例与6反例通过。新formatter非法返回的Session清理、resume定制及新配置类型负例仍需补测；未声称整个定制契约阶段已完成。

预览呈现职责迁移（架构重构续批）：

- 新增 `session/view/preview.lua` 的 PreviewPane，拥有行号与viewport状态；View委托content/matches/scroll及resize前后save/restore，不向子模块传完整View，不改变Content读取/缓存/交付。
- 删除View中的预览呈现实现与两个分散状态字段；buffer/popup释放仍由View负责。
- 补跑format发现此前列表投影迁移漏掉省略号裁剪，既有测试失败；恢复原有available检查和省略号字节扣除后，Picker全套通过。
- 本批Preview UI/View专项、Picker全套、Hint80文件通过；格式化本批三个运行时文件。未执行真实fff或终端验收，不宣称全目录格式检查通过。

第六十三批（本轮收尾）：

- 补旧Session retry两个场景，无运行时修改；新增README说明公开API、依赖、keys、resume边界及不兼容旧config。清单按有限证据校正，不声称穷尽认证。
- 统一执行Picker全套（新增Search与Session retry）、Select/Select UI、Selection11项；Hint首次发现新测试predicate返回boolean?，改成显式nil判断后单项重跑及Hint75文件通过。
- 公开API正例+6反例、Selection类型探针通过既有预期；两项真实fff集成通过；lua/tests StyLua --check通过。
- 用户终端反馈已记录。本轮功能实现与验证收口；范围外项目独立保留，不自动迁移个人配置。

第六十二批：

- 开始收尾行为对照，记录已覆盖与尚需核对的差异；未机械勾选整张实施清单。
- 补旧pages-retry对应Search回归：连续indexing不丢目标，ready交付第2条且只交付一次。Search7项及Hint74文件通过，无运行时代码修改；未跑全量。

第六十一批（用户终端验收反馈与进度校正）：

- 用户确认上一批列出的四项终端检查均无问题：resume续输、连续移动预览、连续resize布局与焦点、长grep列表滚动鼠标命中。
- 校正过时的当前进度与所有权表；本批仅文档更新，无新自动化执行。不将用户有限场景验收扩展为性能数据或全场景保证。

第六十批：

- 真实fff三页测试推进到公开UI：通过C-n映射移动至第3页第5条，公开Actions标记后关闭，picker.resume重搜；读取实际选中渲染行验证位置与status的mark，CR确认后核对真实文件path/line/byte col，清理回单窗。
- 实际fff专项通过；Picker57项全量及Hint74文件通过；tests/README.md补两项opt-in命令与验证边界，无运行时代码修改。
- 公开UI深页headless恢复已有证据；终端连续输入/连续resize/preview流畅度和视觉仍需人工验收，不作为完成项。

第五十九批：

- 原生group替换测试验证close捕获时旧输入buf仍有效，捕获最新中文query并丢弃未搜索旧位置，随后正常释放；公开resume验证替换期间最近已关闭快照的归属与重复恢复，无焦点抢回。
- 新 opt-in tests/picker-fff-resume.lua 创建7个文件共280命中，通过真实adapter/Search/Restore重建3页continuation，恢复原path/line/col；这是恢复算法联调，不是公开UI深页验收。
- 首次测试错误假定fff每页恰好100条，实际按文件批次返回120条；改为验证至少100且按真实items长度跨页后通过，无运行时代码改动。
- 两group专项及fff深页专项通过，Hint74文件无诊断；未跑全量，终端验收仍待做。

第五十八批：

- marks恢复补3项边界：首见顺序去重/输入数组隔离且不改current/results、false值去重与toggle、nil/boolean/table/NaN key和key函数异常时保持完整旧状态。
- 新测试先失败：replace_marks接受了boolean/table key，与replace约束不一致；收紧为string/非NaN number后通过。
- Selection11项、Select6项、Select UI全套通过；Hint73文件无诊断；公开API正例+6反例及Selection类型探针通过既有预期，LuaLS数组推断限制仍存在。本批未重跑Picker全量或fff。

第五十七批：

- 用户报告resume光标在查询开头；恢复完成后显式将光标置于查询尾部，并使用startinsert!在行尾进入插入模式，普通open不变。
- 公开resume回归改用中文结尾查询并断言尾部光标，Picker57项全量及Hint73文件通过。
- 初始feedkeys实际输入探针未能正确驱动headless延迟startinsert（字符没有写入），不能作为已复现实际键入的证据；最终回归验证光标位置，终端实际追加输入需用户复验。

第五十六批：

- 真实fff公开grep确认后resume，验证query、regex模式、1个mark、预览开关/绝对行号/第2行命中字节和输入焦点恢复，退出清理通过。
- 测试首次等待状态超时原因是默认headless宽度不足、状态按设计隐藏；固定180x45后通过，无运行时代码修改。
- Session恢复专项增加move(0)/confirm/resize立即中断，所有后续调用offset保持0，确认打开当前已显示条目而非预排页。
- 两专项通过，Hint73文件无诊断；本批未重跑全套，未验证真实fff深页恢复或终端流畅度。

第五十五批：

- 公开 picker.resume() 接入最近关闭快照；成功open后注册close捕获，清理前复制，保存规范cwd/配置；无历史INFO提示，每次恢复新建source/session，demo增加PickerResumeDemo。
- 显式move/click/confirm/quickfix/resize取消自动恢复；Search记录已显示page并撤销预排的下一页，避免旧任务抢回选择；close也先撤销pending再保存。
- 公开恢复回归验证无历史、最新未搜索输入、重复恢复与fresh source；Picker57项全量通过，Hint73文件无诊断。
- 仍需真实fff resume联调及恢复期间交互专项；resize当前策略是停止深恢复。marks恢复失败原子性/false值、被替换popup关闭前buffer可读性等边界待补。

第五十四批（Session恢复已接，公开入口未接）：

- Session.open 内部接受snapshot，恢复query/match_mode/marks/preview请求状态；refresh调用Restore.step，ready链用0ms defer续步，indexing沿用轮询，恢复完成前不预取搜索页；fallback发简短通知。
- 输入变化、模式切换及close取消恢复，revision挡住旧定时任务。新增真实窗口测试验证3页fresh continuation、marks、新查询取消旧链、close后无继续搜索。
- Picker56项全量通过，Hint72文件无诊断。公开resume/关闭捕获/最近快照存储尚未接；恢复期间用户导航/确认与resize竞争还需专项处理，不能宣称完整恢复已完成。

第五十三批（resume恢复任务，尚未接Session）：

- Restore 每step最多一次前台搜索；files 从旧逻辑位置换算当前page size并按新total钳制；grep重建continuation，最多目标第10页，超限回首页。索引未就绪返回未完成，交调用方重试。
- 目标页按path/line/col优先匹配身份，找不到则保留位置回退并返回fallback；链提前结束停在最后到达页。未实现跨页全局身份寻回。
- 新专项覆盖fresh offset、indexing重试、files尺寸换算和超限fallback；单项通过，Hint71文件无诊断。公开resume/关闭捕获/任务调度/取消仍未连接，未跑全量。

第五十二批（resume仍未开放）：

- capture 检查原始输入是否等于已搜索query；未搜索输入只保存新query，页归零且丢弃旧current/index，marks独立保留。
- Selection 新增原子 replace_marks，按身份去重保留顺序；Controller.restore_marks 复制位置后委托 Selection，不通过临时替换当前结果恢复标记。
- snapshot 回归验证未搜索/已搜索状态与 marks 恢复隔离；Selection8项回归通过，Hint69文件无诊断。新 replace_marks 的失败原子性/false值专项仍需补测；close捕获、最近存储、有界恢复和公开入口尚未连接。

第五十一批（resume基础，未开放入口）：

- 新 snapshot.capture 复制调用配置、当前原始输入、匹配模式、预览请求状态、搜索页/size/index、当前位置与有序marks；位置只保留path/display/line/col，不保存snippet/命中范围/缓存或窗口。
- Search/View/Session 以只读方法提供各自拥有的状态，无直接读取私有字段。测试验证最新未搜索输入与复制隔离，关闭后快照仍有效；单项通过，Hint69文件无诊断，未重跑全套。
- 尚未在close捕获、没有最近快照存储或公开resume；后续需处理输入已改但当前结果仍旧的快照一致性（不能把旧页位置应用给新query）、有界grep重搜与marks恢复。

第五十批：

- 新增独立 tests/picker-types.ts：临时复制实际插件实现并加载 Neovim/popup 类型，合法 open 配置与映射 Actions 推断先通过，再分别验证非法 mode/icon/move字符串/mark/page/preview方向产生类型诊断。
- 7次 Hint检查均符合预期，测试临时文件自动清理；测试说明更新。本批无运行时代码修改，未重跑运行时套件。不是 API 所有类型健全性的证明，也未覆盖既知泛型数组限制。

第四十九批：

- Actions 边界校验 move/scroll_preview 有限整数，page direction ±1、mark direction -1/0/1、可选 preview direction ±1；操作前拒绝无效参数，沿用 Session 错误关闭/报告策略。公共类型同步收紧 direction。
- 新映射回归覆盖 NaN/Infinity/小数/非法方向，验证无额外搜索、不改 marks、一次回调和窗口清理。Picker53项全量通过，LuaLS Hint67文件无诊断。
- 预览 direction 可选组合、超大有限整数与所有参数类型的穷举未覆盖；本批不代表 API 全面冻结。

第四十八批：

- open 前置拒绝旧 root/input/list/preview/detail 配置，校验 layout 函数和 icon false/function；Window 校验 supplied pane 身份与 buffer。校验 keymaps 原生 mode、映射表、非空 lhs、false/string/function 声明，保留原生 RHS 字符串。
- options 回归增至20个错误场景，并验证禁用映射/原生 RHS/禁用 icon 正常通过边界且配置不变。Picker52项全量通过，Hint66文件无诊断。
- 原生 pane 几何字段仍由 popup 验证，layout 返回树由既有 View 校验；Actions 数值参数尚未补齐。

第四十七批：

- 公开 open 在创建 source/UI 前校验 options、mode、cwd、group、view、keymaps 顶层类型；false 不再被 options or {} 静默当默认配置。错误沿用 picker notify 边界，不改变 API 返回约定。
- 新回归9种无效输入验证明确选项名、后端调用0次、buffer/window不分配、调用者配置保持，省略 options 仍进入默认 files 后端。
- Picker52项全量通过，LuaLS Hint66文件无诊断。嵌套 view/keymaps 结构与 Actions 数值参数完整校验尚未完成。

第四十六批：

- 仓库 dotfiles Lua 搜索仅找到生产 single_popup on_join，无 on_leave 生产消费者；更新 popup.group.config 注释明确已加入/已退出及异常语义。
- 增加 on_leave 同组重入后抛错测试，新关系保留，测试通过；Picker Hint65文件无诊断。
- 首次 popup 独立 Hint 检查20文件发现6条：instance/group.lua 的可空局部变量已改为先捕获后判空；其余涉及 init.lua group 导出类型、renderer/window.lua 三条 buffer 可空、tree.lua 未用局部变量，不在本次授权的 group 修复范围，未改。独立检查仍不能宣称通过；局部修正后尚未再次运行。

第四十五批：

- 经授权修改 popup group.lua、instance/group.lua、types.lua：加入前记录关系，以唯一 membership token 区分同组重入；on_join 抛错回滚本次仍存关系，不调用 on_leave、不误删新关系。退出先移除成员再调用 on_leave，重复移除不调用 hook。
- Picker close 隔离 leave_group 异常，继续 View 清理与一次完成回调后报告错误。
- 新回归覆盖 join/leave 抛错清理、同组退出重入后外层 join 抛错、新关系保留、leave hook 重入与重复退出。Picker51项通过，Select UI 回归通过，Picker LuaLS Hint65文件无诊断（非 popup 全量独立类型检查）。
- on_leave 现在观察已移除后的成员列表，这是明确语义变更；其他 group 消费者完整验收仍待执行。

第四十四批（异常边界诊断，未修复）：

- 隔离 headless 注入 on_join 抛错：Session 回调1次、窗口恢复1个，但原生 group.instances 残留1个成员。原因：Group:add 先插入再调用 hook，Instance.join_group 在 add 返回后才设置 _group。
- 注入 on_leave 抛错：group残留1个成员、窗口残留4个、完成回调0次，并出现 schedule callback 异常。原因：leave_group 先清空 _group，Group:remove 在删除成员前调用 hook；异常中断 Session.close 的后续 View 清理和回调。
- 本批未修改运行时代码。完整修复需要 popup 原生成员生命周期的异常安全，不能在 Picker 内篡改 group.instances 或另建管理器；等待用户批准扩大到 popup.nvim。同步重入测试尚未开展。

第四十三批：

- 增加原生 group 替换/回调重入真实窗口回归，使用旧 single_popup on_join/open 策略：旧会话延迟清理不抢焦点，group 只留新成员，确认两次只回调一次，完成回调可再开 Session，最终窗口/主题监听恢复基线。
- 本批仅测试，无运行时代码改动。Picker50项全量通过；Select/Select UI/Selection/Selection负向类型回归通过（既有 LuaLS number[] 数组限制仍明确报告）。LuaLS Hint64文件无诊断。
- 不表示所有 group 异常边界已覆盖：on_join/on_leave 抛错或同步重入仍需独立验证。

第四十二批：

- Session 订阅 ColorScheme，仅 decorate 更新 marks/status，立即重算 staged RGB；不调用搜索或重写列表/预览。沿用 Session._events 生命周期清理。
- 新真实窗口测试验证主题事件后颜色、搜索次数/列表 changedtick/输入焦点/选择保持，以及 close 立即移除监听、后续事件无搜索。
- 默认49项全量通过，LuaLS Hint 63 文件无诊断。终端主题视觉仍待验收。

第四十一批：

- staged Git marker 沿用旧版 0.6 foreground / NormalFloat background 混色；缺颜色回退原组，Tab 优先，不写背景以保留 overlay combine 的 CursorLine。
- 每次 marks 绘制重读主题颜色，不缓存 RGB；尚未增加 ColorScheme 即时重绘事件，主题切换后下次 decorate 更新。
- 原47项通过，新 signs 测试补齐 popup rtp 后通过，覆盖精确混色/无背景/mark优先/主题重绘/缺色回退；LuaLS Hint 62 文件无诊断。终端主题视觉待验收。

第四十批：

- 迁移旧 snippet Treesitter 字符串解析：不打开源文件/创建 buffer，缺 parser/query 静默降级；成功与 query/parse 错误均释放已取得 parser。
- format 将 capture 字节范围移过行列前缀，语法 priority100、命中200，沿用 View 截断裁剪。
- 原46项通过；新真实 Lua parser/query 测试验证关键词、中文文本范围、优先级、无 buffer 副作用与异常释放，修正故障注入时机后通过；LuaLS Hint 60 文件无诊断。其他语言依赖安装 parser/query，终端视觉/性能未验收。

第三十九批：

- View 以独立 PickerPreviewMatches namespace 绘制 grep 字节命中；Preview 同内容快捷路径仍更新装饰，不重写内容、不重置滚动。消息/空状态清除命中，非法行不映射到钳制后的其他行。
- 回归覆盖同文件同行更换范围、内容 changedtick 保持、错误清除；真实 fff 集成验证第2行字节 [3,25) 命中。默认46项及真实集成通过，LuaLS Hint 无诊断（最后追加的真实 extmark 断言已运行，未再次跑 Hint）。
- grep 列表 snippet 语法高亮尚未实现。

第三十八批：

- 扩展真实 fff 公开入口测试：C-l 切 regex 正则查询、fuzzy 非连续字符查询、plain 恢复；断言结果、右侧模式状态、输入焦点与 C-r 未占用。
- 不完整 regex `[` 实测回退字面匹配；直接检查真实 fff 返回 regex_fallback_error，会话保持可用并继续预览/确认。沿用旧行为，不新增提示或异常处理。
- 对照旧 config.keymaps 核对 marks/quickfix/mode/preview/page 键位一致；真实集成通过，LuaLS Hint 58 文件无诊断。本批仅扩展测试，无运行时代码修改，未重跑默认套件。

第三十七批（纠正第三十六批）：

- 对齐旧 config.next_grep_mode 与 view.status：C-l 循环，释放 C-r 原生寄存器输入；左侧固定 Grep，右侧为 mode · count · N selected，非 Grep:mode 标题。
- 回归先在 C-r 被占用断言失败，修复后验证 C-l、固定标题及完整右侧状态；默认46项通过，LuaLS Hint 58 文件无诊断。此前第三十六批键位/显示设计作废。

第三十六批：

- grep 内 C-r / Actions.cycle_match_mode 循环 plain/regex/fuzzy；保留查询/marks/会话，Search 重置 continuation，输入前缀显示匹配模式并参与状态宽度预算。
- grep Session 测试通过真实映射断言三种模式转发、offset 重置、查询/marks 保留与前缀更新。默认46项通过，LuaLS Hint 58 文件无诊断。
- 本批模式切换采用模拟 source 回归，真实 regex/fuzzy 与非法正则行为待验收；files/grep 会话内切换仍未实现。

第三十五批：

- 新增独立真实后端测试 tests/picker-fff-integration.lua，FFF_NVIM_PATH 显式加载安装目录；隔离临时目录/文件，测试后删除，不加入无依赖默认测试。
- 本机 fff 通过公开 grep 搜索 -> 分组结果 -> 预览行定位/行号/输入焦点 -> 确认打开原文件第2行与 popup 清理完整流程。
- 默认46项全量重跑通过，真实集成1项通过；LuaLS Hint 58 文件无诊断。会话内模式切换、grep snippet 语法与预览命中高亮、resume 等仍待完成；不是终端性能验收。

第三十四批：

- 公开 open({mode='grep'}) 连接 plain grep、100项固定页大小、Grep 前缀与分组 View；按条目边缘才跨页，半页按显示行计算跳标题。
- 真实 demo 增加 :PickerGrepDemo（先退出当前 Picker 再执行）；会话内 files/grep、plain/regex/fuzzy 切换未实现。
- 旧45项通过；新增 grep Session 回归发现并修正非边缘误跨页，单项重跑通过。LuaLS Hint 57 文件无诊断。公开 grep UI 真实 fff 完整交互仍需联调。

第三十三批：

- View 内部 render 支持 grep 分组：连续同文件标题 + :line:column snippet，位置 Comment、命中 Special。
- 双向条目/显示行映射统一选择、marks、鼠标 hit；文件标题与空结果无条目映射。
- 原44项通过，新 grep View 测试修正为 screenpos 内容坐标后通过；LuaLS Hint 56 文件无诊断。Session 尚未传 grep 模式，公开入口仍为 files；下一步接模式和显示行半页导航。

第三十二批：

- fff grep adapter 迁移旧索引保护、空查询、mode/continuation offset、snippet 与字节坐标转换；暂用旧 50 matches/file、1MiB、50ms 限制。
- 模拟回归覆盖索引未就绪不搜索、空查询、offset/mode 转发与坐标保留。44 项通过，LuaLS Hint 55 文件无诊断。
- 隔离进程真实 fff plain 查询 function Content 返回6项，路径/行列有效。尚未开放 grep UI；分组显示、显示行映射、模式切换是下一批。

第三十一批：

- Preview 可见时预取当前前后 radius=2 内不同文件，最多4个，排除当前文件；同一 Content 单读取队列前台优先，预取只填缓存。
- invalidate/隐藏/关闭清除旧预取队列；在途读取不强制中断，正常关闭 fd 后服务最新前台。预取版本变化不重试、不交付错误到 UI。
- 新增真实磁盘预取去重/缓存命中/取消待预取回归。43 项测试通过，LuaLS Hint 55 文件无诊断。未做终端延迟基准，不宣称已验证性能提升。

第三十批：

- 真实预览内容显示绝对行号，禁用相对行号；Loading/错误/空结果不显示行号。
- View 在布局重建前保存 preview winsaveview，重新出现时恢复视图、wrap/number 窗口选项；内容切换定位更新保存状态。
- UI 回归检查行号、错误无行号、滚动后 toggle 重建恢复视图及行号。42 项通过，LuaLS Hint 54 文件无诊断。
- 邻近文件预取仍待实现；低高度自动隐藏走相同 resize 路径，实际终端连续缩放仍待验收。

第二十九批：

- C-f/C-b 默认滚动预览半窗，公开 Actions.scroll_preview(lines?, direction?) 支持指定有符号行数；隐藏时 no-op，保留输入焦点与业务选择。
- UI 测试通过原生映射验证上下滚动、同项 refresh 保留视图、超大步长夹紧及焦点/选择不变。更新 Actions 白名单回归。
- 42 项测试通过，LuaLS Hint 54 文件无诊断。窗口重建时视图恢复、邻近预取仍待完成。

第二十八批：

- Preview 保留最后显示快照；同路径/定位更新不显示 Loading，完成版本检查且内容相同时不重写 buffer/重载 syntax/重置视图。文件内容变化仍更新。
- UI 回归检查刷新前后 changedtick 不变、没有 Loading 闪烁，以及磁盘修改后同项刷新读取新内容。
- 42 项测试通过，LuaLS Hint 54 文件无诊断。滚动 Actions、窗口重建时视图恢复及邻近预取仍待完成。

第二十七批：

- Preview 根据路径/内容检测文件类型，仅 scratch buffer 加载原生 syntax runtime，不全局 syntax enable、不触发 FileType 钩子；错误/Loading/空状态清理旧 syntax。
- 真实 demo 单独启用 filetype on / syntax enable，确认打开的真实文件也有原生语法高亮。未接 Treesitter。
- Preview UI 回归在 -u NONE 下检查 Lua local token 存在 syntax group、错误消息清除旧语法；42 项通过，LuaLS Hint 54 文件无诊断。

第二十六批：

- Preview 对象连接 Session 当前条目与 View 持有的 pane/buffer。C-o 现在显示真实纯文本内容、Loading/空状态/读取错误；键盘/鼠标移动更新，toggle/resize 重取当前项，关闭立即取消交付。
- 内容读取上限暂为 1MiB，已用缓存/版本/单读取队列。语法高亮、滚动动作、邻近预取及避免同项刷新闪烁仍待完成。
- 新增真实文件 UI 回归：内容、移动到缺失文件、输入焦点、关闭重开预览、资源清理。42 项通过，LuaLS Hint 54 文件无诊断。

第二十五批：

- PreviewCache 迁移旧 LRU 的容量/最近使用语义，最多 32 文件/8MiB，版本不符即失效；快照存取复制数组，超大替换不驱逐其他条目。
- Content 交付前验证版本后缓存，排队相同路径复用已完成读取，关闭清空缓存；默认限制留在 preview scope，读取层不依赖 popup。
- 41 项测试通过，LuaLS Hint 52 文件无诊断。预取、Session/pane 接入、语法高亮/滚动仍待完成。

第二十四批：

- PreviewContent 读取/交付前后比较版本：loaded buffer changedtick，磁盘 mtime(sec/nsec)+size；变化时丢弃结果，仅当前请求重排，旧请求不替换更新的 pending。
- 新增真实磁盘读完交付前写入、buffer 交付前修改回归，确保重读后交付最新内容。
- 40 项测试通过，LuaLS Hint 49 文件无诊断。缓存、预取及预览 pane 接入仍待完成；本批没有宣称完整 Preview 可用。

第二十三批：

- PreviewContent 改为单个 active + 最后一个 pending；连续请求不再无限并发，关闭丢弃待处理但正常释放正在读取的 fd。
- 新增真实磁盘队列回归：100 次请求只发起首尾两次读取，仅第 100 次交付；关闭后不发起 pending。
- 39 项测试通过，LuaLS Hint 48 文件无诊断。版本检查、缓存、预取和 Session 接入尚待完成。

第二十二批：

- PreviewContent 首个独立切片：已加载缓冲区优先、uv 异步磁盘读取、大小上限/非普通文件/二进制保护、CRLF 处理、最新请求交付和关闭失效。打开的 fd 在完成路径关闭。
- 两项真实临时文件回归涵盖读取、超限、二进制、缺失、未保存缓冲区及过期交付；38 项通过，LuaLS Hint 47 文件无诊断。
- 尚未接入 Session/preview pane；缓存、限制并发读取队列、文件版本检查、预取及语法高亮/滚动仍需迁移。当前阅读器允许并发，不能称为已达到旧 Preview 完整行为。

第二十一批：

- 新增 picker-format.lua 两项回归：basename-first 中文路径跨段匹配、分隔符排除、无目录和控制字符归一化；真实窄 pane 截断后的高亮不覆盖省略号、不切 UTF-8，刷新清除旧范围。
- 36 项测试通过，LuaLS Hint 45 文件无诊断。本批只补列表格式回归，Preview 内容尚未实现。

第二十批：

- 按最终确认格式，仅将图标与文件名间隔改为两个空格：`▊   view.lua lua/picker/picker/session`；其余间距不变。
- picker-icons.lua 三项检查通过，包括双空格显示断言。

第十九批：

- 修正 files 格式为外侧空格 + 状态格 + 空格 + 可选图标/一空格 + basename + 一空格/目录（旧目录间隔为一格）。目录 Comment 弱化。
- 迁移旧 render 的路径段/fff 半开字节范围映射；高亮裁剪不覆盖省略号，图标/目录/匹配统一清理。
- 图标 UI 测试现检查 src/a.lua 显示为 λ a.lua src。34 项通过，LuaLS Hint 44 文件无诊断；复杂 Unicode 跨段匹配还需专门回归。

第十八批：

- view.icon 支持 nil 自动发现、false 禁用、fun(absolute_path): glyph?, highlight? 自定义；自定义优先，无返回值不回退默认，校验返回字符串及单行约束。
- 真实 fff demo 自动加载本地 core/opt/nvim-web-devicons，DEVICONS_NVIM_PATH 可覆盖；依赖缺失仍无图标运行。
- 34 项测试通过，LuaLS Hint 43 文件无诊断。隔离 headless demo 已实际加载本地 fff+devicons 并检测到图标高亮 extmarks；终端字体显示仍待人工查看。

第十七批：

- 可选图标：优先已加载 MiniIcons，否则尝试 nvim-web-devicons；无依赖时不显示、不留图标空位。每个 View 解析一次提供者。
- 图标进入共享截断文本，专用 namespace 只高亮完整保留的图标；保留外缩进/状态格/分隔空格，条目身份不变。
- 新增缺失依赖、图标间距、Unicode 字节范围及清空结果测试；33 项通过，LuaLS Hint 43 文件无诊断。
- 图标测试使用模拟提供者，尚未验证用户实际图标主题。路径重排/匹配高亮和 Preview 仍待迁移。

第十六批：

- 修正 Git/Tab overlay 默认 replace 高亮覆盖当前行背景的问题：状态 extmark 使用 hl_mode=combine。
- View 回归先验证旧实现缺少 combine 失败，修复后 Git/Tab 两种标记检查通过。此测试验证实际 extmark 配置，不是终端像素验收。
- 31 项测试通过，LuaLS Hint 41 文件无诊断；主题自定义背景下的实际终端效果仍需查看。

第十五批：

- 按用户要求整体右移一个 cell：外侧空格 + Git/Tab 状态格 + 分隔空格 + 内容。
- list_padding.left=3、status_column=1 集中配置；极窄列表不绘制超出宽度的状态标记。
- 测试检查 Git/Tab 标记列与条目起始空格；31 项测试通过，LuaLS Hint 41 文件无诊断。

第十四批：

- 默认布局按旧阈值 root.width < 160 上下排列，否则左右；上下时 root.height < 10 暂时隐藏预览，View 保留 requested 状态，恢复高度重新出现。自定义 layout 自主管理。
- 固定状态位一格 + 分隔空格，Git 基本状态标记与 Tab 共用且 Tab 优先；无状态时文字位置不变。staged 明暗混色和可选图标尚待迁移。
- `node tests/picker.ts`：31 项通过，新增真实窄/宽窗口布局、低高度恢复、Git/Tab 优先级和间隔测试。LuaLS Hint 41 文件无诊断。
- 预览仍为空 pane，终端视觉与连续 resize 体验需人工验收。

第十三批：

- 用户提供 fff 根目录 `~/.local/share/nvim/site/pack/core/opt/fff`；该版本入口为 lua/fff.lua，之前只查 init.lua 漏检。
- 隔离 headless 进程加载真实 fff：查询 session 返回 26 项；公开 open 输入 picker-session、确认、关闭 popup 并打开对应真实文件，通过。
- 新增 `node tests/demo-picker-fff.ts [cwd]`，FFF_NVIM_PATH 可覆盖依赖根目录；只修改独立进程 runtimepath，不使用个人配置。Enter 会实际打开文件。
- LuaLS Hint 41 文件无诊断；真实终端流畅度、根目录切换等仍未完整验收。
- 用户新确认：图标插件缺失静默无图标；Git/Tab 共用固定状态位，Tab 优先，与条目间留一空格。此呈现调整尚待实施。

第十二批：

- 多选标记以独立 namespace 覆盖左 padding 显示 ▊，不扩展 signcolumn 或改变已有截断宽度。
- 输入右侧显示结果总数、Indexing…、已标记数量；长查询/窄输入时隐藏，避免覆盖输入光标。
- 标记只更新装饰，不额外执行搜索；结果刷新后重建可见标记。
- `node tests/picker.ts`：30 项通过，新增标记显示/取消、selected 数量、Unicode 长查询状态隐藏验证。LuaLS Hint 40 文件无诊断。
- 仓库及 ~/.local/share 下仍未找到 fff/init.lua，真实 fff 联调仍未验证；图标/Git/富文本匹配与 Preview 尚未完成。

第十一批：

- 输入默认 40ms 防抖，TextChanged 即刻使旧轮询和页预取失效；动作仍同步最新查询。
- `tests/picker-scheduling.lua` 使用受控 defer 队列与真实 Neovim 输入事件/窗口：索引轮询、仅最新查询搜索、ready 停止重试、确认越过防抖、关闭后不搜索，3 项通过。
- `node tests/picker.ts`：29 项通过；LuaLS Hint 40 文件无诊断。
- 本批未进行真实 fff 安装/加载和性能测试；本机常见 nvim 数据目录搜索未找到 fff/init.lua。真实后端 demo 仍待接入；不自动安装依赖。

第十批：

- backend/fff.lua 迁移旧 files adapter：cwd 校验、索引根目录保护、零等待扫描检查、ready 后第二次查询；不进入 fff UI。
- 公开 `require('picker').open({ mode = 'files', cwd, view, keymaps, group })` 已连接 Session 和完成动作；grep/resume 尚未开放。
- Session 显示 Indexing… 并按 100ms 轮询，revision/closed 淘汰旧重试。输入防抖与可配置扫描间隔尚待完善。
- `node tests/picker.ts`：26 项通过，fff adapter 使用模拟模块验证；LuaLS Hint 39 文件无诊断。
- 未在默认 lazy 路径找到本机 fff，尚未运行真实 fff 搜索；固定数据 demo 不变。未修改个人配置。

第九批（用户明确要求默认 input/list 与 Select 样式一致，支持鼠标选择）：

- 默认 input/list 使用 Select 同款连接边框；input inline 前缀 Files/FloatTitle，保留共享行 padding/截断。
- LeftMouse 原生映射通过显示行几何命中 Controller，点击只选不确认；root 内边框/空白不当成外部，真正外部点击取消。
- demo 单独启用 mouse=a；插件不更改全局 mouse。
- `node tests/picker.ts`：25 项通过，新增真实 nvim_input_mouse + 映射测试，验证第三行选择、未确认和输入焦点保持。
- LuaLS Hint：36 文件无诊断。grep 分组尚未接入，后续必须将显示行转换为条目并排除标题。前缀当前 Files，随 mode 配置待 fff/grep 接入；终端视觉待验收。

第八批：

- Session 完成结果快照与 completion.execute：edit/split/vsplit/tab、quickfix；清理后交付，回调错误报告。
- Actions.open/quickfix/mark 与 C-s/C-v/C-t/C-q/Tab/S-Tab 默认映射接通；标记呈现和状态数量仍待完善。
- `node tests/picker.ts`：24 项通过，新增真实临时文件四种打开/行列定位/窗口清理顺序，以及有序 quickfix 验证。
- macOS 临时路径别名导致字符串路径比较失败，测试改以 realpath 验证同一文件。
- LuaLS Hint：36 文件无诊断。demo 仍只输出选择、不执行文件打开；真实 fff 入口尚未接入。

第七批：

- `session/bindings.lua` 负责声明映射解析，默认映射集中到 config；Actions 类型在 picker/types.lua。
- 已支持 confirm/cancel/move/page/toggle_preview，字符串动作、false、Actions 回调和原生字符串动作透传；open 四种方式/quickfix 尚未接入，未提供空实现。
- Session 的内部构造器暂以第四参数接映射覆盖，最终公开 Options 尚未接入。
- `node tests/picker.ts`：19 项通过；新增自定义映射、禁用映射、Actions 最小表面、关闭后保留的 Actions 无效、调用方配置不变检查。
- LuaLS Hint：34 文件无诊断；尚未新增类型负向探针。下一步完成动作与 fff 接入，仍不修改个人配置。

第六批：

- `session/init.lua`：正式内部会话，事件注册先于 open，支持原生 group；关闭先失效 Search/监听，再调度 UI 清理与回调。
- demo 只保留固定数据及启动；不再自行绑定按键、分页和清理。
- 修正宽度变化/预览切换未改变页大小时重置选择的问题；只在 Search.resize 返回目标时按换页刷新。
- `node tests/picker.ts`：18 项通过（Controller 5、Search 6、View 4、Session 3）。Session 通过原生映射连续移动 80 次，验证切换布局/resize 保持选择、完成一次、最新查询不确认旧项、外部焦点取消、missing group 清理。
- LuaLS Hint：32 文件无诊断。missing group warning 为预期负向测试。
- 尚未测原生 group 实际替换、完整开窗中重入或用户终端视觉；仍需补齐。

第五批：

- 新增 config.layout，准备新鲜原生节点并校验树、必需角色和 buffer 身份；配置深拷贝。
- View resize/toggle_preview 复用输入窗口与 buffer；demo 保存逻辑位置后调用 Search.resize。
- `node tests/picker.ts`：Controller 5、Search 6、View 4 项通过；View 新覆盖自定义上下布局、preview 切换、输入内容/窗口保留、缺失和重复 pane 的清理。
- LuaLS Hint：30 文件无诊断。尚未人工视觉验收；预览内容尚未实现。

第四批：

- `session/view.lua` 显式拥有 popup 和自有 buffers，负责查询读取、页高度、列表呈现及幂等释放；demo 已改用 View。
- `tests/picker-view.lua`：真实 Neovim 窗口验证呈现、空结果、重复关闭、open listener 失败资源释放，2 项通过；已加入 `tests/picker.ts`。
- Controller/Search 11 项仍通过，LuaLS Hint 29 文件无诊断。
- 尚未实现公开布局配置、preview 和 resize；默认几何仍为 demo 阶段配置，终端视觉待用户检查。

第三批：

- 新增 `tests/demo-picker.lua` 与附着终端 runner `tests/demo-picker.ts`，未接入个人配置。
- LuaLS Hint：27 文件无诊断。
- headless 原生 popup 冒烟：执行 80 次向下移动后取消，仅剩来源窗口。尚未人工终端视觉验收。
- 临时 demo 的绑定/布局只用于验证现有 Controller/Search，不作为最终公开实现。

第二批迁移：

- `nvim --headless -u NONE -l tests/picker-search.lua`：6 项通过，覆盖 files 边界/缓存/resize、预取失效、LRU 淘汰、grep continuation/索引重试/模式变化、前台与预取错误边界。
- `node tests/check-lua.ts`：26 文件，Hint 无诊断。
- 新增 `node tests/picker.ts` 汇总纯 Controller 与 Search 测试。
- Search 迁移旧分页算法，改为对象持有状态；三页缓存暂留同文件，不提前创建通用缓存框架。
- PageSource 统一调用形状为 query/size/mode/position，fff 转换尚未接入。
- 原生 UI、真实后端与终端性能仍未验证。

第一批迁移：

- `nvim --headless -u NONE -l tests/picker-controller.lua`：5 项通过，覆盖目标夹取、空结果、身份保持、跨页标记、grep 身份、邻近去重和失败原子性。
- `node tests/check-lua.ts`：24 文件，Hint 检查无诊断；本批未新增类型负向探针。
- `node tests/selection.ts`：8 项通过。
- `node tests/select.ts`：6 项通过。
- 新 Lua 文件已用 StyLua 格式化。
- 尚未实现新 Picker UI，未做新 Picker 终端视觉验证。旧配置与 Select 实现未修改。

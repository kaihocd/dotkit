# Picker 全域重构：实现核对与验收

范围：files/grep Picker。Select、共享 renderer/Selection、个人配置不在本轮重构范围。
本记录对应新 `lua/picker/picker/`，不是冻结 `picker-bak/` 的验收。

## 原实现到当前 owner

路径相对旧/新 `lua/picker/picker/`。原备份共 27 个文件，按以下归属覆盖。

| 原实现                                               | 当前 owner / 调用边界                                                                | 验证入口（tests/，省略 picker- 前缀）                          |
| ---------------------------------------------------- | ------------------------------------------------------------------------------------ | -------------------------------------------------------------- |
| init.lua                                             | init.lua + options.lua；创建新 source/Panel，持有 latest 值快照                      | options、resume、backend、types.ts                             |
| config.lua                                           | config.lua 保留默认值/公开类型；window/layout.lua 执行布局计算与验证                 | options、view、group-errors                                    |
| presentation.lua、types.lua                          | 保留解析和公开契约，不承担运行状态                                                   | presentation、types.ts                                         |
| backend/fff.lua                                      | 保留实际 fff API、共享索引 readiness、规范化 Entry                                   | backend、fff-integration、fff-resume                           |
| snapshot.lua                                         | 读取 Panel:snapshot_state()，复制 options、裁剪为 location 数据                      | snapshot、resume                                               |
| session/init.lua                                     | panel.lua 组装/用户意图/错误边界；input.lua debounce；list/init.lua 列表任务         | input、list、scheduling、session、action-errors                |
| session/lifecycle.lua                                | 合入 Panel，唯一 started/closed/save/complete                                        | replacement、group-errors、completion                          |
| session/search.lua                                   | list/pages.lua 的缓存/交付/pending target；files.lua 逻辑坐标；grep.lua continuation | search、list、session-retry、grep-session                      |
| session/restore.lua                                  | list/restore.lua 每步一次搜索；List 安排下一步                                       | restore、resume-session、fff-resume                            |
| session/controller.lua                               | selection.lua；唯一共享 Selection 实例保存 current/ordered marks                     | controller、grep-session、completion                           |
| session/actions.lua                                  | editor/actions.lua 参数校验及 guarded execution，无业务状态                          | action-errors、types.ts                                        |
| session/bindings.lua                                 | editor/bindings.lua mappings；PickerBindings 独占 autocmd IDs                        | bindings、session、theme                                       |
| session/completion.lua                               | completion.lua；UI 关闭后执行 Neovim 命令                                            | completion、fff-integration                                    |
| session/view.lua                                     | window/init.lua UI 资源及 pane 组合                                                  | view、session、replacement                                     |
| session/view/input.lua                               | window/input.lua 无自有文本状态，读写 Window 管理的 pane                             | input、resume、scheduling                                      |
| session/view/list.lua                                | window/list.lua；ListPane 独占 rows/entry_rows/row_entries                           | grep-view、view、presentation                                  |
| session/view/preview.lua                             | window/preview.lua；viewport/number/syntax/matches                                   | viewport、preview-ui                                           |
| session/list/init.lua、session/format.lua            | window/row.lua formatter 契约；window/format.lua 默认格式                            | presentation、format                                           |
| session/icons.lua、signs.lua、syntax.lua             | window/ 下对应模块；不进入后端 List                                                  | icons、signs、syntax、theme                                    |
| session/preview/init.lua                             | preview/init.lua 内容交付与 freshness；仅使用显示能力                                | preview-ui、preview-prefetch                                   |
| session/preview/content.lua、cache.lua、defaults.lua | preview/ 下对应模块；保留单 active/latest pending、版本检查及 LRU                    | preview-content、preview-queue、preview-version、preview-cache |

旧测试名里的 session/controller/search 保留，便于与历史行为用例对照；它们导入的是新对象，不是旧模块。

## 状态和接口核对

- **Input**：pane 是原始文本唯一来源；Input 只存 read/write 能力和 debounce generation，不注册 autocmd、不管理 buffer。Panel 在构造时提供 Window 的 query/restore_query 能力，最终由 InputPane 读写。
- **List**：`load/move/resize/restore/interrupt_restore/snapshot/close` 为外部入口；`continue_loading` 必须在页面成功应用后调用，避免渲染失败后仍安排工作。
- **ListPages**：缓存、pending target、最后交付页及预取 freshness。FilePages/GrepPages 分别拥有坐标/offset。三页 LRU 放在共同的 pages 层，因为 files/grep 都要缓存与恢复前页；并非重复两份缓存实现。空的 files accept / grep resize 是这两个分页策略明确的“不适用”行为，不是转发对象。
- **generation 分层**：Input 防止旧 debounce 交付；List 防止旧 poll/restore 交付；ListPages 防止旧预取写缓存。各自只修改自身 token，无互相读写 revision。
- **Selection**：Entry identity 适配与 nearby 去重是 Picker 层行为；共享 Selection 是 current/marks 的唯一 owner。List 给 target，不修改 Selection。
- **Window**：只接收 entries/index/is_marked 等投影输入，不读取 List/Selection 字段。ListPane 保存行映射，PreviewPane 保存 viewport；buffer 只由 Window 释放。
- **Preview**：Content 负责读队列和文件版本；Cache 负责容量/新近性；Preview 负责是否交付和是否重写；Pane 负责显示。nearby 从 Panel 传入，不反向获取 Selection。
- **Panel**：`_query/_result` 表示已应用到 Selection 的页面，是用户操作一致性和状态栏的上下文，不负责搜索缓存或调度。refresh 只执行 flush → List → Selection → Window/Preview → 安排 List 继续加载。bind 只连接回调，翻页计算在 page 方法。
- **关闭**：Panel 防重入、捕获快照、关闭 Input/List/Preview、解绑事件，然后延迟退出 group/释放 UI/恢复 origin/完成回调。无独立 Lifecycle 状态，无 Pane 自行完成业务。
- **Bindings**：对象保存事件句柄；静态 mappings 由 popup 原生扩展随 UI 释放。注册失败清理已经取得的 IDs，不依赖调用方拿到返回值。
- **Snapshot**：中间 SnapshotState 不是公共 API；最终快照复制配置和 location，不保存 source、Pane、缓存页或对象引用。

这是具体对象之间的协作，不引入 Source 框架、事件总线或通用技术角色。内部名称/签名可与原方案示例不同，但状态所有权保持。

## 自动化验收

完整命令见 picker-refactor-todo.md。`node tests/picker.ts` 包括新增 Input、List、Bindings 部分注册失败、独立 viewport，以及 resume marker/empty/indexing 的实际 buffer/extmark 断言。

类型验收保留两个限制：LuaLS 接受部分非法 inline formatter 返回值；Selection 数组元素类型探针存在 LuaLS 本身的限制。运行时验证仍执行，LIMITATION 不记作通过的负例。

## 待人工终端验收

在插件目录运行：

```sh
node tests/demo-picker-fff.ts /Users/qihao/dotkit
```

使用隔离 Neovim 配置，确认会实际打开文件；不修改个人配置。

1. Files 连续输入、删除、立即 Enter：应打开最新查询对应当前项；Tab 标记后继续跨页/换查询，C-q 顺序不变。
2. `:PickerGrepDemo` 输入常见词，多页 C-d/C-u、C-n/C-p：无重复/漏跳，文件标题不可选；C-l 切模式后仍保留输入，C-r 保持原生。
3. C-o 打开预览，C-f/C-b 滚动；反复隐藏/恢复、改变终端宽高：焦点仍在输入，当前项及 viewport 合理保留。
4. 长 grep 列表滚动后用鼠标点内容/标题/边框：只内容可选，不确认、不把焦点移入列表；点击外部关闭。
5. Esc 后 `:PickerResumeDemo`，继续输入；再次取消/恢复：查询、模式、marks、位置、预览请求状态保留。
6. group replacement 可在关闭 Picker 后执行下面命令，再按 F8 连续替换两次；只剩一个 Picker，Esc 后 F9 恢复，不发生旧窗口抢焦点。

```vim
:lua local g = require('popup').group('picker-manual', { on_join = function(instance, members) instance:on('open', function() for _, other in ipairs(vim.list_extend({}, members.instances)) do if other ~= instance and other:is_open() then other:close() end end end) end }); vim.keymap.set({'n','i'}, '<F8>', function() require('picker').open({ group = g.name }) end); vim.keymap.set({'n','i'}, '<F9>', function() require('picker').resume() end)
```

自动化覆盖同类行为，但不能替代此次人工观感与真实终端焦点验收。此项通过前，不宣布所有验收完成。

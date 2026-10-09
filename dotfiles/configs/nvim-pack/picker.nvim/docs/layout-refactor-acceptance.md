# Layout 重构阶段证据

> 下文侧边 detail 记录是历史证据，已被原位切换实现取代。当前行为与本轮验证见 [select-detail-transition-todo.md](select-detail-transition-todo.md)；不能用旧测试记录证明新交互通过。

状态：进行中，不是最终验收。执行计划见 [layout-refactor-todo.md](layout-refactor-todo.md)。

## 本阶段：独立 Select detail

已实现：

- 默认布局初始仅 input/list；打开全文时由 Window 临时挂载右侧独立 detail，退出时恢复原布局。
- 自定义布局明确包含 detail 时，全文动作只渲染该 pane；省略 detail 则不插入额外布局，也不展示全文提示。
- list buffer、装饰、光标不再被 detail 改写；Detail 只保存自己的窗口选项和 viewport。
- 多行文本按实际换行符拆分。
- buffer 逐个分配、立即登记；删除旧的 prepare_buffers 递归补分配路径。
- Select layout 对原始 pane 引用、ID、类型、buffer 做校验；拒绝 nil/false 返回、重复引用和循环。

本次测试：

| 检查                                                         | 结果                     | 日志                                 |
| ------------------------------------------------------------ | ------------------------ | ------------------------------------ |
| Select UI + 对象 + 新 layout 集成测试                        | PASS                     | `/tmp/select-detail-current.log`     |
| LuaLS                                                        | PASS，94 文件无诊断      | `/tmp/layout-luals-current.log`      |
| Picker / Select / Selection / public types / Selection types | PASS（类型局限单独输出） | `/tmp/layout-regression-current.log` |
| 冻结 backup SHA-256                                          | PASS                     | `/tmp/layout-backup-current.log`     |

新增 `tests/select-layout.lua`：上下/左右嵌套布局、独立多行 detail、非法 callback、pane/buffer 篡改、循环、第二次 buffer 分配失败后的清理。

## 后续阶段：Picker 校验审计与使用文档

- Picker 校验保存 callback 之前的 pane 引用；即使替换的新 pane 使用相同 ID/buffer，也会拒绝。
- 两个 builder 拒绝空容器、非数组 children；Select 同时校验未挂载的 detail 身份。
- 新增 `tests/picker-layout.lua`，注册进 Picker 完整测试：非法返回、替换身份、循环、分配失败，以及上下/左右布局 resize/toggle 保留 query/buffer。
- README 已移除旧 root override 示例，新增 [layout.md](layout.md) 使用文档。
- Picker 回归：`/tmp/layout-picker-audit.log`；Select UI：`/tmp/layout-picker-audit-select.log`；LuaLS：`/tmp/layout-picker-audit-luals.log`，均通过。

## 后续阶段：Select resize

- Bindings 注册/清理 `VimResized`；Panel 捕获 resize 失败并通过 close-once 完成取消。
- Window 保存初始 texts 和屏幕锚点，resize 不使用过滤结果或 input cursor 重新测量。
- 重建保持 query/buffer、列表光标和 detail 活跃状态及 viewport。
- 新回归覆盖自定义与默认 detail resize、callback 失败后监听移除、小屏幕高度不足的取消和资源释放。
- Select UI：`/tmp/layout-resize-ui.log`；完整 Picker/Select/Selection/LuaLS/types：`/tmp/layout-resize-full.log`，通过；已知类型局限仍单独报告。
- backup hash：`/tmp/layout-resize-backup.log`，通过；`git diff --check` 通过。

## 集中收尾验证

- `tests/picker.ts`、`select.ts`、`select-ui.ts`、`selection.ts`、`check-lua.ts`、`picker-types.ts`、`selection-types.ts` 全部执行成功：`/tmp/layout-final-suite.log`。
- 全插件 lua/tests StyLua check：`/tmp/layout-final-format.log`，通过。
- 真实 fff grep、preview、cleanup-before-open 和三页 resume：`/tmp/layout-final-fff.log`，通过。
- backup hash：`/tmp/layout-final-backup.log`，通过；git diff --check 通过。
- 49 个运行模块无 require 环、backup 引用或 Select→Picker 依赖。
- Select detail 挂载错误现由 Panel 捕获并取消一次；新增故障注入回归。旧字段拒绝回归覆盖五种角色。
- README 和 picker-plan 已移除当前旧入口描述。仓库外层扫描结果 `/tmp/layout-callers.txt` 中的 `plugins.explorer.picker` 是另一套实现，不属于本插件调用方，未迁移。

## 明确范围与剩余验收

不实现自动 root 尺寸推导：调用者负责让固定尺寸与边框适合预算，失败应取消并清理。
自定义常驻 detail 退出后保留最后文本并恢复自身窗口选项；不改写 list。

人工终端验收仍未完成，不能用以上 headless 结果代替：

1. `node tests/demo-picker.ts`：默认及自定义上下/左右布局，preview toggle、滚动和 resize。
2. `node tests/demo-select.ts`：默认全文打开/退出；自定义 detail；Unicode、列表点击和外部焦点取消。
3. 窄终端缩放、Esc、group replacement、callback reopen；确认不残留窗口、不抢外部焦点。

TODO 中未逐项取得证据的历史条目保持未勾选；本记录不等于所有阶段均已完成。

已知 LuaLS 对 Select 泛型 callback/Actions、inline formatter 和 Selection 数组的推断局限仍存在，不计为类型安全通过。

# Select 重构实现记录

状态：运行对象已迁移，自动化持续通过；执行 TODO 尚有未核账项，人工验收未完成。

## 旧实现到新 owner

| 旧路径/字段                                        | 新 owner                                                                          | 测试                                             |
| -------------------------------------------------- | --------------------------------------------------------------------------------- | ------------------------------------------------ |
| session/controller.lua entries/query/selection     | SelectList，唯一共享 Selection 实例；texts 返回新数组                             | select.lua、select-objects.lua                   |
| session/view.lua measure/geometry                  | window/layout.lua 实际测量与约束                                                  | select-ui.lua                                    |
| session/view.lua popup/release_buffers             | SelectWindow 的 popup/_buffers，获取立即登记，close 释放                          | select-ui.lua 部分挂载/监听器失败、caller buffer |
| session/view.lua render/select/hint                | SelectWindow；prompt 行偏移和 clipping 在显示层                                   | select-ui.lua                                    |
| session/detail.lua pane/snapshot                   | Window 内 DetailPane；回到列表的重画/恢复顺序不再交给 Panel                       | select-objects.lua、select-ui.lua                |
| session/lifecycle.lua finished/origin/on_choice    | SelectPanel 的 closed/origin/complete                                             | select-objects.lua、select-ui.lua group          |
| session/bindings.lua autocmds/unbind               | SelectBindings 的 events/detach；注册失败回滚                                     | select-objects.lua                               |
| Session keymaps/detail_key                         | SelectBindings 的 configured/detail_key；Panel 只查询提示键                       | select-ui.lua                                    |
| Session query/controller/popup/detail/view_options | Panel 只保存 raw query、List/Window/Bindings 引用；无 buffer、viewport 或显示配置 | select-objects.lua、源码复读                     |
| select/init.lua                                    | 创建 SelectPanel；公共入口不变                                                    | select-ui.lua、公开类型探针                      |
| config.lua/types.lua                               | 保留公共默认值/类型和解析行为                                                     | select-ui.lua、公开类型探针                      |

## 内部签名与兼容说明

- Window.hit 返回过滤列表位置；0 表示 prompt，nil 表示列表外。0 是明确不可选的哨兵，用于保持“点击 prompt 不关闭、不确认”的行为。
- Detail 返回列表时 Window 内部执行 close → render → restore；新结果 render 丢弃旧 viewport。
- Window.focused(input_only) 区分外部焦点取消与完成时是否恢复来源窗口；不把两个语义合并。
- Panel.close 先 claim，再 detach，然后 schedule Window.close 与回调；group leave 错误通知，但不跳过释放资源和最终完成。
- Bindings 是一次性 attach 对象，重复 attach 不叠加原生 listener；detach 可重复，关闭后 open listener 不注册事件。
- 保留现有 formatter 先于 view 配置校验的顺序，避免重构改变 caller formatter 的调用/错误行为。view 校验仍在任何 UI 分配之前。声明映射解析提前到 UI 分配前，避免解析失败遗留 buffer。
- normalize 在 UI 中仍由 vim.fn.tolower 提供；不在此次重构中修正既有 Options.normalize 行为差异。

## 类型证据

现有 picker-types.ts 增加 Select 正例及两项负例：inferred Actions.move 参数、callback item 运算。
新实现两项负例均被 LuaLS 接受，明确报告 LIMITATION，不认证推导有效。
已将冻结 select-bak 放入独立临时插件运行同一探针，原实现也输出相同两项 LIMITATION。
基线对照整套命令在后续 Picker 负例阶段超时，不能称完整基线类型套件通过；Select 两项对照输出已取得，见 `/tmp/select-original-types.log`。

## 当前证据

- Select/Select UI/Selection/Picker 运行回归通过。
- 新 select-objects.lua 已注册到 select-ui.ts，不是手工运行后遗漏的测试。
- Hint93 无诊断；既有与新增类型 LIMITATION 均保留。
- 冻结 select-bak 9 文件 hash 复验一致，清单 `/tmp/select-backup.sha256`。
- 实现中间态日志：`/tmp/select-owner-review.log`、`/tmp/select-final-ui.log`、`/tmp/select-final-picker.log`。

## 待人工验收

插件目录运行 `node tests/demo-select.ts`，检查光标附近布局、过滤后几何稳定、数字定位、长项 detail/hint、退出 detail 的 viewport、鼠标与外部焦点、自定义映射及 callback/group 替换。自动化通过不代替本轮终端观感。

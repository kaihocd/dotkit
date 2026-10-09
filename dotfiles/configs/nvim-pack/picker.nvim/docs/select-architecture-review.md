# Select 对象重构方案

状态：代码审阅完成，待按本方案迁移。具体执行步骤、阶段出口与验证要求见 [select-refactor-todo.md](select-refactor-todo.md)。范围仅 `lua/picker/select/`，不复用 PickerPanel，不同时改公共行为。

## 当前问题

不是 Session 太长，而是对象边界没有成立：

- Session 同时持有 popup、view_options、prompt、query、detail，直接读 buffer、计算 list 行号和半页高度。
- View 是函数集合，create 返回 popup 与 release_buffers 闭包；UI 资源先在 View 分配，再交给 Lifecycle 保存释放操作。UI 生命周期无法在一个对象内理解。
- Lifecycle 保存 finished/origin/callback/popup，但是否 active 的判断贯穿 Session。一次交互的关闭协议被切成两个必须一起阅读的对象。
- Detail 的 pane、wrap、cursorline、viewport 全是显示状态，却由 Session 驱动“退出 detail → render → 执行恢复闭包”的底层顺序。
- Controller 已有原始条目、过滤查询和共享 Selection 实例，职责实际是一个可过滤的选择列表，而不是泛泛的控制器。
- Bindings 用闭包保存 autocmds，生命周期通过返回的 unbind 闭包转交 Lifecycle；绑定过程中失败的所有权不够直接。

## 目标对象

Select 不需要复制 Picker 的对象数量。没有 backend 分页、异步预览、debounce 或 marks，因此不造 SelectInput、分页 SelectList + SelectSelection 两层、独立 Completion。

| 对象           | 状态                                                                   | 主要接口                                                                                                    |
| -------------- | ---------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| SelectPanel<T> | started/closed、来源窗口、最终回调、最近处理的原始输入、组合对象       | open、close、confirm、move、page、click、refresh、toggle_detail、commands                                   |
| SelectList<T>  | 全部预格式化 Entry、normalized query、唯一共享 Selection               | set_query、entries、texts、current_index、select、move、choice                                              |
| SelectWindow   | popup、owned buffers、resolved view、prompt、固定 geometry、DetailPane | open、close、query、render、select、hint、hit、focused、page_size、show_detail、leave_detail、scroll_detail |
| DetailPane     | 暂时借用的 list pane、原 wrap/cursorline/viewport                      | active、open、close、scroll；仅 Window 使用                                                                 |
| SelectBindings | 解析后的映射、detail key、事件 IDs、attached/closed 状态               | attach、detach；只接收 popup 注册资源、Actions 与窄回调                                                     |

### 选择与过滤为什么在 SelectList

这里的列表不是后端分页列表，而是一次 `select(items)` 的有序候选集合。过滤与可见选择替换必须保持 original index 身份，合在一个对象内更清楚。共享 Selection 仍然是 current 的唯一 owner；SelectList 不再保存第二份 current。不会为了模仿 Picker 将一个直接操作拆成两套状态接口。

### 输入为什么不单独类化

Select 每次事件同步过滤，没有 debounce 或输入队列。Window 提供 query()，Panel 比较 raw query，SelectList 比较 normalized query；后者相同时前者变化仍需要退出 detail，保持现有行为。这是两种不同语义的值，不是两个输入模型。

### Detail 为什么属于 Window

Detail 是把同一个列表窗格临时切换为完整文本，并不是业务数据源或文件预览。Panel 只表达“显示当前项全文”“回到列表”；Window 完成重新绘制与 viewport 恢复顺序，不再将 restore_view 闭包交给 Panel。

## 生命周期与依赖

```text
select/init → config / SelectPanel
SelectPanel → SelectList / SelectWindow / SelectBindings
SelectList → shared picker.selection
SelectWindow → layout / DetailPane / popup / shared picker.list
SelectBindings → popup keymap + autocmd API
```

- config 继续解析与复制配置，不持有 UI。
- layout 负责真正的测量、鼠标光标锚点与屏幕约束，不做 Window 薄转发。
- Window 在分配时记录所有 owned buffers；调用方提供的有效 buffers 不由 Window 删除。
- Panel 在任何可能重入前 claim close，Bindings.detach 后延迟 Window.close、按原焦点语义恢复来源窗口、完成回调一次。
- Window.close 退出 group、关闭 popup、释放 owned buffers；Panel 不直接遍历 buffers 或访问 extmark。
- Actions 继续只暴露命令和 choice，不向公共回调交出 Panel/List/Window。
- 不引入 Lifecycle、事件总线或通用 Controller，也不让 Select 依赖 files/grep Picker 对象。

## 目录

```text
select/
  init.lua
  config.lua
  types.lua
  panel.lua
  list.lua
  bindings.lua
  window/
    init.lua
    layout.lua
    detail.lua
```

Input/List panes 如无独立长期状态，保持 Window 内的局部实现；不为每个 pane 制造空壳对象。未来职责真正增长再提取。

## 行为冻结

- 返回原始 item 引用和原始 index，重复 label 不合并，空结果不确认。
- 数字 query 按原始 index 匹配，普通 query 按既有大小写归一化做字面包含；保留当前项身份。
- 初次测量后过滤不改变 popup 几何位置；prompt 占据第一行，不是可选条目。
- full-text detail、hint、半页滚动、退出后 viewport 恢复保持。
- mouse 不确认、不进入列表；外部 focus 取消且不抢焦点。
- native root/pane/keymap/group 配置和 caller buffer 所有权保持。
- 公共 normalize 字段当前在 UI 入口被 vim.fn.tolower 覆盖。这是既有行为与类型描述差异，本次不顺手修正；如需要改变应另行确认。
- 不安装全局 vim.ui.select override。

## 实施与验收顺序

1. 建立 Select/Select UI/Selection/Picker/Hint 基线；保存 Select 源码备份，排除备份重复类型。
2. Controller → SelectList；添加 texts()，使 Panel 不再重复将 Entry 投影为字符串。
3. 构造真正的 SelectWindow：收回资源释放、布局、query/hit/page_size、DetailPane 和返回列表流程。
4. SelectPanel 收回关闭协议，删除 Lifecycle；只保留用户动作与对象协作。
5. SelectBindings 独占句柄，注册失败 rollback；保持 Actions 泛型与运行行为。
6. 删除旧 session 路径、更新内部测试引用，写清原字段映射及架构差异。
7. 新增独立 Window detail/viewport、部分绑定失败、重复 close 与 callback reopen 回归。保持现有 UI 错误注入和 group 测试有效。
8. 最终 Picker/Select/Select UI/Selection、Hint 与类型、StyLua；真实终端验收另列，不以 headless 代替。

每步复读所有权和调用流程后再勾选；不以重命名、文件数或无诊断代替结构验收。

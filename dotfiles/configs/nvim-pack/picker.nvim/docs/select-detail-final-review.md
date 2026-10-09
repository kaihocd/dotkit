# Select detail 最终自动验收与质量审查

## 结果

- 最终全套 Picker / Select / UI / Selection / LuaLS / public types / Selection types 通过：`/tmp/detail-final-reviewed.log`。
- LuaLS inference limitation 仍由测试明确输出，不代表负例全部受类型系统保护。
- 真实 fff 搜索与三页 resume 通过：`/tmp/detail-final-fff.log`（质量修正前执行；修正仅涉及 Select）。
- backup hash 通过：`/tmp/detail-final-hashes.log`。
- 用户已确认 demo 中原生 wrap + linebreak 的折行效果正确。
- 其他人工终端组合操作不据此视为全部验收。

## 质量审查及修正

1. **过滤触发退出 detail 的错误边界遗漏**：refresh 的 render 可能执行用户 layout。现用 pcall 捕获并走 close-once；回归注入退出 callback 错误。
2. **移动退出失败后继续执行**：leave_detail 可能关闭 Panel；现立即检查 closed，避免继续修改 selection。新增断言确保选择不变。
3. **无效状态**：移除只写不读的 Window._root。
4. **废弃恢复协议**：Detail.close 返回的恢复闭包已无调用者，改为直接恢复自身 viewport；list viewport 仍由 Window 管理。

## 保留边界

- SelectList：原始 item/index、单行列表投影与原始 full_text。
- Panel：用户动作、截断门槛、完成与错误边界。
- Window：buffer/popup、布局模式、切换与 list viewport。
- Detail：原始全文写入、原生软折行、滚动。
- Bindings：映射与 autocmd 生命周期。

未新增 Controller、通用生命周期框架或拆文件。后续可以进一步统一 hint 与 action 的 clipping 调用入口；当前二者使用同一 renderer 判定，但仍各自取宽度。此项是可维护性改进，不应伪称已经完成。

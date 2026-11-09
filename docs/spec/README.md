# 规格导读

这里是项目规格的唯一入口。当前文档描述的是一个从零设计的个人跨平台工作环境系统，**只用于讨论、确认和完善规格，不包含实现代码，也不迁移旧实现**。

如果你第一次阅读，请按下面的顺序阅读，不要直接从某个模块文件开始：

```text
README.md
  ↓ 先了解阅读路线、术语和文档权威性

overview.md
  ↓ 了解系统目标、范围和非目标

architecture.md
  ↓ 了解 Bootstrap、三个模块、Platform、Runtime 的关系

modules.md
  ↓ 了解 Packages、Environment、Configurations 各自负责什么

contracts.md
  ↓ 了解模块对外提供哪些对象级能力和上下文

orchestration.md
  ↓ 了解 Profile 如何生成执行计划、调用对象和生成反操作计划

decisions.md
  ↓ 查阅已经确认、不能随意推翻的设计决策

open-questions.md
  ↓ 查看仍未确认的规格问题
```

## 如果只想快速理解系统

先看这三份：

1. [overview.md](./overview.md)：系统是什么；
2. [architecture.md](./architecture.md)：系统如何分层；
3. [modules.md](./modules.md)：每个模块负责什么。

核心关系可以先记成：

```text
Bootstrap
    ├── packages.neovim.install()
    ├── environment.DOTKIT_NVIM_CONFIG.attach()
    └── configurations.neovim.apply(context)
```

三个模块决定自己提供哪些对象和操作；Bootstrap 只根据用户配置选择对象、决定顺序、传递上下文并汇总结果。

## 如果想理解“怎么执行”

阅读顺序：

```text
contracts.md → orchestration.md → decisions.md
```

重点关注：

- 公开操作不是模块批量操作；
- Bootstrap 生成计划并逐项调用对象；
- 配置、软件包和环境变量的内部流程由各自模块拥有；
- 反操作计划根据实际执行记录生成，而不是只根据原始配置猜测；
- 各模块可以拥有自己的领域结果，不强制共享一个结果枚举。

## 如果想理解跨平台设计

阅读顺序：

```text
overview.md → architecture.md → modules.md → contracts.md
```

核心原则：

```text
Environment 定义稳定的变量契约
Platform 解析当前平台的实际值
Bootstrap/Profile 选择变量或提供经过验证的覆盖值
Configurations 使用上下文，不自行判断平台
```

平台可以改变实际路径、默认值、发布方式和权限要求，但不能随意改变公共变量的名称、类型或语义。

## 如果想查看当前还缺什么

阅读 [open-questions.md](./open-questions.md)。其中的内容不是已确认设计，不能当作实现要求。

已确认的设计结论见 [decisions.md](./decisions.md)。如果其他文档与决策记录冲突，应先修正文档冲突；不能默默采用旧说法。

## 文档职责

| 文档 | 回答的问题 | 权威范围 |
| --- | --- | --- |
| `README.md` | 应该从哪里开始读？ | 阅读路线和文档关系 |
| `overview.md` | 系统是什么，范围是什么？ | 目标、范围、非目标、术语 |
| `architecture.md` | 各层和模块如何连接？ | 分层、依赖方向、总体关系 |
| `modules.md` | 每个模块负责什么、不负责什么？ | 模块边界和所有权 |
| `contracts.md` | 模块对外提供什么能力？ | 对外操作、上下文、领域契约 |
| `orchestration.md` | Bootstrap 如何组织一次操作？ | Profile、计划、执行、反操作 |
| `decisions.md` | 哪些设计已经确认？ | 已确认决策 |
| `open-questions.md` | 哪些问题仍待讨论？ | 未决规格，不是实现任务 |
| `implementation.md` | 什么时候开始实现？ | 实现阶段占位说明 |

## 当前状态

- 规格正在完善中，不是最终实现说明；
- 未确认内容必须标记为 `[open]` 或 `[proposed]`；
- 具体 TypeScript 接口、目录结构和实现任务暂不在本阶段确定；
- 根目录 `CONTEXT.md` 仅是历史参考，不是当前架构、接口或开发顺序的权威规格。

## 阅读规则

1. 先读本文件，再按路线阅读其他文档。
2. 先看高层边界，再看公开契约，最后看执行编排。
3. 不从具体项目示例反推通用架构。
4. 不把 `open-questions.md` 中的内容当成已确认结论。
5. 发现文档冲突时，优先依据最新确认的 `decisions.md`，然后修正文档。
6. 规格确认不等于实现验证；当前阶段不开发代码。

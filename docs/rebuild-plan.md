# Dotkit 重建计划

> 本文件是本轮重建期间唯一允许保留的计划文档。
>
> 本轮重建的目标不是在现有文档、测试和目录上继续修补，而是先把历史维护材料移出当前仓库，只依据功能代码重新整理项目。文档和测试将在功能结构稳定后，按照本文件末尾重新定义的规范从零补回。
>
> 本文件同时是本轮重建的进度日志。每次完成一个阶段或产生重要结构决策，都必须更新“当前进度”和“完成记录”。重建完成后删除本文件，不把它转化为长期架构文档。

## 当前进度

### 当前阶段

**清理阶段已完成。现在进入最终架构构思阶段；尚未开始 installer 重构。**

已建立仓库外参考快照，并将当前仓库中的旧文档、测试、demo、probe 和测试说明全部迁出。当前仓库暂时只保留功能代码、运行时配置、构建/安装逻辑、依赖配置和本文件。尚未修改功能源码，尚未改变功能目录结构，也尚未开始 Arch Linux 适配。

### 阶段状态

| 阶段                                | 状态   | 说明                                                              |
| ----------------------------------- | ------ | ----------------------------------------------------------------- |
| 0. 建立重建计划与边界               | 完成   | 本文件已建立并作为唯一过程文档                                    |
| 1. 建立外部历史参考快照             | 完成   | 快照位于仓库外 `/tmp/dotkit-rebuild-reference/`                   |
| 2. 迁出全部旧文档和测试             | 完成   | 已清理测试入口、依赖、preset、include，并迁出旧 CI 和启动测量脚本 |
| 3. 盘点功能代码结构                 | 完成   | 结构级方案已确认；细节质量审查后续进行                            |
| 4. 建立 macOS / Arch Linux 平台边界 | 进行中 | 清理已完成，正在依据真实源码确定最终 installer 结构               |
| 5. 重建功能目录和模块 ownership     | 未开始 | 移动、合并或删除功能源码                                          |
| 6. 整理主要功能流程                 | 未开始 | 安装、启动、UI、Git 等生命周期                                    |
| 7. 功能代码质量审查                 | 未开始 | 删除死代码，收拢状态和边界                                        |
| 8. 重新编写正式文档                 | 未开始 | 只依据重建后的源码和确定行为                                      |
| 9. 重新编写少量长期测试             | 未开始 | 只覆盖主要流程、平台 contract 和高风险回归                        |
| 10. 恢复检查和 CI                   | 未开始 | 使用新的文档和测试规范                                            |

### 完成记录

#### 2026-06-16

- 完成重建方向讨论，确定采用彻底断舍离，而不是在旧文档和旧测试上渐进维护。
- 确定旧文档和旧测试迁移到仓库外，仅作为历史参考，不作为新结构、接口、文档或测试的依据。
- 确定重建期间只保留一份过程计划文档，完成后删除。
- 创建本文件并移动到 `docs/rebuild-plan.md`。
- 在 `/tmp/dotkit-rebuild-reference/` 创建清理前参考快照，记录 Git HEAD、分支、工作树状态、未提交 diff、文件清单和源码快照。
- 将根级 README、AGENTS、CONTRIBUTING、旧 `docs/`、package README、Neovim package 文档，以及全部 package/configuration/workspace 测试、demo、probe 和测试说明迁移到仓库外参考目录。
- 验证当前仓库的文档/测试扫描结果只剩 `docs/rebuild-plan.md`。
- 未修改功能源码，未运行 `pnpm slink`，未修改用户环境。

#### 下一步

- 盘点只剩下的功能代码、运行时配置、构建/安装逻辑和平台假设。
- 输出外部功能模块地图，不把它写入当前仓库。
- 从 `profiles` / `dotfiles` 安装流程开始识别 macOS 与 Arch Linux 的真实平台 seam。

#### 阶段三初步盘点：2026-06-16

当前功能代码已按运行边界完成第一轮只读盘点，尚未移动或修改源码。

初步识别出四个功能区域：

```text
packages/shared   平台无关的错误、环境、输出、脚本和 symbolic-link 基础能力
packages/task     workspace 任务执行、上下文、事件、渲染和预设
packages/palette  Palette 输入、构建、catalog、主题状态和安装
profiles          XDG profile 生成、构建产物和 macOS LaunchAgent 激活
 dotfiles         用户配置资源以及配置 symbolic-link 安装
 nvim-pack        Neovim 本地插件实现：pack、popup、picker、terminal
```

当前发现的真实平台 seam：

- `profiles/src/xdg.ts`、`profiles/profiles.config.ts` 和 `packages/shared/src/link` 是可以平台无关化的 profile/link 基础能力；
- `profiles/src/macos/launch-agent.ts` 和 `profiles/scripts/slink.ts` 将 Darwin 专属的 plist、`launchctl`、`~/Library/LaunchAgents` 与通用 profile/link 流程混在一起；
- `dotfiles/scripts/slink.config.ts` 在模块加载时直接读取 `XDG_CONFIG_HOME`，使 link 计划依赖外部 profile 已经被激活；
- 当前没有 Linux adapter，`profiles/scripts/slink.ts` 会对非 Darwin 直接失败；
- `dotfiles/configs/wezterm/font.lua` 已经存在运行时平台分支，但它属于 WezTerm 配置内的局部适配，不应与 profile 激活逻辑混合。

当前发现的功能结构问题：

- `profiles` 同时承担 profile 数据、构建 LaunchAgent 产物和安装/重启服务；需要拆成平台无关的 planning/build 与 Darwin activation；
- `dotfiles/scripts/slink.ts` 目前只执行静态 link 配置，配置文件在加载时计算 home 和 XDG 路径，后续需要改为显式环境/平台输入；
- `profiles/scripts/build.ts` 无条件生成 LaunchAgent 和 `launchctl` helper，Linux 构建不能复用；
- `packages/shared/src/environment` 目前只有 required lookup，没有默认 XDG environment 的解析层；
- workspace manifest 中每个 package 都仍然暴露旧的 `test` script。它们暂时不修改，等功能结构稳定后按新测试规范重建；
- `packages/palette/dist`、`profiles/dist` 属于构建产物观察对象，不在本阶段隐式刷新或修改 Palette 输入。

本轮盘点没有运行测试，没有运行 `pnpm slink`，没有修改用户环境，也没有修改功能源码。

#### 源码盘点与状态纠正：2026-10-14

- 本轮实际系统日期为 2026-10-14；此前日志日期保留为历史记录，不作为新记录日期。实际 HEAD 为 `3f16f7e3fbb75d21db32421a0df26f958a1d257c`；开始迁移时仅计划文档未跟踪，此前关于三个独立未提交文件的描述已过时。
- 已盘点 Profiles、Dotfiles 链接入口、Shared 基础能力及 Shell 环境消费链，补查 Palette 安装入口；外部结果为 `/tmp/dotkit-functional-map.md`。
- 确认 Shared 没有反向依赖 Profiles/Dotfiles，也不是 Task 的包装层。symbolic-link 模块具有真实复用价值，暂不拆分。
- 确认跨平台缺口不只是 launchctl：zshenv 要求预先存在全部 XDG 变量，tools.zsh 依赖 Homebrew 的 zinit/NVM 路径，ls 别名带 BSD 假设，Palette 安装也要求 XDG 环境。
- 平台设计需要区分 host 与 target；跨平台生成/预览不能自动授权在宿主机执行另一平台的激活。Linux 不能仅靠空 adapter 宣称支持。
- 发现旧 test scripts、Vitest 依赖、Task preset、tsconfig test include、CI 和 `dotfiles/configs/nvim/scripts/startup.ts` 仍存在。此前“阶段二完成”结论过早，现改回进行中。不能因文件名扫描未命中就认为全部迁出。
- 已识别失败边界：Shared 只恢复单个链接，不是整批事务；Profiles build 删除旧 dist 后再 rename，不是完整回滚发布。本轮只记录，未修改行为。
- 本轮仅做源码读取与引用检索，未运行 build/check/test/slink，未修改功能代码、锁文件或用户环境。
- 下一步：收尾阶段二残余，再完成 Task、Palette 核心和 Neovim 功能盘点，形成整体目录方案；不提前实现 Linux 或移动源码。

#### 整体结构方案：2026-10-14

- 已补查 Task 执行/状态/呈现、Palette 输入/构建/持久化、Neovim 启动和本地插件入口/状态所有者；方案保存在仓库外 `/tmp/dotkit-rebuild-proposal.md`，安装地图仍为 `/tmp/dotkit-functional-map.md`。
- Task workspace 实际通过 Promise.all 并行执行 package scripts，不是依赖排序器。根安装流程不应以 Profiles 先执行作为隐含前提。
- 建议保留顶层目录和四个本地插件边界，优先整理环境解析、安装顺序、Darwin 激活和 Shell 平台差异。Neovim 只做有明确归属收益的局部调整，不重写已有交互。
- 已记录待验证风险：Palette ActiveThemeStore 固定临时文件名可能竞争、Profiles 发布缺少完整回滚；这些是源码观察，不是本轮已复现的故障。
- 待确认：保守目录方案；XDG 是否允许 home 外绝对覆盖；Arch 首版是否以 Shell/CLI/Neovim 为范围；清理依赖时是否允许同步锁文件。
- 本轮用户要求先盘点与出方案，因此没有继续删除 CI、修改 manifests 或清理依赖；迁移残余列为确认后的第一批。
- 本轮修改仅为本计划和外部 Markdown。未运行 build/check/test/slink，未启动真实 Neovim，未修改功能源码、锁文件、Palette 输入或用户环境。
- 下一步：用户确认方案后分批实施；全量细节审计、平台运行验证及人工 UI 验收不能由本次结构盘点替代。

#### 清理收尾与方案确认：2026-10-14

- 用户确认 A（保留主要目录）、B（XDG 覆盖政策）、C（Arch 首版 Shell/CLI 范围）。本轮不实现桌面会话环境发布，也不要求用户提供桌面栈。
- 锁文件永远由包管理器生成：本轮只编辑六个 package.json 移除 test scripts/Vitest 声明，再运行 `pnpm install --lockfile-only --offline --ignore-scripts` 自动同步。未手工编辑锁文件，未更新插件锁或 Palette pin。
- 清理五个 tsconfig 的 test include 和 Task Vitest preset，保留静态检查能力。
- 将旧 CI 和 Neovim 启动测量脚本迁出至 `/tmp/dotkit-rebuild-reference/cleanup-ElJl36xd/`，未删除功能 spec 模块或功能源码中的测试相关注释。
- 初次 `pnpm check` 被计划文档格式阻断；独立 workspace check 的 Palette tsconfig 格式也失败，其余输出包含通过的 Lua 检查。仅格式化本轮涉及文件后重跑，不做全仓格式化。
- 定向格式化后，完整 `pnpm check` 与 `git diff --check` 均通过。
- 未运行测试（旧入口已移除）、build、slink 或任何环境激活；仅安装锁同步和静态检查。后续从重建后的功能补写少量测试与 CI。

### 安装协议与实施计划（2026-10-14，设计稿）

本节取代此前直接从双平台 XDG helper 开始实施的顺序。首版只落实 macOS 与 Arch；不实现 Windows、Debian、自动平台检测或 TUI，不把平台选择作为核心职责。下述协议是首版目标，尚未实现。

#### 基础环境协议确认：2026-10-14

用户确认：所有未来支持的平台（包括 Windows）都必须由 Dotkit 定义并提供完整的 `XDG_*` 环境变量，不建立 `DOTKIT_*` 平行命名空间。

```text
XDG_CONFIG_HOME
XDG_DATA_HOME
XDG_CACHE_HOME
XDG_STATE_HOME
```

这四个变量是跨平台长期 contract：始终解析为非空绝对路径；用户显式绝对路径优先；未提供时使用目标平台的默认路径；非空相对路径拒绝；允许路径位于 home 之外。Windows 使用 Windows 路径格式，但仍发布相同变量名。Node 安装核心内部使用解析后的环境对象，不能在模块加载时从 `process.env` 隐式读取。

`home` 和 `binDirectory` 是解析上下文/派生路径，不新增第五个 XDG 变量。`HOME`、`ZDOTDIR`、`HOMEBREW_PREFIX`、`NVM_DIR` 等仍属于平台或组件专属变量；`PATH` 保留运行时继承值，不固化完整快照。由 Dotkit 管理的跨平台组件统一消费上述 XDG contract；不理解 XDG 的原生应用由其组件适配，但不能因此改变基础 contract。

这一决定适用于后续 Windows、Debian 等平台，不是 macOS/Arch 阶段性兼容策略。

#### 协议一：显式请求

核心输入为 target、使用方案、home、环境覆盖和执行授权。target 采用 `macos` / `arch`；它不同于 Node 的 `darwin` / `linux`，由入口显式提供。核心不读取参数、不选择默认目标、不自动猜测发行版，只验证目标定义和请求是否合法。未来 CLI/TUI 都调用同一核心。

宿主执行是调用方的责任；未验证平台对应关系时不得把跨目标预览直接转为执行。当前不实现跨系统部署；仅支持本机执行选定目标的计划。

#### 协议二：平台适配与使用方案分离

- 平台定义拥有路径规则、供应器配置、软件映射、部署/环境发布能力。
- 使用方案拥有该平台的组件选择和用户选项；平台支持某组件不代表默认安装它。
- macOS 从现有配置提取选择；Arch 的最终组件清单由用户确定，设计实例不是默认授权。
- 首版优先评估 brew 与 pacman；逐项确认来源和版本，不自动引入 Linux Homebrew 或 AUR helper。
- 共用能力直接复用，不要求每个平台写一套空包装脚本。

#### 协议三：组件拥有功能

组件声明稳定 ID、必需组件依赖、软件需求、构建/部署描述和验证要求。组件不调用包管理器、不提权、不自行检测平台。软件需求用语义 ID 表达，由平台映射到供应器的包；缺映射明确失败，不静默跳过。

只展开所选组件的依赖闭包；拒绝未知依赖和循环；合并共同软件需求，遇到来源/版本约束冲突明确报错。首版使用少量具名选项，不建立任意配置继承或通用条件表达式语言。

Zsh、Neovim、Palette、WezTerm 和 Starship 是待核实的组件边界，不按每个配置文件创建组件。共享工具配置归独立组件，Shell 内的接入代码仍由 Shell 组件所有。未选中且不在依赖闭包中的组件没有安装副作用。

#### 协议四：声明、探测、计划、执行分离

```text
显式请求 + 平台/组件声明
  → 解析依赖与目标路径
  → 只读探测软件、权限、文件冲突
  → 生成计划
  → 授权检查
  → 顺序执行准备/构建/部署/激活
  → 验证与报告
```

声明解析为纯计算；探测允许只读本机命令和文件检查，不更新包索引、不联网安装、不创建目录。供应器不存在时仍能列出待准备项；无法确认的状态标为 unknown/blocked，不伪装为已安装。

计划包含稳定 step ID、所属组件、依赖步骤、操作类型、目标、理由、当前状态和权限/网络要求。操作类型首版限制为软件准备、软件安装、构建、配置部署、环境激活、验证；纯数据计划引用具名实现，不携带任意 shell 字符串执行权限。

预览允许产物尚不存在：展示构建前置步骤，不调用现有 linker 检查尚未构建的源文件。真正部署前重新校验产物和目标冲突。执行阶段重新检查关键前置条件，避免把旧预览当成不可变事实；重试重新生成当前计划，不先建设持久化恢复引擎。

#### 协议五：适配实现和脚本边界

供应器暴露只读探测、准备/安装执行、安装后验证；平台部署/激活实现同样接受显式 context 和具名操作输入。实现返回结构化结果，不直接拥有 CLI 退出和渲染。

统一执行器负责启动进程、参数数组、cwd、显式环境、输出与退出状态；禁止拼接用户输入到 shell 命令。确需脚本时由适配器包装：参数/环境输入明确、成功返回 0、失败非 0、无静默吞错、不可隐式重启或提权。不会为了新平台自动发现并运行任意目录内脚本。

授权逐步核对用户写入、管理员权限、网络与服务激活；选择目标或预览不等于授权所有操作。暂不提供通用 hook 系统。

#### 协议六：状态、安全与一致性

- 步骤结果明确区分 satisfied、changed、failed、blocked；可选组件的跳过必须来自显式选择，不用于掩盖安装失败。
- 已满足步骤可跳过；组件使用本身允许发生的状态变化不等同于安装器可随意覆盖用户数据。
- 链接部署遇到普通文件占用报冲突；更新链接沿用明确 ownership 策略。首版不自动退化成复制。
- 不承诺全局回滚，失败即停并报告已完成和未执行步骤；局部回滚仅由确实支持该行为的步骤提供。
- XDG 延续已确认政策：绝对覆盖优先，缺失/空值使用 home 默认，非空相对路径报错，允许 home 外绝对路径。
- Shell 环境与 GUI 会话发布不同；Arch 首版不处理桌面会话发布、不创建系统服务。macOS 的既有 LaunchAgent 行为由显式激活步骤拥有。
- 软件准备不偷偷升级全部已安装软件；Arch 的仓库同步/系统升级策略必须明确，不能采用不安全的局部升级组合。
- 依赖变更先编辑描述文件，再由包管理器生成锁文件；不手改锁，不刷新 Palette 既有输入或插件锁。

#### 协议七：bootstrap 前置边界

Node/pnpm 是 TypeScript 安装器的执行前提，不能由尚不能运行的安装器负责自举。第一轮计划开发使用现有工具链；完整新机流程需要极薄的 POSIX bootstrap，只检查/准备明确版本范围的运行时后移交安装核心。Homebrew 缺失应展示准备动作并单独授权，不能在探测中运行远程安装器。Bootstrap 不复制组件逻辑。

#### 实施批次与验收门槛

1. **需求清单**：提取现有配置的软件、文件和激活依赖；列出 macOS/Arch 来源与版本要求，明确 Arch 选择，识别不支持/待决项。
2. **只读计划纵向切片**：先用 Palette + Neovim 展开依赖、构建产物与配置部署，再纳入 Zsh/Starship/WezTerm。平台组件未选中时不产生无关步骤。无需软件已安装也能形成有 blocked 原因的计划。
3. **隔离执行**：临时 home、假供应器与假激活命令验证顺序、权限、重复执行、冲突和失败报告；外部临时验证脚本不写回旧测试。
4. **macOS 接入**：复用现有构建和链接能力，把 Profiles 激活从公共编排移到 Darwin 适配；真实安装须另行授权。
5. **Arch 接入**：确认 pacman 来源/升级政策、Shell 工具路径和 GNU/BSD 差异；真实 Arch 验证后才能声明支持。
6. **协议收敛**：记录新增平台需补的声明、映射和实际适配；确认无需修改核心流程才能新增平台，避免提前承诺 Windows 已兼容。
7. **维护材料重建**：从稳定实现补新的文档和少量 contract/主流程测试，恢复 CI。

安装流程需要唯一所有者（候选 `packages/installer`），Task 保持工程任务角色，Shared 保持底层能力。实际文件结构随只读纵向切片落实，不先创建一堆无实现接口。现有 root slink 最终接入统一编排，不能与新入口长期各自编排同一安装生命周期。

本轮仅补充计划，未修改功能源码或依赖，也未执行构建、安装、测试或系统激活。下一步是需求清单和只读计划接口，不立即操作用户机器。

### 系统安装抽象收敛（2026-10-14）

根据用户进一步限定，本阶段仅处理环境变量、所选软件、软件路径及配置链接；不审查或改写 Neovim/WezTerm 内部跨平台行为。此前组件协议作为方向参考，不提前实现通用组件框架或完整 DAG。平台由外部明确传入。

重新读取现有 slink、Profiles 和 Zsh 配置后，建议首版保留三个概念：

1. **使用方案**：显式 target、软件选择、配置选择。软件和配置分别声明，例如已有系统 Neovim 可以只部署配置；配置所需命令可检查并报告缺失，不自动扩大软件安装授权。
2. **平台实现**：软件 ID 到来源的映射、探测/安装及安装位置解析、必要的环境发布。macOS/Arch 共用 XDG 和 Node 路径操作，不重复维护相同链接表。
3. **解析后的安装计划**：软件需求及来源、环境变量和 PATH 项、软件初始化资源路径、配置链接、仓库产物构建前置项与阻塞原因。执行与只读解析分开。

源码确认的安装需求：

- Dotfiles 当前一次安装全部 Zsh、Starship、WezTerm、Neovim 配置，需要拆成具名配置集合，而不是按平台复制资源。
- Zsh tools 直接调用 zoxide/starship/fzf，fzf 预览调用 bat；NVM 和 Zinit 通过 Homebrew 前缀下的脚本加载，不能只探测同名可执行命令。
- zshenv 只尝试两个 macOS brew 路径；软件位置应优先使用明确路径或供应器探测所得前缀，不把跨平台安装路径直接写进 Shell。
- Profiles 生成四个 XDG 默认值，Dotfiles 和 Palette 又依赖调用进程已有的环境，需统一解析为显式输入。
- Palette 是仓库构建软件，不应伪装成 brew/pacman 包；其命令入口与 Zsh completion 应分别部署，未选 Zsh 不默认安装补全。
- 用户 PATH 应只保存有意添加的目录项，不冻结安装时整个进程 PATH；运行时继续保留继承 PATH。

建议先用本地 TypeScript 数据/函数表达使用方案、共同链接规则和两套平台实现，暂不创建插件注册框架、通用路径 DSL 或一软件一类。软件路径需区分 executable、prefix、初始化脚本/资源，未知值在预览标为待探测，软件安装后再解析并验证。

软件来源仍需核实：Arch 的 NVM/Zinit 来源以及 Node/pnpm 工具链政策不能从 macOS Homebrew 路径推断；此轮没有查验远端包仓库，不把候选包名视为已确认。Node/pnpm 是当前运行安装代码的前置条件，与未来新机 bootstrap 单独处理。

本轮仅源码阅读、引用检索及本计划更新；未修改功能代码、未运行安装或运行时测试。下一步先实现显式环境解析和具名配置链接计划，再接软件供应器；不是先调整应用配置内部逻辑。

#### 旧部署入口清理：2026-10-14

- 用户同意将 `build`、底层链接和 `install` 分开：build 只生成产物，链接是被 install 调用的底层动作，install 负责选择和编排。
- 删除根 `slink` workspace 编排，以及 Profiles、Dotfiles、Palette package manifest 中的 `slink` scripts。
- 删除旧 CLI wrapper：`profiles/scripts/slink.ts`、`dotfiles/scripts/slink.ts`、`packages/palette/scripts/slink.ts`。这些入口曾被 `task workspace slink` 并行执行，无法表达 Profiles、Dotfiles、Palette 之间的安装顺序。
- 移除 Task CLI help 中已失效的 `task workspace slink --only-preview` 示例。
- 暂时保留各 package 的 `build`：`pnpm build` 仍是仓库构建编排，不负责用户部署；Profiles/Palette 的 build 实现下一阶段再迁移或被平台 install 按需调用。
- 本轮未删除 `packages/shared/src/link` 底层能力，未执行任何链接、LaunchAgent、软件安装或构建；未修改用户环境。
- 删除旧的 `dotfiles/scripts/slink.config.ts` 全量静态链接配置；它只服务于已删除的 Dotfiles slink 入口，不能作为最终配置声明保留。
- 删除旧的 `profiles/scripts/build.ts` 和 Profiles package 的 `build` script；该脚本无条件生成 macOS LaunchAgent/helper，属于未来平台 installer 的平台部署能力，不应继续作为通用 workspace build。
- 清理后仅保留 Palette 的仓库构建/输入准备：`packages/palette/scripts/ensure.ts` 与 `packages/palette/scripts/build.ts`。根 `ensure`/`build` 暂时只是对这些现存构建任务的 workspace 编排，不承担用户部署。
- 本轮仍未创建 installer、未恢复任何 slink、未执行 build/link/launchctl 或软件安装。因删除 Dotfiles 旧 TypeScript slink 入口导致其 tsconfig 无输入，已同步移除 Dotfiles package 的 typecheck 子任务；Lua/配置静态检查仍保留。
- 完成部署清理审计：仓库没有 `slink`、`SLINK_CONFIG`、package 级部署脚本或旧 workspace slink 引用。根 `ensure`/`build` 仅编排 Palette 的输入准备和构建，不修改用户环境；`packages/shared/src/environment` 仍被 Palette 运行时使用，不能作为旧部署残留删除；`packages/shared/src/link` 和 macOS LaunchAgent 声明是待新 installer 调用的底层能力。
- 清理阶段至此结束。接下来不再删除或创建过渡模块，先在本计划中完成最终 installer 的职责、数据结构、执行顺序和目录 ownership 设计，再一次性开始重构。

#### 最终架构构思：2026-10-14

清理完成后，最终结构确定为“平台 installer 是唯一安装声明与编排入口；功能包提供构建/运行能力；shared 只提供通用执行能力”。不再保留 package 级 slink，也不为软件选择、来源和链接建立彼此分离的配置表。

最终目录方向：

```text
profiles/
├── macos/
│   └── install.ts       # macOS 完整环境、软件、构建、链接、激活声明与入口
├── arch/
│   └── install.ts       # Arch 完整环境、软件、构建、链接声明与入口
└── src/
    ├── environment.ts   # 所有平台共用的 XDG_* 解析/校验
    ├── installation.ts  # 最小安装条目、计划和执行能力
    └── macos/           # LaunchAgent 声明与 macOS 激活实现
```

`install.ts` 是平台边界，不是另一个只调用旧脚本的 wrapper。每个平台文件直接声明：

```text
基础 XDG_* 环境值及发布方式
软件条目
软件安装方式
软件构建方式（可选）
该软件产生的全部 source → target links
平台专属激活/验证步骤
```

一个软件条目即表示该平台处理它；不再额外声明 `enabled`、software selection、provider mapping 或 `configLinks`/`executableLinks` 分类。条目中的 `links` 只表示符号链接动作，用途由所属条目决定：

```ts
{
  name: "palette",
  build: buildPalette,
  links: [
    { source: paletteExecutable, target: binDirectory + "/palette" },
    { source: zshCompletion, target: xdgDataHome + "/zsh/site-functions/_palette" },
  ],
}
```

安装流程固定为：

```text
构造平台 installer 声明
→ 解析并校验四个 XDG_* 变量
→ 检查/执行声明的软件安装方式
→ 执行声明的构建方式
→ 重新确认构建产物和全部 link source
→ 预览/检查 link target 冲突
→ 执行全部 links
→ 按平台发布四个 XDG_* 变量
→ 执行平台专属激活
→ 验证软件、产物、链接和环境
```

声明阶段只做路径计算和只读检查；执行阶段才允许网络、软件包管理器、构建、文件系统修改、环境发布和服务激活。`preview` 必须在执行前停止，不能通过导入或计划生成触发副作用。

职责归属固定为：

```text
profiles/<platform>/install.ts
  平台选择、软件条目、安装顺序、links、激活和验证

packages/palette
  Palette 的源码、构建实现和运行时；installer 调用其 build 能力

dotfiles/configs
  配置源文件；installer 直接声明它们的 source → target

packages/shared/src/link
  通用符号链接检查与执行，不拥有安装入口
profiles/src/macos
  plist/helper 生成和 launchctl 激活，不进入 Arch 或 shared 流程
```

不再保留通用软件 provider 注册框架。`macos/install.ts` 直接使用 Homebrew 的结构化命令/参数，`arch/install.ts` 直接使用 pacman 或已确认的其他来源；来源未确认的软件不能写入声明。Node 的 `path`、`fs` 和 `os` 负责路径及文件机制，不创建跨平台 path abstraction。

XDG contract 固定为所有平台都必须提供：

```text
XDG_CONFIG_HOME
XDG_DATA_HOME
XDG_CACHE_HOME
XDG_STATE_HOME
```

解析结果只能由 installer 上下文向下传递。任何功能模块不得在安装路径计算中重新读取 `process.env`、`homedir()` 或自行拼接默认目录。Windows 未来也必须发布同名变量，只使用 Windows 格式的绝对路径。

`build` 保持仓库构建命令，不是安装入口；平台 installer 可以调用 Palette 等功能包的构建函数。`shared/link` 不是 slink 命令，根目录不恢复 slink。是否保留 package 的独立 build/ensure script，必须与最终 installer 的构建 ownership 同时调整，不能让 workspace 脚本再次变成部署编排。

本次构思尚未修改功能源码，未创建 installer，未运行构建、链接、激活或软件安装。下一步进入最终重构实现：先将通用 XDG/安装声明能力落到最终 `profiles/src`，再把 macOS 的真实配置、软件和链接一次性收拢到 `profiles/macos/install.ts`，同时删除不再有 owner 的旧 package 脚本；随后按相同 contract 建立 Arch 声明。

#### 最终重构改动计划：2026-10-14

以下是执行计划，不引入临时 installer、兼容入口或“第一版”接口。每一步完成后都必须通过静态检查，并且不得运行真实软件安装、用户目录链接、LaunchAgent 激活或插件同步。

##### 1. 建立最终公共安装模型

在 `profiles/src/` 建立少量最终模块：

```text
profiles/src/environment.ts
profiles/src/installation.ts
profiles/src/plan.ts
```

职责固定为：

- `environment.ts`：接收显式 `home`、环境变量和平台默认值，解析并验证四个 `XDG_*`，同时提供派生的用户 bin 目录；不在 import 时读取进程环境。
- `installation.ts`：定义软件条目、安装动作、构建动作、`links`、环境发布、激活和验证动作所需的最小结构；不建立 provider 注册表。
- `plan.ts`：把平台声明转成有顺序的只读步骤，执行前完成 source、target、软件状态和构建前置检查；preview 不产生副作用。

保留 Node 原生 `path/fs/os`，不增加通用路径 DSL。把当前 `profiles/src/xdg.ts` 的最终实现迁移或合并到上述 owner，避免同时保留两套 XDG API。

##### 2. 明确功能包的可调用边界

- `packages/shared/src/link` 保留为唯一符号链接执行能力；计划层使用它，shared 不知道平台和软件。
- `packages/palette` 保留 Palette 的构建和运行时实现；将构建实现导出为可被 installer 调用的函数，CLI script 只作为开发构建入口，不能成为安装编排入口。
- `dotfiles/configs` 保持配置资源 owner；将配置源路径以最终可调用声明导出，接受 installer 提供的 `home`/XDG 上下文和明确软件条目，不读取 `process.env`/`homedir()`。
- `profiles/src/macos/launch-agent.ts` 只保留 plist/helper 生成；将 macOS 专属的产物生成、LaunchAgent 目标路径和 `launchctl` 激活收拢到 macOS installer 使用的模块，不让 Arch 或 shared 引用。

若某个旧 package script 没有独立 owner，删除它；不为了保留旧命令而反向污染最终接口。

##### 3. 实现 macOS 最终 installer

创建 `profiles/macos/install.ts`，由它直接声明真实的 macOS 安装内容：

- 解析并发布四个 `XDG_*`；
- 声明经确认的 Homebrew 软件及其结构化命令参数；
- 声明 Zsh、Starship、WezTerm、Neovim、Palette 的实际配置关系；
- 声明 Palette 构建及命令/completion links；
- 声明 macOS XDG helper/plist 产物和 LaunchAgent 激活；
- 生成 preview/plan，并按依赖顺序执行；
- 执行后验证命令、产物、链接和环境发布结果。

平台选择、软件声明、链接目标和执行顺序都在这个 installer 的最终 owner 内，不再由根 workspace 并行拼接。

##### 4. 实现 Arch 最终 installer

创建 `profiles/arch/install.ts`，复用同一 XDG、安装条目、计划和链接模型，但独立声明 Arch 的真实软件安装方式与环境发布方式：

- 只写已经确认的 pacman/其他来源和包名；
- 不导入 LaunchAgent、`launchctl`、Homebrew 路径或 macOS plist；
- 按 Arch 的实际 shell/CLI 需求发布四个 `XDG_*`；
- 未确认来源的软件不得假装已支持，必须在计划中阻塞并说明原因；
- 不加入桌面会话环境发布和系统服务，除非另行明确决定。

##### 5. 收拢根命令语义

最终根命令只保留清晰的工程命令和显式平台安装入口：

```text
check / fix       工程静态检查和修复
build             纯构建，不修改用户环境
deploy            接收明确平台并调用对应 profiles/<platform>/install.ts
```

外部部署命令统一为 `pnpm run deploy --platform macos` 或 `pnpm run deploy --platform arch`。不使用 `install`（依赖安装命令及生命周期脚本），也不使用 `setup`（pnpm 自带命令）。不通过 preinstall/postinstall/prepare 等生命周期自动触发部署。内部平台文件仍命名为 `install.ts`；待实现入口后再添加根 `deploy` script，不添加指向不存在文件的命令。

根 `build` 不再通过 workspace 自动执行部署；需要被 installer 使用的构建能力通过函数调用，未选软件不构建。根 `ensure` 只有在仍被最终构建输入需要时保留，否则删除并由 Palette build 明确处理其输入前置。

##### 6. 删除旧 owner 和补齐长期验证

安装器与公共模型稳定后，删除所有无 owner 的旧脚本、重复 XDG API 和隐式环境读取。重新补回只覆盖长期 contract 的测试：

- 四个 XDG 在 macOS、Arch 以及未来 Windows 的解析规则；
- 相对路径、空值、home 外绝对路径和 Windows 路径；
- 软件条目到 build/link/activation 顺序；
- preview 无副作用；
- 普通占用目标、重复 target 和 source 缺失；
- macOS 与 Arch 不互相加载平台行为。

测试恢复前不运行真实安装；需要真实 macOS/Arch 软件、LaunchAgent 和交互 Shell 的部分单独标记为未验证。

##### 实施检查点

```text
A  公共模型和 XDG contract 完成，未有平台 installer
B  功能包边界完成，旧 package 部署脚本无 owner 即删除
C  macOS installer 完成并能生成只读计划
D  Arch installer 完成并能生成只读计划
E  根命令语义完成，build/deploy/pnpm install 不再混淆
F  长期测试和最终文档恢复，重建计划删除
```

每个检查点都记录实际修改文件、运行的检查及未测试的交互行为；禁止把真实安装作为静态开发检查的一部分。

### 环境解析实施记录

- 已实现 `profiles/src/environment.ts`：调用方显式传入 home、variables、四个 XDG defaults、binDirectory 和目标路径语法。模块不读取或发布 process.env，不进行文件系统操作。
- 使用 Node posix/win32 校验，拒绝非绝对路径、NUL 以及 Windows 当前驱动器相对路径；允许 home 外的目录。缺失或空环境值使用声明的默认值；输出为只读快照。
- 删除旧 profiles.config.ts、src/profiles.ts、src/xdg.ts，将 index 与 macOS LaunchAgent 的类型依赖转向唯一 environment 模块。平台默认目录政策由后续平台声明负责，不在解析器中猜测 Windows 默认目录。
- 已运行 POSIX/Windows 路径语法的独立断言：默认值、空值、覆盖、home 外目录、非法路径、home/bin 校验、冻结结果及 process.env 不变均通过。这不是 Windows 原生环境发布验证。
- 首次 pnpm check 因此前计划文档的格式问题失败；对该文档定向格式化后重跑。未运行 build、部署、链接、launchctl 或软件安装；尚未创建 installer。

### 安装声明实施记录

- 新增 `profiles/src/installation.ts`，只定义类型，不执行动作：平台持有 environment 和 software；每个软件条目集中持有 name/install/build/links，不创建独立选择表、来源表或 provider 注册框架。
- install 使用 executable/args/cwd/显式子进程环境，禁止任意 shell 字符串；只读 inspect 返回 installed/missing/blocked。构建引用功能包的异步函数。安装和构建分别声明网络及提权需求，不允许执行器隐式 sudo。
- links 复用 shared 的 Link 类型；构建产物未生成不代表链接永久无效，后续计划和执行检查必须区分构建前置与真正缺失源。
- 当前类型仅覆盖环境和软件条目。环境发布、激活和软件路径重新探测需依据平台实际实现接入，不能把这些类型声明视为已有执行、权限控制或完整平台支持。
- 未创建平台 installer 或执行器，未运行软件探测、构建、安装、链接或服务激活。

### macOS 声明实施记录

- 新增 `profiles/macos/install.ts`，导出无部署副作用的 `defineMacosInstallation`。home、variables、brew 可执行路径为显式输入；统一环境、软件安装动作和 links 集中在平台声明。
- 声明 Zsh、Starship、Neovim、WezTerm、fzf、bat、zoxide、NVM、Zinit、Palette。Homebrew 使用结构化命令，状态检查只读取本地 formula/cask 列表；供应器错误报告 blocked，不能假装软件缺失。包名是待本机/来源验证的安装声明，不代表已验证远端可用性。
- Palette 的构建动作延迟导入现有 ensure/build；只有执行动作才可能下载缺失的固定 revision 输入，不刷新已有输入。Zsh 的默认 Shell 切换、插件下载以及 Node 版本安装均没有自动加入。
- 此文件尚未提供完整部署执行：XDG 发布、LaunchAgent 产物/激活、NVM/Zinit 初始化资源路径检查以及完整计划检查仍待接入。不能将软件声明已存在视作 macOS 安装完成。
- 声明断言通过：使用不存在的 brew 路径仍可纯粹生成声明，XDG 覆盖生效，链接目标无重复，process.env 不变。pnpm check 通过；未调用 inspect、build、安装、链接或 launchctl。Profiles tsconfig 已包含 macos 目录。

### 只读预览入口实施记录

- 清理改动已单独提交为 57ea8f2；新重构代码继续留在工作区供审查。
- 新增 profiles/deploy.ts 和根 deploy script，要求显式 platform、brew 绝对路径及 --only-preview。执行模式直接拒绝，不做任何部署；目前只接 macOS。
- profiles/src/plan.ts 只调用软件只读 inspect 并检查链接：重复软件/目标、非绝对路径、普通文件冲突、缺失源、构建前置、已有链接。输出不包含继承的子进程环境，避免泄漏凭据。
- 输出明确列出尚未完成的环境发布/激活、初始化资源验证和执行器阻塞项；不把当前检查当作完整部署许可。
- 使用不存在的 brew 路径运行预览成功，供应器错误显示 blocked，没有调用真实 Homebrew。首次 check 因 await 循环抑制注释位置失败，修正后 pnpm check 和 git diff --check 通过。未执行真实构建、安装、链接或激活。

### 平台扩展目录与公共入口收敛

- 平台扩展目录固定为 `profiles/platforms/<name>/install.ts`，macOS 声明和 LaunchAgent 均迁入 platforms/macos；公共 src 不保留 macOS 实现。此前记录中的 profiles/macos 路径由此替代。
- deploy 只解析 platform/home/only-preview，发现直属平台目录并按需加载统一 defineInstallation 导出，不包含平台枚举、Darwin 或 brew 参数。平台名称仅匹配发现结果，不直接拼接用户输入路径。
- macOS 自行检查宿主，使用 PATH 中的 brew 或显式 HOMEBREW_BREW_FILE；其阻塞说明由平台返回。执行器尚未实现的通用拒绝仍保留，避免误执行。
- 环境解析删除 pathStyle 和 win32/posix 手动分支，使用 Node 本机 isAbsolute；跨宿主生成其他系统路径不在支持范围。
- 临时目录新增 example/install.ts 的发现/动态加载断言通过，未知路径拒绝；使用不存在的 brew 验证 CLI 预览通过，无真实 Homebrew 调用。首次 check 有排序和函数作用域 lint 失败，修正后 pnpm check、git diff --check 通过。未执行部署。

### 只读计划路径检查

- 计划检查现在区分 `lstat` 目标本身和 `stat` 父目录：不会把系统中存在的符号链接父级误判为普通文件，也会阻塞被普通文件占用的中间路径。
- 临时目录回归覆盖：父目录不存在时 pending，普通文件占用父路径时 blocked，已有正确符号链接时 satisfied。没有调用安装、构建或链接。
- `pnpm check` 和 `git diff --check` 通过。

### macOS 声明模块化

- 移除临时 `Installation.blockers` 字符串数组；它不是可检查的安装状态，也不属于最终模型。预览仅报告真实软件、构建产物和链接检查结果，并标记当前为 `preview-only`。
- 将 macOS 声明拆成三个有明确边界的模块：`install.ts` 负责平台编排和环境，`homebrew.ts` 负责 Homebrew 命令/探测，`software.ts` 负责软件条目和 links。后续增加 macOS 软件主要修改 software 模块，不再扩大入口函数。
- 模块拆分不是按代码块机械切文件：Homebrew 是可复用的供应能力，software 是平台软件清单，install 是唯一平台组装入口。
- `HOMEBREW_BREW_FILE` 仍为显式可选环境输入，默认使用 PATH 中的 `brew`；不存在的路径只在预览探测时返回 blocked。`pnpm check`、预览和 `git diff --check` 均通过，未执行安装、构建、链接或激活。

### 包管理器 API 收敛

- 用 `src/package-managers/homebrew.ts` 的 `brew.install(name, options)` 替代平台侧 HomebrewContext、packageFor、declareSoftware 装配。API 仅声明动作，不执行；支持 formula/cask 和显式 executable。
- install.ts 恢复为集中、展开的软件清单；删除平台 homebrew.ts、software.ts。包管理器封装定位、只读探测、命令及特有环境设置；公共预览提供 cwd 和 HOME/XDG 合并后的环境，不输出完整子进程环境。
- 公共动作契约的 command(context) 仅解析命令，inspect(context) 才执行只读探测；其他包管理器可实现相同契约，不引入注册表。
- 声明断言验证 formula/cask 参数、可执行路径覆盖、非法包名拒绝、无环境修改；不存在的 brew 路径预览通过。pnpm check 和 git diff --check 通过。没有执行真实安装、构建、用户目录链接或服务激活。

### 配置对象导出

- 平台模块不再导出 `defineInstallation` 函数，改为默认导出一个 `PlatformConfiguration` 配置对象。
- 配置对象只声明 target、宿主要求、XDG 默认相对目录、bin 相对目录和软件清单函数；公共 deploy 负责用显式 home/variables 解析最终环境，再调用软件清单函数。
- 平台配置仍需延迟生成 links，因为绝对目标路径依赖运行时 home 和 XDG 覆盖值；这不是平台入口函数，而是配置中的运行时路径解析字段。
- 平台发现只要求默认配置对象；新增平台无需修改 loader 或公共入口。macOS 预览、pnpm check、git diff --check 通过；未执行真实部署。

### 预览状态传播

- 只读计划现在将软件探测状态传播到 links：软件 blocked 时链接 blocked，软件 missing 且源可用时链接显示 `pending-install`；构建条目根据其源链接状态显示 `pending` 或 `satisfied`。
- 预览输出保持声明与检查分离，不执行 build/install/link。使用不存在的 brew 验证后，Homebrew 软件及其链接均被标记为 blocked，Palette 现有产物则独立显示实际链接状态。
- `pnpm check`、macOS preview、`git diff --check` 通过。尚未接入执行器或 LaunchAgent 激活。

### 执行边界第一步

- 新增 `profiles/src/execute.ts`，定义显式授权的执行边界：software 按声明顺序执行 install → build → links；安装/构建需求未授权时 blocked，失败后不继续该软件的后续步骤，结果记录 completed/skipped/blocked/failed。
- 安装通过 `execFile` 执行结构化 command，不使用 shell；链接复用 `@dotkit/shared/link` 的安全实现。执行器不修改 process.env，仅使用声明生成的子进程环境。
- 当前执行器是内部 API，deploy 仍强制 `--only-preview`，因此没有开启真实部署。临时目录已验证无安装动作时的链接执行；pnpm check 和 git diff --check 通过。
- 尚未接入 build 后重新计划、环境文件发布、LaunchAgent、统一验证和 CLI 执行授权；不要直接调用执行器处理真实用户路径。

### 目录边界调整

- 将稳定部署机制移入 `profiles/deployment/`：`environment.ts`、`model.ts`、`plan.ts`、`execute.ts`、`platform-discovery.ts`。将可替换包管理器 API 移入 `profiles/package-managers/`。
- `profiles/platforms/` 保留为平台扩展区，macOS 配置和 LaunchAgent 仍归平台；`profiles/deploy.ts` 只保留 CLI 外壳。删除不再有公共 barrel API 的空 `profiles/src/`。
- 这是目录和 import 重组，不改变预览或执行语义。`pnpm check`、macOS preview、`git diff --check` 均通过；未执行软件安装、构建、链接或激活。

### macOS 环境产物进入计划

- 平台模型新增 `artifacts` 和 `activation`：平台声明生成内容、目标路径、权限模式及结构化激活命令；公共计划只展示元数据，不序列化 artifact 内容，避免把环境值直接泄漏到普通计划输出。
- macOS 配置现在声明 XDG environment helper 和 LaunchAgent plist 目标，并声明 `launchctl bootstrap` 激活动作。来源仍来自现有 `launch-agent.ts`；没有写文件、调用 launchctl 或改变用户环境。
- 预览验证显示两个 artifact 目标和 bootstrap 参数，`pnpm check`、macOS preview、`git diff --check` 通过。artifact 的占用/内容差异检查和执行尚未接入。

### 收回平台专属 artifact/activation 公共模型

- 删除 `DeploymentArtifact`、`PlatformActivation` 及其在 Installation/PlatformConfiguration 中的字段。它们是为 macOS LaunchAgent 临时引入的新概念，不属于所有平台的公共安装模型。
- macOS 的 `launch-agent.ts` 保留为平台内部能力，但暂不接入公共计划；未来如需执行额外平台动作，先在平台配置中设计最小 hook，而不是扩展公共模型。
- `pnpm check`、`git diff --check` 通过。未生成环境文件、未写入用户目录、未调用 launchctl。

### 平台前置 hook 边界

- 按统一主流程增加最小的可选 `PlatformConfiguration.prepare` hook；公共部署器只负责在软件处理前调用它并传入上下文，不理解平台内部动作。
- 平台特殊处理继续归属平台模块：macOS 可由 `launch-agent.ts` 在该 hook 中负责 XDG GUI 环境发布；其他平台无需实现，也不需要共享 LaunchAgent、plist 或环境注入模型。
- 本轮只建立调用边界，macOS 尚未绑定有副作用的 prepare 实现；预览仍不会写文件或调用 launchctl。`pnpm check` 和 `git diff --check` 待验证。

### 平台 before/after hooks 实现

- 公共主流程提供两个最小生命周期入口：`beforeInstall` 和 `afterInstall`。平台可在安装/构建/链接前后处理自己的差异，公共层不理解 LaunchAgent、plist 或 `launchctl`。
- macOS 将 `launch-agent.ts` 接入两个 hook：`prepareXdgEnvironment` 在 preview 中只生成并校验脚本/plist 内容，不写文件；`verifyXdgEnvironment` 暂留为执行后验证边界。真实执行仍由 CLI 拒绝。
- hook 上下文包含解析后的 HOME/XDG、cwd、原始变量和 preview 标记。`pnpm check`、macOS preview、`git diff --check` 通过；没有写用户目录或调用 launchctl。

### 更新规则

每次执行本计划时，必须在本节补充：

```text
日期
完成的阶段或子任务
实际修改的目录和文件类型
验证结果
未完成事项
下一步
```

阶段只有在达到对应“完成条件”后，才能从“进行中”改为“完成”。如果执行过程中改变计划，必须记录原因和新的决策，而不是删除旧记录。

## 1. 重建原则

### 1.1 当前源码是实现事实来源

在本轮重建期间，以下内容不作为当前架构、目录、接口或行为的依据：

- 现有 README、设计文档、TODO、计划、评审和验收记录；
- 现有测试、demo、probe 和临时验证脚本；
- 历史重构过程中的目录命名和文件拆分；
- 旧文档中尚未被当前源码证实的意图。

源码、运行时配置、构建逻辑、安装逻辑和实际依赖关系才是当前实现的依据。

迁出的文档和测试只作为历史参考，用于查找可能遗漏的需求、用户行为或过去发生的问题；不得直接恢复、复制或用来决定新结构。

### 1.2 先整理功能，再恢复维护材料

重建顺序固定为：

```text
保存历史参考
→ 迁出全部旧文档和测试
→ 只审查功能代码
→ 重建功能目录和模块 ownership
→ 建立 macOS / Arch Linux 平台边界
→ 整理主要运行流程
→ 做功能代码质量审查
→ 定义最终文档规范
→ 从源码重新编写文档
→ 从主要流程重新编写少量测试
```

在功能结构稳定以前，不恢复旧文档，不恢复旧测试，不为了让旧测试通过而修改源码。

### 1.3 断舍离不以减少文件数量为唯一目标

保留的每个目录和模块都必须有真实的功能 ownership、调用者、状态或生命周期。删除或合并的依据是：

- 是否有真实运行时调用方；
- 是否拥有不可再随意分散的状态或行为；
- 是否形成有价值的 interface 或 seam；
- 删除后复杂度是否会扩散到多个调用方；
- 是否只是历史重构留下的浅层转发或兼容壳。

目标是提高 locality、module depth 和依赖方向的清晰度，而不是机械地压缩文件数量。

### 1.4 保留现有用户环境安全边界

本轮重建期间：

- 不运行 `pnpm slink`；
- 不修改用户目录中的 symbolic links、LaunchAgent 或插件同步状态；
- 不未经授权刷新 Palette 的固定上游输入；
- 不未经授权修改 lock 文件；
- 保留并隔离开始重建前已有的工作区改动；
- 每次修改前先检查当前工作树，不能覆盖用户已有变更。

---

## 2. 重建前状态

当前分支：`feature/oil-popup`

当前已完成但尚未推送的功能提交保留为重建前历史基线：

```text
7c0670c fix(nvim): wrap long select prompts
7b59bb3 refactor(nvim): derive heirline labels for uri buffers
752ff7c fix(terminal): harden popup and shell lifecycle
858c020 fix(pack): retry failed lazy plugin loads
5197f2c feat(nvim): add git view refresh mappings
```

当前已存在、需要继续隔离且不属于本轮功能重建范围的工作区改动：

```text
dotfiles/configs/nvim/lua/plugins/ai/init.lua
dotfiles/configs/nvim/lua/plugins/editing/init.lua
dotfiles/configs/nvim/nvim-pack-lock.json
```

这些改动不能因为迁移文档和测试而丢失、覆盖或混入无关重构。

---

## 3. 阶段一：建立外部历史参考快照

### 目标

在不把历史材料放回当前仓库的前提下，保存完整、可恢复的参考资料。

### 外部位置

建议使用仓库外目录：

```text
/tmp/dotkit-rebuild-reference/
```

该目录不得加入 Git，也不得被当前测试或构建入口扫描。

### 保存内容

```text
/tmp/dotkit-rebuild-reference/
├── metadata/
│   ├── git-head
│   ├── git-status
│   ├── git-diff.patch
│   └── tracked-tree.txt
├── docs/
├── tests/
├── source-snapshot/
└── MANIFEST.sha256
```

保存：

- 当前 Git HEAD、分支和工作树状态；
- 当前未提交 diff；
- 当前所有文档；
- 当前所有测试、demo、probe 和测试辅助文件；
- 与测试或文档配套的配置；
- 必要时保存清理前完整源码快照，便于恢复单个文件；
- 文件清单和校验信息。

### 完成条件

- 能恢复清理前的文档、测试和工作区改动；
- 快照不在当前项目目录中；
- 快照不会被项目命令自动发现；
- 当前工作树状态已记录。

---

## 4. 阶段二：迁出全部旧文档和测试

### 目标

让当前仓库暂时成为只包含功能代码的工作区。迁出不是删除历史证据；历史证据保存在仓库外快照和 Git 历史中。

当前仓库不建立 `archive/`、`legacy/`、`history/` 等目录，避免旧材料继续污染维护路径。

### 必须迁出的文档

包括但不限于：

```text
README.md
AGENTS.md
CONTRIBUTING.md
docs/**
**/README.md
**/docs/**
*-todo.md
*-plan.md
*-review.md
*-acceptance.md
*-progress.md
*-migration.md
*-refactor.md
```

本文件 `REBUILD-PLAN.md` 是唯一例外，必须保留在仓库根目录，直到重建完成。

### 必须迁出的测试和验证材料

包括但不限于：

```text
dotfiles/test/**
dotfiles/configs/nvim/tests/**
dotfiles/configs/nvim-pack/*/tests/**
packages/*/test/**
profiles/test/**
**/*.spec.ts
**/*.test.ts
**/*test*.lua
**/*test*.ts
**/*probe*.lua
**/*probe*.ts
**/*demo*.lua
**/*demo*.ts
**/*smoke*.lua
**/*smoke*.ts
```

同时迁出：

- 测试专用 fixtures；
- PTY、截图、交互驱动和一次性验证脚本；
- 测试专用 TypeScript/Lua 配置；
- 只服务测试的 runner 配置；
- 只服务测试的 CI 入口；
- 当前测试目录中的 README 和说明文件。

迁出范围以“是否属于开发验证材料”为准，而不是只看文件名。

### 需要同步清理的功能入口

迁出后检查并清理：

- 只供测试使用的导出；
- 只因旧测试存在而保留的兼容接口；
- 只供测试使用的依赖；
- 测试专用环境变量；
- 测试专用脚本和 manifest 命令。

不能为了让清理后的项目暂时通过旧测试而保留这些内容。

### 迁出后的仓库允许保留

```text
运行时源码
运行时配置
构建、打包和安装逻辑
profiles 与平台实现
package manifest
workspace 配置
必要的类型和编译配置
依赖锁定信息
REBUILD-PLAN.md
```

### 完成条件

- 当前仓库中没有旧 README、旧 docs、旧 tests、demo 或 probe；
- 只有本文件作为重建计划文档；
- 功能代码可以在没有旧文档和旧测试的情况下继续被分析和修改；
- 不存在因迁出测试而残留的无主测试入口。

---

## 5. 阶段三：只依据功能代码盘点真实结构

这一阶段不使用迁出的材料设计目录。结果先记录在外部临时资料中，不立即创建新的项目文档。

### 盘点对象

```text
packages/palette
packages/shared
packages/task
profiles
dotfiles/scripts
dotfiles/configs/nvim
dotfiles/configs/nvim-pack/pack.nvim
dotfiles/configs/nvim-pack/popup.nvim
dotfiles/configs/nvim-pack/picker.nvim
dotfiles/configs/nvim-pack/terminal.nvim
```

### 每个模块记录

```text
模块名称
运行时入口
真实调用方
依赖方向
状态所有权
生命周期
外部副作用
平台假设
公开 interface
```

### 必须回答的问题

- 哪些目录是独立的功能 module；
- 哪些文件只是浅层转发；
- 哪些状态跨目录泄漏；
- 哪些配置属于装配层，哪些属于实现层；
- 哪些源码没有真实调用方；
- 哪些平台判断已经泄漏到通用逻辑；
- 哪些构建或安装脚本拥有真正的领域职责；
- 哪些 package 之间的依赖方向反了。

### 重点功能边界

#### Workspace

重新判断 `packages`、`profiles` 和 `dotfiles` 是否是正确的顶层 ownership，以及 `shared`、`task`、Palette 和 profile 生成之间的真实依赖关系。

#### Neovim 配置

区分：

```text
启动和基础配置
第三方插件装配
本地插件实现
Palette 消费
UI 生命周期
开发工具配置
```

不根据旧测试文件数量决定源码目录。

#### 本地 Neovim packages

对 Pack、Popup、Picker、Terminal 分别做 deletion test，确认每个保留的 package 是否拥有足够 depth、明确入口和独立生命周期。

### 完成条件

- 有一份外部功能模块地图；
- 每个顶层目录都有明确的功能解释；
- 已列出需要移动、合并、删除或保留的源码；
- 目录调整建议只来自当前代码的调用关系和 ownership。

---

## 6. 阶段四：建立 macOS / Arch Linux 平台边界

该阶段必须在重新编写正式文档和测试之前完成。

### 首期支持平台

正式支持：

```text
macOS (darwin)
Arch Linux (linux)
```

暂不承诺 Windows，也不自动承担其他发行版的包管理和系统服务差异。

### 平台选择优先级

支持三种方式：

```text
命令行：--platform darwin|linux
环境变量：DOTKIT_PLATFORM=darwin|linux
默认：process.platform
```

优先级：

```text
命令行参数 → DOTKIT_PLATFORM → process.platform
```

非法值必须立即失败，不能静默回退。

### 平台无关核心

应尽可能保持平台无关：

```text
平台选择
环境和 XDG 路径解析
profile 数据结构
symbolic link 计划
preview
报告和错误模型
```

### macOS adapter

只负责：

- LaunchAgent plist；
- `launchctl bootstrap`；
- `launchctl bootout`；
- macOS 特定路径和服务生命周期。

### Linux adapter

第一版负责：

- XDG 默认路径和覆盖；
- symbolic links；
- Neovim、zsh、Starship、WezTerm 等配置安装；
- 不调用 `launchctl`；
- 不自动创建 systemd user service。

只有确认某个常驻服务确实属于 Dotkit 功能后，才另行设计 Linux service adapter。

### 安装和 profile 流程目标

将当前混合流程整理为：

```text
platform selection
→ environment resolution
→ profile planning
→ link planning
→ preview / apply
→ platform activation
```

`--only-preview` 在两个平台都必须无文件系统副作用；平台激活必须与通用 link 操作分离。

### 需要重点重构的现有 seam

当前 `profiles/scripts/slink.ts` 混合了：

```text
参数解析
平台判断
symbolic link
LaunchAgent
命令执行
终端输出
```

必须拆分真实的 platform-neutral core 与 Darwin-specific adapter。当前 `launchctl` 相关实现不得被 Linux 路径加载或执行。

### XDG 规则

首期默认值：

```text
XDG_CONFIG_HOME=$HOME/.config
XDG_DATA_HOME=$HOME/.local/share
XDG_CACHE_HOME=$HOME/.cache
XDG_STATE_HOME=$HOME/.local/state
```

显式环境变量可以覆盖默认值。首次执行 `slink` 不应要求用户已经手动激活某个 profile 才能完成安全预览。

### 完成条件

- macOS 现有 LaunchAgent 行为仍由 Darwin adapter 负责；
- Linux 可以完成不涉及 LaunchAgent 的安装流程；
- 平台分支集中在明确 seam，而不是散落在业务逻辑中；
- `--only-preview` 两个平台均无副作用；
- 不运行真实 `slink` 修改用户环境进行验证。

---

## 7. 阶段五：重建功能目录和模块 ownership

平台边界明确后，才移动、合并或删除功能源码。

### Workspace 方向

审查并可能重组：

```text
packages/
profiles/
dotfiles/
```

最终结构必须表达：

- 可复用基础能力；
- 任务执行能力；
- Palette 领域；
- profile 规划和生成；
- dotfiles 配置和链接安装；
- 平台适配实现。

不为了形式统一创建没有真实职责的 `src`、`core` 或 `platform` 目录。

### Neovim 方向

明确区分：

```text
用户配置层：选择和装配第三方/本地插件
本地 package 层：实现可复用功能
平台无关 UI 逻辑
第三方插件 adapter
启动生命周期
```

配置层不得依赖本地 package 的内部文件结构。

### 模块调整规则

允许：

- 合并浅层转发模块；
- 删除无调用方的死代码；
- 收拢跨模块泄漏的状态；
- 将平台实现移入明确 adapter；
- 将真正独立的生命周期边界拆成 module；
- 改善目录的 locality。

禁止：

- 为了模仿旧测试路径而保留目录；
- 只为减少文件数而机械合并；
- 创建没有真实 interface 的通用框架；
- 在没有实际平台需求时预留多个空 adapter。

### 完成条件

- 功能目录只表达当前真实职责；
- 每个公共入口可从源码直接定位；
- 依赖方向清晰；
- 平台实现不会污染平台无关模块；
- 不需要旧文档或旧测试才能解释当前目录。

---

## 8. 阶段六：整理主要功能流程

功能目录稳定后，按真实生命周期审查主流程。

### Dotkit 安装流程

```text
选择平台
→ 解析环境
→ 生成 profile
→ 生成 link plan
→ preview 或 apply
→ 执行平台激活
```

关注：

- 配置解析与副作用分离；
- 完整声明验证后再应用变更；
- 失败时不留下半完成状态；
- platform adapter 不被错误调用。

### Neovim 启动流程

```text
启动
→ 基础 options / autocmd / keymaps
→ Palette
→ Pack registry / loader
→ plugin specs
→ lazy loading
→ UI 初始化
```

关注：

- setup 是否可重入；
- 加载失败能否恢复；
- 配置层是否知道实现细节；
- UI 初始化和插件加载顺序是否明确；
- 半初始化状态是否可清理。

### Popup、Picker、Oil、Terminal

统一审查：

- Popup group ownership；
- focus 与 buffer ownership；
- hide / close / reopen 语义；
- 配置快照边界；
- shell job 生命周期；
- 失败清理；
- 模块之间是否泄漏内部状态。

### Git 功能

统一审查 Gitgraph、Diffview、mini.git、mini.diff、Gitsigns 的：

- 状态来源；
- refresh 行为；
- tab、window 和 buffer identity；
- 配置层与第三方实现的依赖；
- 重复逻辑和不必要的 adapter。

### 完成条件

- 主要流程可以按生命周期描述；
- 每个状态都有明确 owner；
- 错误和关闭路径是对称的；
- 平台安装流程和 Neovim 运行流程之间没有隐式依赖。

---

## 9. 阶段七：功能代码质量审查

此阶段仍然不恢复旧文档和旧测试。

审查：

- 无调用方的源码；
- 浅层 module 和无意义 adapter；
- 重复状态；
- 过宽或泄漏实现细节的 interface；
- 平台条件分支泄漏；
- 配置、状态和副作用混合；
- setup 重入和生命周期不对称；
- 错误后留下的半初始化资源；
- 仅为旧测试保留的兼容代码；
- 命名、文件路径和 ownership 不一致；
- 不必要的启动成本和重复工作。

代码质量审查以可维护性、locality、depth 和 failure safety 为标准，不以表面文件数量或抽象数量为标准。

### 完成条件

- 功能源码不依赖旧材料才能理解；
- 主要 module 有明确职责和边界；
- 已处理确认存在的问题，而不是进行无目标的重构；
- 功能行为没有因为文档和测试迁出而被悄悄改变。

---

## 10. 阶段八：重新定义并编写文档

只有阶段一至七完成后，才恢复正式文档。本文件在此之前是唯一项目文档。

### 允许的文档结构

```text
README.md
AGENTS.md
CONTRIBUTING.md
docs/
├── architecture.md
├── platforms.md
├── testing.md
└── decisions/
```

真正独立的本地 package 最多保留一个 package-local `README.md`。

### 根 README 规范

只说明：

- 项目用途；
- 支持平台；
- 前置依赖；
- 安装和预览命令；
- 用户环境副作用；
- workspace 功能区域；
- 生成物和外部输入规则。

### AGENTS 规范

只说明：

- package ownership；
- 修改和验证规则；
- 平台边界；
- 禁止的环境操作；
- lock 文件、Palette 输入和用户改动规则；
- 如何处理运行时副作用。

### Package README 规范

每个 package README 只回答：

```text
Purpose
Entry point
Public interface
State ownership
Lifecycle
Platform constraints
Failure behavior
Verification command
```

不得重新引入：

```text
*-todo.md
*-plan.md
*-review.md
*-acceptance.md
*-progress.md
*-migration.md
```

开发过程放在临时资料、issue 或 commit message 中，不进入当前维护面。

### 完成条件

- 文档全部来自当前源码和已确认的当前行为；
- 没有复制旧文档的历史结论；
- 每份文档有唯一职责；
- 文档数量足以使用和维护项目，但不再描述开发过程。

---

## 11. 阶段九：重新定义并编写测试

文档完成后再建立测试。测试从当前功能和主要用户流程重新选择，不恢复旧测试目录。

### 长期测试只保留四类

#### Smoke

- workspace 可以构建；
- profile 可以生成；
- Neovim 可以启动。

#### Primary workflow

- 主要 Terminal 流程；
- 主要 Picker / Select 流程；
- 主要 Popup 流程；
- 主要 Shell 流程；
- 重要 Git 工作流。

#### Platform contract

- `darwin` 和 `linux` 选择；
- Linux 不加载或执行 `launchctl`；
- preview 没有副作用；
- XDG 默认值和覆盖行为；
- macOS 激活逻辑只由 Darwin adapter 负责。

#### High-risk regression

只保留同时满足以下条件的回归：

- 真实发生过；
- 容易再次发生；
- 失败代价高；
- 可以用小而明确的测试表达。

### 开发期测试

开发过程中可以创建任意临时测试、probe、PTY driver 或性能脚本，但统一放在仓库外，例如：

```text
/tmp/dotkit-probes/
```

开发完成后删除，或在确认属于长期 contract 后重新写成符合规范的新测试。旧测试不直接恢复。

### 长期测试禁止事项

不保留：

- 只测试内部函数调用顺序的测试；
- 只验证实现细节或文件布局的测试；
- 重构步骤验收测试；
- 一次性 probe 和 demo；
- 重复覆盖同一主要流程的测试；
- 没有明确失败含义的测试；
- 只为了提高覆盖率而存在的组合。

### 完成条件

- 每个长期测试对应主要流程、高风险生命周期或平台 contract；
- 测试数量显著小于迁出前；
- 测试失败能直接指向功能模块；
- headless 测试不冒充完整交互验收；
- `pnpm test` 只运行新建的长期测试。

---

## 12. 阶段十：恢复检查和 CI

最后恢复项目的验证入口，而不是恢复旧 runner。

保留或重建：

```text
pnpm check
pnpm test
```

检查入口只覆盖：

- 当前功能源码；
- 当前平台适配；
- 新建的少量长期测试；
- 当前文档规范要求的静态检查。

CI 从当前功能结构和新测试规范重新编写，不原样恢复旧 workflow。

不运行：

```text
pnpm slink
```

除非得到明确授权。真实用户环境行为继续使用 preview 或隔离临时目录验证。

---

## 13. 计划提交顺序

建议使用以下独立提交边界：

```text
1. chore: capture pre-rebuild reference snapshot
2. chore: remove legacy docs and tests from maintenance tree
3. refactor: rebuild functional source ownership
4. refactor: add darwin and linux platform seam
5. refactor: make profile and link flow cross-platform
6. refactor: simplify primary runtime flows
7. refactor: remove dead and shallow functional modules
8. docs: add current documentation set
9. test: add minimal smoke and workflow coverage
10. ci: restore checks for the rebuilt project
```

第 2 步完成后，旧文档和旧测试不再回到当前仓库。第 3 至第 7 步只关注功能代码。第 8、9 步才重新引入符合新规范的文档和测试。

---

## 14. 退出条件

本轮重建完成时，必须满足：

- 当前仓库没有迁出的旧文档和旧测试；
- `REBUILD-PLAN.md` 已经被有效的当前维护文档取代或删除；
- 顶层目录表达真实功能 ownership；
- macOS 和 Arch Linux 有明确、可执行的平台边界；
- Linux 路径不依赖 macOS 的 LaunchAgent 或 `launchctl`；
- 安装、profile、link 和平台激活流程分离；
- Neovim 配置层与本地 package 实现层边界清晰；
- 主要运行流程的状态 ownership 和失败行为明确；
- 只保留少量符合规范的主要流程测试；
- 新文档完全根据当前源码重写；
- `pnpm check` 和 `pnpm test` 通过；
- 没有未经授权的用户环境变更、插件同步或 lock 文件刷新。

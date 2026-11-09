# 对外能力契约

本文档描述三个领域模块对外提供的能力边界和协作语义，不规定具体 TypeScript 接口或内部实现。

## 总体原则

三个模块都以“模块对象 → 领域对象 → 对象级操作”的形式对外提供能力，但 Environment 是集合级例外：

```text
packages.neovim.install(context)
environment.attach(context)
configurations.neovim.apply(context)
```

模块决定能够提供哪些领域对象以及对象支持哪些操作。Bootstrap 选择对象、按三个固定阶段组织顺序、准备上下文并调用；模块不向 Bootstrap 暴露内部步骤，也不提供跨模块批量编排。公开契约必须说明：可调用的对象和操作、调用所需输入、结果含义，以及成功后对后续阶段的最低保证。

固定阶段为：

```text
Packages → Environment → Configurations
```

每个阶段内部的对象顺序由对应平台 Profile 的声明顺序决定。每次运行 Profile 都先检查各阶段当前是否已经完成且目标仍满足；满足时返回成功但不产生变化，继续后续阶段，不把这种情况当作新的安装或应用。

模块内部可以使用基类、接口、组合或其他实现方式，但实现方式不是本规格的外部契约。

## Packages

Packages 提供软件包对象及其领域操作：

```text
packages.<package>.install(context)
packages.<package>.uninstall(context)
```

### `install(context)`

用途：使指定软件包满足该对象声明的安装要求。

Context 至少用于提供：

- 当前平台和可用包管理能力；
- Profile 为该软件包声明的用户选项；
- 本次运行和记录存储上下文。

`install()` 成功后，Bootstrap 可以认为该软件包已经满足要求，并继续 Packages 阶段的下一个对象。软件包是否原本已满足、是否需要调用包管理器、失败后如何检查残留，均由 Packages 自己判断。

### `uninstall(context)`

用途：移除该软件包或处理该软件包由本项目产生的可安全移除内容。

Context 用于提供平台能力、用户策略和记录上下文。Packages 自己根据现实状态和自己的记录判断是否可以卸载；Bootstrap 不拼接卸载命令，也不解释部分安装记录。

Packages 决定支持哪些软件包，并拥有包管理器准备、平台调用、安装/卸载验证、所有权和记录等内部流程。Packages 不提供 `installAll()` 或 `uninstallAll()`；软件包的选择、Profile 顺序和阶段是否继续由 Bootstrap 负责。

## Environment

Environment 定义稳定的环境变量契约，并提供环境集合级操作：

```text
environment.attach(context)
environment.get(context)
environment.unattach(context)
```

单个变量对象用于定义、引用和读取变量契约，不作为 Bootstrap 逐项调用的生命周期对象。Environment 可以在内部逐变量解析和处理，但对 Bootstrap 暴露的是一次整体环境操作。

### `attach(context)`

用途：解析、验证并发布 Profile 选择的完整环境集合，同时为当前 Bootstrap 流程及其显式传递环境的子进程提供可用环境。

Context 至少用于提供：

- Profile 选择的变量和语义化输入；
- 当前平台和环境发布能力；
- 本次运行和记录存储上下文。

`attach()` 成功后，Bootstrap 才能把 Environment 的结果传给 Configurations。Bootstrap 不假设父 shell 或已运行进程会自动刷新。

### `get(context)`

用途：获取 Environment 当前确认的有效环境集合，供外部查看或传递给后续操作。它不要求调用者直接读取平台持久环境，也不暴露变量逐项发布过程。

### `unattach(context)`

用途：按 Environment 自己的记录、现实状态和策略，取消本项目发布的环境集合。Bootstrap 只决定是否调用，不决定恢复哪些变量。

`set()` 暂不作为公开生命周期操作；Profile 的语义化输入由 `attach(context)` 接收并统一解析、验证和发布。

变量契约至少拥有稳定名称、语义类型、语义说明、必需性和默认值解析规则。Environment 拥有变量定义和默认值解析；平台适配层提供当前平台的路径与能力。Bootstrap/Profile 只选择变量并传入符合契约的语义化用户输入，不能改变公共变量的类型或语义，也不直接负责拼接平台路径。

Environment 内部拥有变量解析、持久发布、当前流程环境构造、现实状态检查、原值记录和恢复流程。`attach()` 成功时必须区分并报告当前流程可用性与持久发布结果；普通子进程不能反向修改启动 Bootstrap 的父 shell。

## Configurations

Configurations 提供配置对象及其应用操作：

```text
configurations.<config>.apply(context)
configurations.<config>.remove(context)
```

### `apply(context)`

用途：使指定配置达到其声明的目标状态。目标可以包括配置文件、符号链接、生成内容、自研工具或插件等，但这些内部步骤不属于 Bootstrap 契约。

Context 至少用于提供：

- Environment 已确认的语义值；
- 当前平台能力和解析后的目标路径；
- 该配置自己的用户 `options`；
- 本次运行和记录存储上下文。

`apply()` 成功后，Bootstrap 可以认为该配置已达到目标，并继续 Configurations 阶段后续对象。

### `remove(context)`

用途：移除或取消该配置由本项目管理的内容。Configurations 自己根据现实状态、所有权、备份和记录判断安全边界。

每个配置自行定义内部步骤、顺序、判断和验证。Configurations 不负责选择 Profile、排序多个配置、执行整体流程或汇总整体结果。

## Context

上下文由 Bootstrap 准备并按操作传入。每个模块和领域对象拥有自己的 Context 类型，只声明并接收自己需要的资料；不定义一个所有模块共享的完整 Context。

```text
PlatformProfile
    ↓ Bootstrap 按模块裁剪
PackageContext
EnvironmentContext
ConfigurationContext
```

Context 可以包含：

- 当前模块需要的平台能力；
- 当前对象或模块的 Profile 配置；
- 后续操作需要的前一阶段结果；
- 当前模块需要的用户选项和策略。

PackagesContext 不包含 Environment 或 Configurations 的配置。EnvironmentContext 不包含配置对象的内部参数。ConfigurationContext 可以包含 Environment 已成功解析的语义值，但 Configurations 不直接调用 Environment，也不读取 Environment 的记录。

`run.id` 不属于当前公开 Context 契约；模块自己的操作记录标识、时间和内部记录关系由模块自行管理。模块记录不放入公共 Context，由模块自己创建、读取和解释。

当前流程环境不等于当前系统所有进程的环境：Bootstrap 只能保证自己及显式传递该环境的子进程；已运行外部进程不保证刷新，父 shell 需要专门的 eval/source 加载入口。

## 结果

Packages、Environment、Configurations 可以拥有各自的领域结果模型，不强制共享一个结果枚举。

每个操作对 Bootstrap 只提供两种确定结果：

```text
success
failure
```

成功结果还必须说明本次是否产生了实际变化：

```text
success.changed
success.unchanged
```

一个公开操作只有在以下条件全部满足时才返回 `success`：

1. 所需前置条件通过；
2. 操作执行完成，或目标原本已经满足；
3. 现实状态验证符合目标；
4. 模块需要保存的操作记录已经可靠落盘；
5. 没有未处理的残留、冲突或不确定性。

如果现实状态可能已经满足，但操作记录无法可靠落盘，仍返回 `failure`，并报告已发生的副作用、残留和记录不完整情况。`success.changed` 表示本次产生了变化；`success.unchanged` 表示目标原本已经满足且本次没有产生变化。只有 `success.changed` 才登记本次操作的取消计划。失败不能伪装成成功，也不使用 `partially_succeeded` 作为公共状态。普通重复部署不得为了重新执行而先卸载；只有明确的重新安装/重新应用请求才可以按对应领域规则先执行 `uninstall()` 或 `remove()`。

失败结果仍必须报告实际副作用、残留、不确定性和可用补救信息。没有“部分成功”状态，不代表失败前绝对没有发生副作用；模块必须在自己的边界内处理或报告这些情况。

详细结果、诊断、状态变化、记录内容和领域扩展字段由对应模块拥有、解释和保存。Bootstrap 不解释模块记录，也不处理模块内部状态组合；它只使用操作是否成功、是否产生变化以及是否允许继续等最小编排信号，不把不同领域的详细结果强行转换成同一种业务状态。

## 取消操作

`install/uninstall`、`attach/unattach` 和 `apply/remove` 是各领域公开提供的独立操作，不称为统一的“反向操作”。正向操作成功且产生变化时，所属模块在自己的阶段记录中登记对应的取消计划；成功但未产生变化时不登记取消项。该取消计划只属于本模块，不受其他模块后续结果影响。

取消计划只属于产生它的模块和本次编排上下文，不要求 Bootstrap 理解模块内部记录。Bootstrap 可以根据 Profile 和模块返回的最小信号请求对应的公开取消操作；具体哪些对象需要取消、如何检查和如何处理失败，由对应模块解释和执行。

各领域公开操作包括：

```text
install   → uninstall
environment.attach → environment.unattach
apply     → remove
```

取消操作必须由对应模块基于现实状态和自己的领域记录进行安全检查。无法安全操作时不得伪装成功，必须通过模块结果报告冲突、残留或限制。Bootstrap 不读取或解释这些细节，只决定是否继续整体编排或向用户报告模块失败。

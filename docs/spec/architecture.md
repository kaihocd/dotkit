# 架构规格

## 总体关系

```text
                         Bootstrap
                       编排者 / 总入口
                    ┌──────┼──────┐
                    ▼      ▼      ▼
               软件流程  环境流程  配置应用流程
                    │      │      │
                    ▼      ▼      ▼
               Packages Environment Configurations
```

三个领域模块各自拥有完整生命周期，不是被 Bootstrap 拆开的内部步骤。模块之间不互相调用或介入彼此内部流程。

## 分层

```text
项目声明层
    ↓
Bootstrap 编排层
    ↓
Packages / Environment / Configurations
    ↓
Platform 能力层
    ↓
Runtime 系统副作用
```

### 项目声明层

描述当前工作环境需要的软件包、环境变量和配置应用内容。配置中心只声明，不执行副作用。

### Bootstrap 编排层

选择 Profile 和平台方案，决定三个模块的顺序，传递必要的声明结果和运行时环境，执行严格停止策略并汇总结果。它不进入模块内部步骤。

### Packages

提供软件包对象和生命周期操作，例如 `packages.neovim.install()` 和 `packages.neovim.uninstall()`。Packages 决定能够管理哪些软件包；包管理器准备、平台调用、验证和记录属于内部实现。

### Environment

是环境变量契约的权威来源，定义稳定的变量集合、语义类型、必需性和默认解析规则，并提供环境集合级操作，例如 `environment.attach()`、`get()` 和 `unattach()`。平台适配层解析同一契约的实际值；Bootstrap/Profile 只能选择变量或提供经过验证的值覆盖，不能改变集合、类型或语义。平台发布、当前流程注入、验证和恢复属于内部实现。

### Configurations

提供配置对象和应用操作，例如 `configurations.neovim.apply(context)` 和 `configurations.neovim.remove(context)`。Configurations 决定能够提供哪些配置；每个配置自行定义内部步骤、顺序和验证规则。配置可以接收环境变量、平台能力和编排者传入的平台差异数据。Configurations 不负责 Profile 选择、配置间排序、整体启动或整体结果汇总；这些属于 Bootstrap 的编排职责。

### Platform

封装包管理器、路径解析、环境发布、链接能力和其他平台差异。上层不散落平台判断。

### Runtime

提供文件系统、进程、命令、状态存储等基础副作用能力。

## 依赖方向

```text
Bootstrap → Packages / Environment / Configurations
Packages / Environment / Configurations → Platform / Runtime
Platform → Runtime
```

领域模块之间不直接互相编排。模块之间若需要传递结果，由 Bootstrap 传递；这不改变模块独立性。

## 配置中心

配置中心描述：

```text
软件包声明
环境变量声明
配置应用声明
Profile 选择
模块或项目依赖
```

配置应用声明可以描述项目步骤、应用目标、通用动作、验证和取消操作，但不执行命令、文件操作、环境写入或清理。具体声明格式待设计。

配置内容的内部组织由内容所属项目负责；Configurations 只提供公开的应用边界和通用副作用能力。

## 工程化系统

工程化是开发前置条件和旁路，不属于工作环境部署领域；它负责检查、格式化、测试、构建和 Git hooks，不参与用户环境副作用。

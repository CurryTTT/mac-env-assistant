# Source modules

- `main.swift`：SwiftUI 界面、状态与启动入口。
- `Installer.swift` / `Bootstrap.swift`：安装计划、执行与系统前置工具引导。
- `Versions.swift` / `ExpandedCatalog.swift`：版本选择与软件目录。
- `EnvironmentChecks.swift`：预检、独立项目环境和运行状态验证。
- `ConfigurationScheme.swift` / `FeatureModel.swift`：方案校验、导入导出及界面衔接。
- `GitConfiguration.swift`：Git 身份配置、备份恢复和写入保护。
- `Purposes.swift`：用途与可选工具关联。

测试入口与业务逻辑同模块编译，运行方式见项目根目录的 `TESTING.md`。

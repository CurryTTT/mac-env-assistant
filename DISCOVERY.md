# 已有环境识别范围

检测按固定候选顺序选择第一个通过检查的入口。损坏入口不再遮蔽后续正常入口；同一真实路径去重。检测结果显示采用路径，并不修改 PATH 或终端、项目的默认解释器。

## 桌面应用

检查 `~/Applications`、`/Applications` 及最多两层子文件夹；另外检查 `~/Library/Application Support/JetBrains/Toolbox/apps` 下最多四层子文件夹。每个根目录最多访问 400 个条目，不进入应用包内部继续寻找软件，不递归目录符号链接。

以清单中的应用文件名匹配，补充 IDEA / PyCharm CE 别名及部分 JetBrains 数字版本后缀。任意重命名、其他磁盘及自定义 Toolbox 目录可能未覆盖。只有应用包和主程序存在才标记已检测到，这并不确认首次启动成功、许可、账号或签名有效。只发现不完整应用时提示检查，不直接覆盖。

## 命令与版本

优先现有固定候选路径，再检查以下运行时目录，每个目录最多选取 12 个规范数字版本，按版本降序尝试：

- pyenv：`PYENV_ROOT/versions/X.Y.Z/bin/python3`，默认 `~/.pyenv`。
- nvm：`NVM_DIR/versions/node/vX.Y.Z/bin/node`，默认 `~/.nvm`。
- Volta：`VOLTA_HOME/tools/image/node/X.Y.Z/bin/node`，默认 `~/.volta`。

目录环境变量只有绝对路径生效，来自启动本应用的进程环境；从 Finder 启动时不保证继承终端配置。直接检查已存在二进制，不加载 shell 配置，不运行管理器安装命令。不额外扫描管理器中的 pnpm 代理入口，以避免触发其自动下载行为。缓存中的解释器可能并非当前激活版本，选择页面会提示此区别。

选择具体系列时只复用匹配版本，例如 3.1 不匹配 3.10，22 不匹配 220。Python 的现有 uv 管理版本检测保留禁止下载参数。并不保证任意管理器、别名、开发版、Conda 或自定义项目环境都能识别。

## 路径依据

- [pyenv 目录与命令说明](https://github.com/pyenv/pyenv/blob/master/COMMANDS.md)
- [nvm 项目说明](https://github.com/nvm-sh/nvm)
- [Volta 安装目录](https://docs.volta.sh/advanced/installers)
- [JetBrains Toolbox 安装目录变更](https://blog.jetbrains.com/toolbox-app/2023/08/toolbox-app-2-0-overhauls-installations-and-updates/)

这些是受限范围的本机发现机制，未发现不等于电脑上绝对没有安装。检测可能执行候选命令的版本查询，单次查询有超时限制；不会启动数据库或替用户安装工具。

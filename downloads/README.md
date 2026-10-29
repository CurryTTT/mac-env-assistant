# DMG 安装包

[下载 MacEnvAssistant-v0.7.0-macOS-arm64.dmg](MacEnvAssistant-v0.7.0-macOS-arm64.dmg?raw=1)

1. 打开 DMG。
2. 将 `MacEnvAssistant.app` 拖入 `Applications`。
3. 退出旧版本后打开应用。

适用：Apple Silicon Mac，macOS 14 或更高版本。Homebrew 首次安装引导需要 macOS 15 或更高版本。

当前为开发试用版本，应用采用本地临时签名，未完成 Apple Developer ID 签名与公证。若系统不允许运行，可从仓库源码在本机构建；软件不会修改系统安全设置。

DMG 已通过 `hdiutil verify` 完整性校验。当前构建环境的磁盘管理服务不可用，因此使用 HFS+ 镜像生成并转换为 UDZO；尚未在构建环境实际挂载测试。

SHA-256：

```text
825ebd836c7c15607f1e070fd213337451f44c42852432e5c14350012ff0b0fc  MacEnvAssistant-v0.7.0-macOS-arm64.dmg
```

仓库为私有时，请登录有访问权限的 GitHub 账号后下载。

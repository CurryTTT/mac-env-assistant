# DMG 与正式签名

本机目前没有可用的 Apple 代码签名身份。默认构建只有临时签名，不代表通过 Gatekeeper 或 Apple 公证。

## 制作试用 DMG

使用独立 Python 虚拟环境安装 `ds_store==1.3.3` 与 `mac_alias==2.2.3`，随后运行：

```bash
PYTHON_BIN=/path/to/packaging-venv/bin/python bash Packaging/build-dmg.sh
```

脚本生成原生图标视图、背景、Applications 链接，读取 HFS+ 文件目录中的真实编号生成背景别名，并在两次生成镜像后保持卷创建日期一致。只修改 `.build/packaging` 中自己生成的镜像，不操作实际磁盘。最终镜像必须通过 `hdiutil verify`。Finder 窗口仍需在实际 macOS 桌面打开核对。

## 正式分发

需要开发者自行准备 Apple Developer Program 账号、有效的 Developer ID Application 证书及其私钥，并将公证凭据存入本机钥匙串。不要把私钥、密码或公证凭据提交仓库。

```bash
SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
  PYTHON_BIN=/path/to/packaging-venv/bin/python bash Packaging/build-dmg.sh
bash Packaging/notarize.sh dist/MacEnvAssistant-v0.8.0-macOS-arm64.dmg your-keychain-profile
```

有显式签名身份时，应用开启 Hardened Runtime 并获取时间戳，DMG 也会签名。公证脚本仅接受 Developer ID 签名镜像，确认 Apple 返回 Accepted 后才附加和验证票据。公证失败时应检查结果 JSON，并按提交 ID 获取 Apple 日志后处理；不能把普通签名校验当成公证成功。

附加票据会改变文件字节，Release 校验文件应在公证完成后生成。正式发布前还需在一台未放行过应用的 Mac 上从下载到首次运行完整验证。

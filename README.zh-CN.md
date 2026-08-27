# Whirl

[English](README.md) | [简体中文](README.zh-CN.md)

[![CI](https://github.com/baiyanwu/Whirl/actions/workflows/ci.yml/badge.svg)](https://github.com/baiyanwu/Whirl/actions/workflows/ci.yml)
[![CodeQL](https://github.com/baiyanwu/Whirl/actions/workflows/codeql.yml/badge.svg)](https://github.com/baiyanwu/Whirl/actions/workflows/codeql.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

![Whirl 应用图标](Whirl/Resources/Assets.xcassets/AppIcon.appiconset/icon_128.png)

Whirl 是一款适用于 Apple 芯片 Mac 的原生 macOS 26 应用启动器和同一应用窗口切换器。它通过一个可配置的修饰键统一完成应用启动、应用切换和窗口切换。

## 主要功能

- 可选择 Option、Command、Shift 或 Control 作为切换修饰键；左右任一实体键均可使用。
- 使用 `修饰键 + A–Z/0–9` 启动或切换到已配置的应用。如果该应用已在最前方，再次按下快捷键会将其隐藏。
- 按住所选修饰键可显示应用栏。
- 双击所选修饰键可显示当前应用的常规窗口。
- 使用空格键或回车键确认高亮窗口，也可按 1–9 直接选择对应编号的窗口。
- 完全以菜单栏工具运行，并提供完整的设置窗口和首次使用指南。
- 支持英文和简体中文。

## 系统要求

- Apple 芯片 Mac
- macOS 26 或更高版本
- 从源码构建需要 Xcode 26 或更高版本
- 修改 `project.yml` 时需要 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.45 或更高版本

项目不支持 Intel 构建，`ARCHS` 被有意限制为 `arm64`。

## 权限与隐私

常规应用快捷键使用 macOS 热键 API。长按和双击识别只观察所选修饰键的状态变化。这两条路径都不需要“输入监控”权限。

只有在双击后枚举、聚焦或切换窗口以及兼容的应用标签页时，Whirl 才会使用“辅助功能”权限。Whirl 不包含分析统计或网络客户端代码，设置仅保存在本地 `UserDefaults` 中。完整的数据处理说明请参阅 [PRIVACY.zh-CN.md](PRIVACY.zh-CN.md)。

## 从源码构建

克隆仓库并构建已提交的 Xcode 项目：

```sh
git clone https://github.com/baiyanwu/Whirl.git
cd Whirl
xcodebuild \
  -project Whirl.xcodeproj \
  -scheme Whirl \
  -configuration Debug \
  -derivedDataPath .build/RunDerivedData \
  build
open .build/RunDerivedData/Build/Products/Debug/Whirl.app
```

Debug 配置会在本机签名，以便 macOS 启动应用并将隐私权限与该应用关联。不要启动通过 `CODE_SIGNING_ALLOWED=NO` 生成的产物。如果没有 Apple Development 证书，每次重新构建都会得到新的临时代码身份；此时需要在“隐私与安全性”中移除或关闭再开启旧的 Whirl 条目，为新构建重新授权并重启应用。在 Xcode 中选择 Apple Development 团队，可让开发构建保持稳定身份。

如果修改了 `project.yml`，请重新生成并提交 Xcode 项目：

```sh
xcodegen generate
git diff -- Whirl.xcodeproj
```

## 测试

`Whirl` scheme 包含确定性单元测试，无需签名证书即可运行：

```sh
xcodebuild \
  -project Whirl.xcodeproj \
  -scheme Whirl \
  -configuration Debug \
  -derivedDataPath .build/TestDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  test
```

macOS UI 自动化要求应用、UI 测试包和测试运行器使用同一个有效的 Apple Development 团队签名。选择开发团队后运行：

```sh
xcodebuild \
  -project Whirl.xcodeproj \
  -scheme WhirlUITests \
  DEVELOPMENT_TEAM=YOUR_TEAM_ID \
  test
```

不要为 UI 测试命令禁用代码签名。未签名或临时签名的 UI 测试运行器会被系统拒绝，因为运行器与注入的测试包没有相同的 Team ID。

## 仓库结构

```text
Whirl/          应用源码和资源
WhirlTests/     确定性单元测试
WhirlUITests/   已签名的 macOS UI 测试
script/         本地构建与运行入口
scripts/        图标、归档、签名、公证和发布工具
release/        导出配置；生成的产物会被忽略
project.yml     生成 Xcode 项目的事实来源
```

## 发布

正式二进制版本从带注释的 `vX.Y.Z` 标签开始。GitHub Actions 会验证标签对应的源码，以及包含具体改动的英文和简体中文发布说明，但不会接收任何签名凭据。随后，维护者在本机从该标签的精确提交重新构建，使用只保存在本机钥匙串中的 Developer ID 身份签名，提交 Apple 公证，验证 Gatekeeper 接受状态和 SHA-256 完整性，最后将已验证产物与根据两份版本化更新日志生成的双语说明一起发布。仓库不会向最终用户发布未签名构建。维护者应遵循 [docs/RELEASING.zh-CN.md](docs/RELEASING.zh-CN.md)。

## 贡献与支持

提交拉取请求前请阅读 [CONTRIBUTING.zh-CN.md](CONTRIBUTING.zh-CN.md)。一般问题请使用 [GitHub Discussions](https://github.com/baiyanwu/Whirl/discussions)，可复现的错误或明确的功能建议请使用对应的中文 Issue 表单。安全问题必须按照 [SECURITY.zh-CN.md](SECURITY.zh-CN.md) 报告。中文拉取请求可使用[简体中文模板](.github/PULL_REQUEST_TEMPLATE/zh-CN.md)。

## 许可证

Whirl 采用 [MIT License](LICENSE) 发布。[中文翻译](LICENSE.zh-CN)仅供阅读参考，法律效力以英文原文为准。

# 更新日志

[English](CHANGELOG.md) | [简体中文](CHANGELOG.zh-CN.md)

Whirl 的所有重要改动都会记录在本文件中。

本文件格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，项目采用[语义化版本](https://semver.org/lang/zh-CN/spec/v2.0.0.html)。

## [未发布]

## [0.1.1] - 2026-09-01

### 新增

- 增加共用的切换器布局设置，让应用、窗口和兼容标签切换器可在原有横向排列与紧凑重叠扇形之间选择。
- 为全部项目文档和 GitHub 贡献者模板增加简体中文版本。
- 根据中英文更新日志的对应版本章节，生成包含具体改动的双语 GitHub Release 说明。
- 建立文档化的 `dev` → `release/vX.Y.Z` → `main` → 标签 → `dev` 流程，并让 CI 和 CodeQL 覆盖开发、发布与紧急修复分支。

### 变更

- 扇形切换器改为独立重叠材质卡片、统一的下方圆心、更紧凑的图标与快捷键，并使用支持“减弱动态效果”的 120 毫秒同步展开动画。
- 应用切换长按阈值现在最低可设为 50 毫秒，新安装默认使用 200 毫秒。

## [0.1.0] - 2026-08-26

### 新增

- 可将 Option、Command、Shift 或 Control 配置为应用快捷键的修饰键。
- 支持 A–Z 和 0–9 应用绑定，并提供启动、切换和隐藏行为。
- 长按显示应用栏，双击显示同一应用窗口切换器。
- 可选的兼容应用标签页发现功能。
- 菜单栏控制、设置、登录时启动支持和首次使用指南。
- 英文和简体中文本地化。
- 开源治理、安全、隐私、贡献和发布文档。
- 用于 macOS 构建验证、单元测试和 CodeQL 分析的 GitHub Actions 工作流。
- 由标签触发的 GitHub 发布就绪检查，以及由本机钥匙串提供凭据的 Developer ID 签名、Apple 公证、Gatekeeper 验证和经复验的 GitHub Release 发布。
- GitHub Issue 表单、拉取请求检查清单、CODEOWNERS 和 Dependabot 配置。

[未发布]: https://github.com/baiyanwu/Whirl/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/baiyanwu/Whirl/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/baiyanwu/Whirl/releases/tag/v0.1.0

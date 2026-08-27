# 为 Whirl 做贡献

[English](CONTRIBUTING.md) | [简体中文](CONTRIBUTING.zh-CN.md)

Whirl 欢迎范围明确的错误修复、测试、文档改进、本地化修正，以及不偏离键盘优先定位的功能建议。

## 开始之前

- 提交前先搜索现有 Issue 和 Discussions，避免重复。
- 宽泛的产品想法请使用 Discussion；具体、可复现的问题请使用 Issue。
- 拉取请求应足够小，以便独立审查和验证。
- 不要提交签名证书、描述文件、公证凭据、个人应用数据或生成的发布产物。

## 开发环境

你需要一台运行 macOS 26 或更高版本的 Apple 芯片 Mac，以及 Xcode 26 或更高版本。编辑项目规范时，还需要 XcodeGen 2.45 或更高版本。

```sh
git clone https://github.com/YOUR-USERNAME/Whirl.git
cd Whirl
xcodebuild \
  -project Whirl.xcodeproj \
  -scheme Whirl \
  -configuration Debug \
  -derivedDataPath .build/RunDerivedData \
  build
```

从当前 `main` 分支创建新分支：

```sh
git switch -c fix/short-description
```

## 项目生成

`project.yml` 是 target 和构建设置的事实来源。修改它之后，请重新生成项目，并在同一个提交中包含由此产生的 Xcode 项目差异：

```sh
xcodegen generate
git diff -- Whirl.xcodeproj
```

不要提交 `xcuserdata`、`DerivedData`、`.build` 或 `release/out` 中的任何内容。

## 测试

提交拉取请求前，请运行确定性单元测试套件：

```sh
xcodebuild \
  -project Whirl.xcodeproj \
  -scheme Whirl \
  -configuration Debug \
  -derivedDataPath .build/TestDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  test
```

如果改动涉及用户可见流程，在实际可行时还应新增或更新 UI 测试。UI 测试需要在本机配置 Apple Development 团队，并且不得使用 `CODE_SIGNING_ALLOWED=NO`。

## 拉取请求

拉取请求应当：

- 说明用户可见的问题和所选择的解决方案；
- 为改动的行为提供测试，或说明自动化测试为何不可行；
- 保持所有用户可见文本的英文和简体中文本地化覆盖；
- 对可见 UI 改动提供修改前后截图；
- 在行为变化时更新 README、隐私、安全或发布文档，并同步维护对应的英文和简体中文文档；
- 通过 CI 和 CodeQL。

提交贡献即表示你同意该贡献可按照仓库的 MIT License 进行分发。

# 发布 Whirl

[English](RELEASING.md) | [简体中文](RELEASING.zh-CN.md)

正式版本由维护者在自己的 Mac 上重新构建、签名、公证并发布。每次推送版本标签后，GitHub Actions 都会独立执行发布就绪检查，但它永远不会接收 Developer ID 私钥或 Apple 公证凭据。

不得将未签名构建作为最终用户下载内容上传。

## 信任边界

- Developer ID 证书和私钥只保存在本机 macOS 钥匙串中。
- Apple 公证凭据只保存在本机 `notarytool` 钥匙串配置中。
- GitHub 只接收源代码、CI 日志、已签名并公证的 DMG 及其 SHA-256 校验文件。
- 本机发布脚本会在远程标签对应的精确提交上创建 detached worktree 并从中构建。
- 只有当上传的产物被重新下载并独立复验后，GitHub Release 才会正式发布。

## 一次性本机配置

你需要：

- 一台运行 macOS 26 或更高版本的 Apple 芯片 Mac；
- Xcode 26 或更高版本，以及 XcodeGen 2.45 或更高版本；
- 本机钥匙串中有效的 **Developer ID Application** 身份；
- 名为 `whirl-local` 且已验证的 `notarytool` 钥匙串配置；
- 以 `baiyanwu/Whirl` 维护者身份完成认证的 GitHub CLI。

在本机创建公证配置。如果省略 `--password`，命令会安全地提示输入密码：

```sh
xcrun notarytool store-credentials whirl-local \
  --apple-id YOUR_APPLE_ID \
  --team-id YOUR_TEAM_ID
```

不要提交或上传证书、私钥、App 专用密码、API 密钥、钥匙串文件或公证配置。

## Release Notes 规范

每个 GitHub Release 都必须提供有实际信息的英文和简体中文说明。只有一条 `Full Changelog` 链接、没有解释的提交列表，或者“修复问题并改进体验”之类的笼统表述，都不属于合格的发布说明。

`CHANGELOG.md` 和 `CHANGELOG.zh-CN.md` 中的对应版本章节，是 Release 正文中更新内容的唯一事实来源。创建标签前必须满足：

- 两份更新日志使用相同的版本号和发布日期；
- 中英文改动条目数量一致、顺序一致；
- 说明具体改了什么，并在有必要时说明对用户的实际影响，不要直接复制提交标题；
- 按实际情况使用 Keep a Changelog 分类：英文为 `Added`、`Changed`、`Deprecated`、`Removed`、`Fixed` 或 `Security`，对应中文为 `新增`、`变更`、`弃用`、`移除`、`修复` 或 `安全`；
- 涉及安全问题的敏感实现细节，只能在协调披露之后写入；
- 比较、源代码、Issue 和拉取请求链接只能作为辅助资料，不能替代具体改动条目。

`scripts/generate-release-notes.sh` 按以下固定顺序生成 GitHub 正文：

1. `## English`，随后是英文版本条目；
2. 英文下载与 SHA-256 校验说明；
3. `## 简体中文`，随后是一一对应的中文版本条目；
4. 中文下载与 SHA-256 校验说明。

如果版本章节缺失、章节为空、中英文条目数量不一致、条目只是裸链接，或者使用 `Full Changelog` 作为更新内容，生成器都会拒绝继续。不得再用 GitHub 自动生成的 `--generate-notes` 输出替换该正文。

## 1. 准备版本

1. 在 `project.yml` 中设置 `MARKETING_VERSION` 并递增 `CURRENT_PROJECT_VERSION`。
2. 将 `CHANGELOG.md` 中的相关条目从 `Unreleased` 移到带日期的版本章节，并在 `CHANGELOG.zh-CN.md` 中同步对应的中文发布说明。
3. 在本机生成双语 GitHub Release 正文，确认两种语言的章节都包含具体改动条目。
4. 重新生成已提交的项目并检查差异。

```sh
zsh scripts/generate-release-notes.sh v0.1.0
xcodegen generate
git diff -- project.yml Whirl.xcodeproj CHANGELOG.md CHANGELOG.zh-CN.md
```

实际操作时，请将示例中的 `v0.1.0` 替换为本次准备发布的标签。

## 2. 验证并提交源码

```sh
xcodebuild \
  -project Whirl.xcodeproj \
  -scheme Whirl \
  -configuration Debug \
  -derivedDataPath .build/TestDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  test
```

提交版本变更，推送 `main`，并等待 CI 和 CodeQL 通过。发布版本必须能够可复现地绑定到 `main` 中的一个确定提交。

## 3. 推送带注释的发布标签

标签必须严格使用 `vX.Y.Z` 格式，并与 `project.yml` 中的 `MARKETING_VERSION` 一致：

```sh
git tag -a v0.1.0 -m "Whirl 0.1.0"
git push origin v0.1.0
```

`Release readiness` 工作流会独立验证：标签是否带注释、版本是否匹配、中英文发布说明章节是否存在且包含具体条目、生成的项目是否同步、是否不存在可执行构建阶段、单元测试是否通过，以及未签名 Release 构建是否成功。该工作流只有仓库只读权限，且不使用任何签名或公证密钥。

## 4. 从维护者的 Mac 发布

在仓库检出目录中运行一条命令：

```sh
./scripts/publish-tag.sh v0.1.0
```

发布脚本会：

1. 获取远程标签，确认标签带注释且对应提交包含在 `origin/main` 中；
2. 等待该标签精确提交对应的 GitHub 发布就绪工作流通过；
3. 验证本机 Developer ID 身份和公证配置；
4. 在标签提交上创建临时 detached worktree；
5. 根据标签中 `CHANGELOG.md` 和 `CHANGELOG.zh-CN.md` 的对应版本章节，生成包含具体改动的英文和简体中文发布说明；
6. 重新生成并比较 Xcode 项目，同时拒绝 shell 脚本构建阶段；
7. 重新运行单元测试，并在本机全新构建 Release 归档；
8. 签名应用和 DMG，将 DMG 提交给 Apple，并装订已接受的公证票据；
9. 验证签名、Gatekeeper 接受状态、磁盘映像完整性、Bundle ID、版本、构建号和 arm64 架构；
10. 写入并验证 SHA-256 校验文件；
11. 使用生成的双语说明创建 GitHub Release 草稿，并上传两个文件；
12. 验证草稿正文与生成的说明完全一致，再下载已上传的产物，并验证其字节内容、校验值、签名、公证票据、磁盘映像和 Gatekeeper 接受状态；
13. 只有全部检查都成功后，才正式发布草稿。

如果任一语言缺少对应的版本章节或具体改动条目，流程会在打包前停止。如果后续检查在创建草稿前失败，不会创建 Release。如果检查在上传后失败，Release 会保持为不可公开访问的草稿，以便排查。

## 5. 最终验证

从 GitHub Releases 下载两个公开产物并独立验证：

```sh
shasum -a 256 -c Whirl-0.1.0.dmg.sha256
xcrun stapler validate Whirl-0.1.0.dmg
spctl --assess --type open --context context:primary-signature --verbose=4 Whirl-0.1.0.dmg
```

# Git 工作流

[English](GIT_WORKFLOW.md) | [简体中文](GIT_WORKFLOW.zh-CN.md)

Whirl 使用稳定的 `main` 分支、长期存在的 `dev` 集成分支，以及短期存在的发布分支。只有发布分支已经合入 `main` 后，才能创建版本标签。推送普通分支永远不会发布二进制版本。

## 分支职责

- `main`：稳定源码，对应已经发布或可以发布的代码。日常开发不得直接提交到 `main`。
- `dev`：日常开发的集成分支。功能、修复、文档、测试和依赖更新的拉取请求通常以 `dev` 为目标分支。
- `feature/<主题>`、`fix/<主题>`、`docs/<主题>` 等：从 `dev` 创建的短期分支，合入 `dev` 后删除。
- `release/vX.Y.Z`：从 `dev` 创建、只服务于一个版本的短期稳定分支。只允许版本号、更新日志、发布文档和阻断发布的修复进入该分支。
- `hotfix/vX.Y.Z`：处理当前已发布版本紧急问题时，从 `main` 创建的特殊分支。

仓库默认分支继续保持为 `main`，这样公开首页和新克隆默认展示稳定代码。维护者创建普通拉取请求时，必须明确选择 `dev` 作为目标分支。

必需的 `Build and test` 工作流会执行稳定分支边界：只有来源分支符合 `release/vX.Y.Z` 或 `hotfix/vX.Y.Z` 的拉取请求才能合入 `main`；普通分支必须以 `dev` 为目标。

## 日常开发

从最新远程 `dev` 开始新工作：

```sh
git switch dev
git pull --ff-only origin dev
git switch -c feature/short-description
```

推送工作分支，并创建合入 `dev` 的拉取请求。CI 和 CodeQL 都通过后才能合并。合并后删除短期工作分支。

发布时不得直接把 `dev` 合入 `main`。必须创建带版本号的发布分支，使版本准备和稳定阶段的修复都可以独立审查。

## 发布流程

发布 `X.Y.Z` 版本时：

1. 更新本地 `dev`，并从它创建 `release/vX.Y.Z`。
2. 在发布分支中更新 `MARKETING_VERSION`、递增 `CURRENT_PROJECT_VERSION`、完成两份更新日志，并且只处理阻断发布的问题。
3. 推送 `release/vX.Y.Z`，等待分支检查完成，然后创建从 `release/vX.Y.Z` 合入 `main` 的拉取请求。
4. 通过审查且 CI/CodeQL 成功后，把发布拉取请求合入 `main`。
5. 更新本地 `main`，确认它与 `origin/main` 完全一致，然后在这个 `main` 提交上创建并推送带注释的 `vX.Y.Z` 标签。
6. 等待标签触发的 `Release readiness` 工作流。该工作流会验证标签提交已经包含在 `origin/main` 中，因此禁止在发布分支合入 `main` 之前打标签。
7. 在干净且与远端同步的本地 `main` 上运行 `./scripts/publish-tag.sh vX.Y.Z`。只有这一步会签名、公证、上传并正式发布二进制产物。
8. GitHub Release 确认成功后，把 `main` 回合到 `dev`，确保发布合并提交以及只在发布阶段产生的修复进入后续开发历史。
9. `main` 与 `dev` 同步后，删除本地和远程 `release/vX.Y.Z` 分支。

历史同步顺序固定为 `release → main → dev`。不要把发布分支分别独立合入两个长期分支：这样可能产生两个不同的合并提交，即使文件内容相同，`main` 和 `dev` 看起来仍会拥有不同的发布历史。

## 紧急修复流程

处理已发布版本的紧急问题时：

1. 从 `main` 创建 `hotfix/vX.Y.Z`；
2. 只实现并验证紧急修复，同时更新两份更新日志；
3. 通过拉取请求把紧急修复合入 `main`；
4. 为合并后的 `main` 提交打标签，并执行正常的签名发布流程；
5. 把 `main` 回合到 `dev`，随后删除紧急修复分支。

## 哪些操作会发布，哪些不会

- 推送 `feature/*`、`fix/*`、`docs/*`、`dev`、`release/*`、`hotfix/*` 或 `main` 只会运行对应验证，不会发布 Release。
- 推送带注释的 `vX.Y.Z` 标签只会运行发布就绪验证；该工作流仍然拿不到签名凭据，也不会发布产物。
- 在维护者的 Mac 上运行 `./scripts/publish-tag.sh vX.Y.Z`，才是明确的正式发布操作。
- 绝不能移动或重建已经发布的版本标签；需要修正时必须准备新版本。

签名、公证、双语 Release Notes、产物复验和失败处理的具体操作，以 [RELEASING.zh-CN.md](RELEASING.zh-CN.md) 为准。

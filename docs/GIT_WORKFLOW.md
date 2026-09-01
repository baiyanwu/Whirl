# Git Workflow

[English](GIT_WORKFLOW.md) | [简体中文](GIT_WORKFLOW.zh-CN.md)

Whirl uses a stable `main` branch, a long-lived `dev` integration branch, and short-lived release branches. A version tag is created only after the release branch has been merged into `main`. Pushing an ordinary branch never publishes a binary release.

## Branch roles

- `main`: stable source corresponding to released or release-ready code. Normal development must not be committed directly to `main`.
- `dev`: integration branch for day-to-day development. Feature, fix, documentation, test, and dependency pull requests normally target `dev`.
- `feature/<topic>`, `fix/<topic>`, `docs/<topic>`, and similar branches: short-lived branches created from `dev` and deleted after merging into `dev`.
- `release/vX.Y.Z`: short-lived stabilization branch created from `dev` for one release. Only versioning, changelog, release documentation, and release-blocking fixes belong here.
- `hotfix/vX.Y.Z`: exceptional branch created from `main` for an urgent fix to the currently released line.

The repository default branch remains `main` so the public landing page and fresh clones show stable code. Maintainers must explicitly target `dev` for ordinary pull requests.

The required `Build and test` workflow enforces the stable-branch boundary: a pull request into `main` is accepted only when its source branch matches `release/vX.Y.Z` or `hotfix/vX.Y.Z`. Ordinary branches must target `dev`.

## Daily development

Start new work from the current remote `dev`:

```sh
git switch dev
git pull --ff-only origin dev
git switch -c feature/short-description
```

Push the work branch and open a pull request into `dev`. CI and CodeQL must pass before merging. Delete the short-lived branch after merge.

Do not merge `dev` directly into `main` for a release. Cut a versioned release branch so release preparation and any stabilization fixes remain reviewable.

## Release flow

For version `X.Y.Z`:

1. Update local `dev` and create `release/vX.Y.Z` from it.
2. On the release branch, update `MARKETING_VERSION`, increment `CURRENT_PROJECT_VERSION`, finalize both changelogs, and make only release-blocking fixes.
3. Push `release/vX.Y.Z`, wait for branch checks, and open a pull request from `release/vX.Y.Z` into `main`.
4. After review and successful CI/CodeQL, merge the release pull request into `main`.
5. Update local `main`, confirm it exactly matches `origin/main`, then create and push the annotated `vX.Y.Z` tag on that `main` commit.
6. Wait for the tag-triggered `Release readiness` workflow. It verifies that the tag commit is contained in `origin/main`; therefore tagging the release branch before the `main` merge is prohibited.
7. Run `./scripts/publish-tag.sh vX.Y.Z` from a clean, synchronized local `main`. This is the only step that signs, notarizes, uploads, and publishes binary assets.
8. After the GitHub Release is confirmed, merge `main` back into `dev` so the release merge commit and any release-only fixes are retained in future development.
9. Delete the local and remote `release/vX.Y.Z` branch after `main` and `dev` are synchronized.

The history is intentionally synchronized as `release → main → dev`. Do not merge the release branch independently into both long-lived branches: two separate merge commits can make `main` and `dev` appear to contain different release histories even when their files match.

## Hotfix flow

For an urgent released-version fix:

1. create `hotfix/vX.Y.Z` from `main`;
2. implement and verify only the urgent fix, including both changelogs;
3. merge the hotfix into `main` through a pull request;
4. tag the resulting `main` commit and run the normal signed release process;
5. merge `main` back into `dev`, then delete the hotfix branch.

## Actions that do and do not publish

- Pushing `feature/*`, `fix/*`, `docs/*`, `dev`, `release/*`, `hotfix/*`, or `main` runs applicable validation only. It does not publish a Release.
- Pushing an annotated `vX.Y.Z` tag runs release-readiness validation only. It still does not receive signing credentials or publish an asset.
- Running `./scripts/publish-tag.sh vX.Y.Z` from the maintainer Mac is the explicit publication action.
- Never move or recreate a published version tag. Prepare a new version instead.

The operational signing, notarization, bilingual Release Notes, asset verification, and failure-handling steps are defined in [RELEASING.md](RELEASING.md).

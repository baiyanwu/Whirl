# Contributing to Whirl

[English](CONTRIBUTING.md) | [简体中文](CONTRIBUTING.zh-CN.md)

Whirl welcomes focused bug fixes, tests, documentation improvements, localization corrections, and feature proposals that preserve its keyboard-first scope.

## Before you start

- Search existing issues and discussions before opening a duplicate.
- Use a discussion for broad product ideas and an issue for a concrete, reproducible problem.
- Keep pull requests small enough to review and verify independently.
- Do not include signing certificates, provisioning profiles, notarization credentials, personal application data, or generated release artifacts.

## Development setup

You need an Apple silicon Mac running macOS 26 or later, Xcode 26 or later, and XcodeGen 2.45 or later when editing the project specification.

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

Create a branch from the current `dev` branch. Ordinary pull requests target `dev`; only reviewed `release/*` and `hotfix/*` branches target `main`:

```sh
git switch dev
git pull --ff-only origin dev
git switch -c fix/short-description
```

## Project generation

`project.yml` is the source of truth for targets and build settings. When it changes, regenerate the project and include the resulting Xcode project diff in the same commit:

```sh
xcodegen generate
git diff -- Whirl.xcodeproj
```

Do not commit anything under `xcuserdata`, `DerivedData`, `.build`, or `release/out`.

## Tests

Run the deterministic unit-test suite before opening a pull request:

```sh
xcodebuild \
  -project Whirl.xcodeproj \
  -scheme Whirl \
  -configuration Debug \
  -derivedDataPath .build/TestDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  test
```

Changes to a user-facing flow should also add or update a UI test when practical. UI tests require a locally configured Apple Development team and must not use `CODE_SIGNING_ALLOWED=NO`.

## Pull requests

A pull request should:

- explain the user-visible problem and the chosen solution;
- include tests for changed behavior, or explain why an automated test is not practical;
- preserve English and Simplified Chinese localization coverage for user-facing strings;
- include before/after screenshots for visible UI changes;
- update README, privacy, security, or release documentation when behavior changes, and keep the corresponding English and Simplified Chinese documents synchronized;
- pass CI and CodeQL.

See [docs/GIT_WORKFLOW.md](docs/GIT_WORKFLOW.md) for the complete daily-development, release, hotfix, tagging, and branch-synchronization policy.

By submitting a contribution, you agree that it may be distributed under the repository's MIT License.

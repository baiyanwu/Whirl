# Releasing Whirl

[English](RELEASING.md) | [简体中文](RELEASING.zh-CN.md)

Official releases are rebuilt, signed, notarized, and published from a maintainer's Mac. GitHub Actions performs an independent release-readiness check for every version tag, but it never receives the Developer ID private key or Apple notarization credentials.

Do not upload an unsigned build as an end-user download.

## Trust boundary

- The Developer ID certificate and private key stay in the local macOS Keychain.
- Apple notarization credentials stay in a local `notarytool` Keychain profile.
- GitHub receives only source code, CI logs, the signed and notarized DMG, and its SHA-256 checksum.
- The local publisher builds from a detached worktree at the exact remote tag commit.
- A GitHub Release is published only after the uploaded assets have been downloaded and independently rechecked.

## One-time local setup

You need:

- an Apple silicon Mac running macOS 26 or later;
- Xcode 26 or later and XcodeGen 2.45 or later;
- a valid **Developer ID Application** identity in the local Keychain;
- a validated `notarytool` Keychain profile named `whirl-local`;
- GitHub CLI authenticated as a maintainer of `baiyanwu/Whirl`.

Create the notarization profile locally. The command prompts securely when `--password` is omitted:

```sh
xcrun notarytool store-credentials whirl-local \
  --apple-id YOUR_APPLE_ID \
  --team-id YOUR_TEAM_ID
```

Do not commit or upload certificates, private keys, app-specific passwords, API keys, Keychain files, or notarization profiles.

## Release notes standard

Every GitHub Release must contain useful English and Simplified Chinese notes. A bare `Full Changelog` link, a commit list without explanation, or a generic statement such as "bug fixes and improvements" is not an acceptable release description.

The version sections in `CHANGELOG.md` and `CHANGELOG.zh-CN.md` are the only source of truth for the descriptive part of the Release body. Before tagging a release:

- use the same version and release date in both changelogs;
- keep the same number and order of change entries in both languages;
- describe what changed and, when useful, the user-visible effect rather than copying commit subjects;
- use the relevant Keep a Changelog categories: `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, or `Security`; use the corresponding Chinese headings `新增`, `变更`, `弃用`, `移除`, `修复`, or `安全`;
- mention security-sensitive implementation details only after coordinated disclosure;
- keep comparison, source, issue, and pull-request links as supporting references, never as substitutes for concrete change entries.

`scripts/generate-release-notes.sh` produces the required GitHub body in this fixed order:

1. `## English`, followed by the English version entries;
2. English download and SHA-256 verification instructions;
3. `## 简体中文`, followed by the matching Chinese version entries;
4. Chinese download and SHA-256 verification instructions.

The generator rejects a missing version section, an empty section, unequal English and Chinese entry counts, a bare URL entry, or a `Full Changelog` entry used as release content. Do not replace the generated body with GitHub's automatic `--generate-notes` output.

## 1. Prepare the version

1. Set `MARKETING_VERSION` and increment `CURRENT_PROJECT_VERSION` in `project.yml`.
2. Move relevant entries from `Unreleased` to a dated section in `CHANGELOG.md`, and mirror the release notes in `CHANGELOG.zh-CN.md`.
3. Generate the bilingual GitHub Release body locally and confirm that both language sections contain concrete bullet points.
4. Regenerate the checked-in project and inspect the diff.

```sh
zsh scripts/generate-release-notes.sh v0.1.0
xcodegen generate
git diff -- project.yml Whirl.xcodeproj CHANGELOG.md CHANGELOG.zh-CN.md
```

Replace `v0.1.0` in the examples with the release tag being prepared.

## 2. Verify and commit the source

```sh
xcodebuild \
  -project Whirl.xcodeproj \
  -scheme Whirl \
  -configuration Debug \
  -derivedDataPath .build/TestDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  test
```

Commit the version change, push `main`, and wait for CI and CodeQL to pass. The release must be reproducibly tied to one commit contained in `main`.

## 3. Push an annotated release tag

The tag must use the exact `vX.Y.Z` format and match `MARKETING_VERSION` in `project.yml`:

```sh
git tag -a v0.1.0 -m "Whirl 0.1.0"
git push origin v0.1.0
```

The `Release readiness` workflow independently verifies the annotated tag, version, non-empty English and Simplified Chinese release-note sections, generated project, absence of executable build phases, unit tests, and unsigned Release build. It has read-only repository permission and uses no signing or notarization secrets.

## 4. Publish from the maintainer Mac

Run one command from the repository checkout:

```sh
./scripts/publish-tag.sh v0.1.0
```

The publisher:

1. fetches the remote tag and verifies that it is annotated and contained in `origin/main`;
2. waits for the exact tag commit's GitHub release-readiness run to pass;
3. validates the local Developer ID identity and notarization profile;
4. creates a temporary detached worktree at the tag commit;
5. generates detailed English and Simplified Chinese release notes from the tagged version sections in `CHANGELOG.md` and `CHANGELOG.zh-CN.md`;
6. regenerates and compares the Xcode project and rejects shell-script build phases;
7. reruns unit tests and builds a fresh Release archive locally;
8. signs the app and DMG, submits the DMG to Apple, and staples the accepted ticket;
9. verifies signatures, Gatekeeper acceptance, disk-image integrity, bundle ID, version, build number, and arm64 architecture;
10. writes and verifies a SHA-256 checksum;
11. creates a draft GitHub Release with the generated bilingual notes and uploads both files;
12. verifies that the draft body exactly matches the generated notes, then downloads the uploaded assets and verifies their bytes, checksum, signature, notarization ticket, disk image, and Gatekeeper acceptance;
13. publishes the draft only after every check succeeds.

If either language is missing a matching version section or concrete bullet points, the process stops before packaging. If a later check fails before draft creation, no Release is created. If a check fails after upload, the Release remains a non-public draft for investigation.

## 5. Final verification

Download both public assets from GitHub Releases and verify them independently:

```sh
shasum -a 256 -c Whirl-0.1.0.dmg.sha256
xcrun stapler validate Whirl-0.1.0.dmg
spctl --assess --type open --context context:primary-signature --verbose=4 Whirl-0.1.0.dmg
```

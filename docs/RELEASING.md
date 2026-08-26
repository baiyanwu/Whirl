# Releasing Whirl

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

## 1. Prepare the version

1. Set `MARKETING_VERSION` and increment `CURRENT_PROJECT_VERSION` in `project.yml`.
2. Move relevant entries from `Unreleased` to a dated section in `CHANGELOG.md`.
3. Regenerate the checked-in project and inspect the diff.

```sh
xcodegen generate
git diff -- project.yml Whirl.xcodeproj CHANGELOG.md
```

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

The `Release readiness` workflow independently verifies the annotated tag, version, generated project, absence of executable build phases, unit tests, and unsigned Release build. It has read-only repository permission and uses no signing or notarization secrets.

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
5. regenerates and compares the Xcode project and rejects shell-script build phases;
6. reruns unit tests and builds a fresh Release archive locally;
7. signs the app and DMG, submits the DMG to Apple, and staples the accepted ticket;
8. verifies signatures, Gatekeeper acceptance, disk-image integrity, bundle ID, version, build number, and arm64 architecture;
9. writes and verifies a SHA-256 checksum;
10. creates a draft GitHub Release and uploads both files;
11. downloads the uploaded assets and verifies their bytes, checksum, signature, notarization ticket, disk image, and Gatekeeper acceptance;
12. publishes the draft only after every check succeeds.

If a check fails before draft creation, no Release is created. If a check fails after upload, the Release remains a non-public draft for investigation.

## 5. Final verification

Download both public assets from GitHub Releases and verify them independently:

```sh
shasum -a 256 -c Whirl-0.1.0.dmg.sha256
xcrun stapler validate Whirl-0.1.0.dmg
spctl --assess --type open --context context:primary-signature --verbose=4 Whirl-0.1.0.dmg
```

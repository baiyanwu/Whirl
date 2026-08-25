# Releasing Whirl

Official releases are built by GitHub Actions when a version tag is pushed. The workflow runs tests, imports the encrypted Developer ID certificate, signs the app and DMG, submits the DMG to Apple for notarization, staples and verifies the ticket, and creates the GitHub Release only after every check succeeds.

Do not upload an unsigned build as an end-user download.

## Prerequisites

- A clean `main` branch with CI and CodeQL passing.
- A paid Apple Developer Program team.
- A valid **Developer ID Application** certificate exported with its private key as a password-protected `.p12` file.
- An Apple ID app-specific password that is valid for notarization.
- The six repository Actions secrets described below.

Keep certificates, private keys, Team IDs, and notarization credentials outside the repository. Never commit them, attach them to an issue, or paste them into an Actions log.

## One-time GitHub Actions setup

Configure these encrypted repository secrets under **Settings → Secrets and variables → Actions**:

| Secret | Value |
| --- | --- |
| `MACOS_CERTIFICATE_BASE64` | Base64 text of the password-protected Developer ID Application `.p12` file |
| `MACOS_CERTIFICATE_PASSWORD` | Password used when exporting the `.p12` file |
| `APPLE_ID` | Apple ID used for notarization |
| `APPLE_APP_SPECIFIC_PASSWORD` | App-specific password created for that Apple ID |
| `APPLE_TEAM_ID` | Ten-character Apple Developer Team ID |
| `SIGNING_IDENTITY` | Full certificate name, for example `Developer ID Application: Name (TEAMID)` |

On macOS, convert the exported certificate without writing credentials into the repository:

```sh
base64 -i DeveloperIDApplication.p12 | pbcopy
```

Paste the copied value into `MACOS_CERTIFICATE_BASE64`. The workflow restores the certificate only into an ephemeral runner keychain, deletes that keychain at the end of the job, and never uploads signing material as an artifact.

## 1. Prepare the version

1. Set `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`.
2. Move relevant entries from `Unreleased` to a dated section in `CHANGELOG.md`.
3. Regenerate the checked-in project and inspect the diff.

```sh
xcodegen generate
git diff -- project.yml Whirl.xcodeproj CHANGELOG.md
```

## 2. Verify the source

```sh
xcodebuild \
  -project Whirl.xcodeproj \
  -scheme Whirl \
  -configuration Debug \
  -derivedDataPath .build/TestDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  test
```

Commit the version change before packaging. The release must be reproducibly tied to one commit.

## 3. Push the release tag

The tag must use the exact `vX.Y.Z` format and must match `MARKETING_VERSION` in `project.yml`. For version `0.1.0`:

```sh
git tag -a v0.1.0 -m "Whirl 0.1.0"
git push origin main
git push origin v0.1.0
```

The `Release` GitHub Actions workflow:

1. regenerates the Xcode project;
2. creates a Release archive;
3. exports and verifies the signed app;
4. creates and signs a DMG;
5. submits the DMG for notarization;
6. staples and validates the notarization ticket;
7. asks Gatekeeper to assess the DMG;
8. writes and verifies a SHA-256 checksum beside the DMG;
9. preserves both files as a workflow artifact;
10. creates the GitHub Release and attaches both files.

If any step fails, no GitHub Release is created. Fix the cause, delete the failed remote tag, create the corrected tag on the intended commit, and push it again.

## 4. Verify the published release

Download both assets from GitHub Releases and verify the checksum independently:

```sh
shasum -a 256 -c Whirl-0.1.0.dmg.sha256
xcrun stapler validate Whirl-0.1.0.dmg
spctl --assess --type open --context context:primary-signature --verbose=2 Whirl-0.1.0.dmg
```

### Local fallback

If GitHub Actions is unavailable, a maintainer with the same signing assets can use the local release script:

```sh
DEVELOPMENT_TEAM=YOUR_TEAM_ID \
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE=your-notary-profile \
./scripts/release.sh
```

Only upload the generated files after all script checks pass.

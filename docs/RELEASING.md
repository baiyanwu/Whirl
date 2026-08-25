# Releasing Whirl

This procedure is for maintainers publishing an official binary release. Do not upload an unsigned build as an end-user download.

## Prerequisites

- A clean `main` branch with CI and CodeQL passing.
- Xcode 26 or later and XcodeGen 2.45 or later.
- A valid **Developer ID Application** certificate in the login keychain.
- A `notarytool` keychain profile configured with Apple notarization credentials.
- GitHub CLI authenticated to the repository.

Keep certificates, private keys, Team IDs, and notarization credentials outside the repository.

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

## 3. Build, sign, notarize, and verify

```sh
DEVELOPMENT_TEAM=YOUR_TEAM_ID \
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE=your-notary-profile \
./scripts/release.sh
```

The script:

1. regenerates the Xcode project;
2. creates a Release archive;
3. exports and verifies the signed app;
4. creates and signs a DMG;
5. submits the DMG for notarization;
6. staples and validates the notarization ticket;
7. asks Gatekeeper to assess the DMG;
8. writes a SHA-256 checksum beside the DMG.

If any step fails, do not tag the commit and do not upload the artifact.

## 4. Tag and publish

Replace `0.1.0` with the version from `project.yml`:

```sh
git tag -a v0.1.0 -m "Whirl 0.1.0"
git push origin main
git push origin v0.1.0
gh release create v0.1.0 \
  release/out/signed/Whirl-0.1.0.dmg \
  release/out/signed/Whirl-0.1.0.dmg.sha256 \
  --verify-tag \
  --generate-notes \
  --title "Whirl 0.1.0"
```

Confirm that the public release shows the intended tag, notarized DMG, and checksum. Download the uploaded assets once and verify the checksum independently before announcing the release.

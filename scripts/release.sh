#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
OUTPUT_DIR="${PROJECT_DIR}/release/out/signed"
ARCHIVE_PATH="${OUTPUT_DIR}/Whirl.xcarchive"
DERIVED_DATA_PATH="${OUTPUT_DIR}/DerivedData"
VERSION="$(awk '/MARKETING_VERSION:/ { print $2; exit }' "${PROJECT_DIR}/project.yml")"
if [[ -z "${VERSION}" ]]; then
  print -u2 "Could not read MARKETING_VERSION from project.yml."
  exit 2
fi
DMG_PATH="${OUTPUT_DIR}/Whirl-${VERSION}.dmg"
CHECKSUM_PATH="${DMG_PATH}.sha256"
EXPORT_OPTIONS="${OUTPUT_DIR}/ExportOptions.plist"

: "${DEVELOPMENT_TEAM:?Set DEVELOPMENT_TEAM to your Apple Developer Team ID.}"
: "${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to your Developer ID Application certificate name.}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to a notarytool Keychain profile.}"

NOTARY_KEYCHAIN_ARGS=()
if [[ -n "${NOTARY_KEYCHAIN:-}" ]]; then
  if [[ ! -f "${NOTARY_KEYCHAIN}" ]]; then
    print -u2 "Notary keychain not found: ${NOTARY_KEYCHAIN}"
    exit 2
  fi
  NOTARY_KEYCHAIN_ARGS=(--keychain "${NOTARY_KEYCHAIN}")
fi

if [[ "${SIGNING_IDENTITY}" != "Developer ID Application:"* ]]; then
  print -u2 "SIGNING_IDENTITY must name a Developer ID Application certificate."
  exit 2
fi

if ! security find-identity -v -p codesigning | grep -Fq "${SIGNING_IDENTITY}"; then
  print -u2 "Developer ID identity not found: ${SIGNING_IDENTITY}"
  print -u2 "Create or download it in Xcode > Settings > Accounts > Manage Certificates."
  exit 2
fi

mkdir -p "${OUTPUT_DIR}"
EXPORT_DIR="$(mktemp -d "${OUTPUT_DIR}/export.XXXXXX")"
STAGING_DIR="$(mktemp -d "${OUTPUT_DIR}/dmg-root.XXXXXX")"
trap 'rm -rf "${EXPORT_DIR}" "${STAGING_DIR}" "${DERIVED_DATA_PATH}"' EXIT
cp "${PROJECT_DIR}/release/ExportOptions.plist" "${EXPORT_OPTIONS}"
plutil -replace teamID -string "${DEVELOPMENT_TEAM}" "${EXPORT_OPTIONS}"

xcodegen generate --spec "${PROJECT_DIR}/project.yml" --project "${PROJECT_DIR}"
xcodebuild \
  -project "${PROJECT_DIR}/Whirl.xcodeproj" \
  -scheme Whirl \
  -configuration Release \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  -archivePath "${ARCHIVE_PATH}" \
  DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM}" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="${SIGNING_IDENTITY}" \
  archive

xcodebuild \
  -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportPath "${EXPORT_DIR}" \
  -exportOptionsPlist "${EXPORT_OPTIONS}"

codesign --verify --deep --strict --verbose=2 "${EXPORT_DIR}/Whirl.app"

ditto "${EXPORT_DIR}/Whirl.app" "${STAGING_DIR}/Whirl.app"
ln -sfn /Applications "${STAGING_DIR}/Applications"
hdiutil create -volname Whirl -srcfolder "${STAGING_DIR}" -ov -format UDZO "${DMG_PATH}"
codesign --force --timestamp --sign "${SIGNING_IDENTITY}" "${DMG_PATH}"
codesign --verify --strict --verbose=2 "${DMG_PATH}"

xcrun notarytool submit \
  "${DMG_PATH}" \
  --keychain-profile "${NOTARY_PROFILE}" \
  "${NOTARY_KEYCHAIN_ARGS[@]}" \
  --wait \
  --timeout 30m
xcrun stapler staple "${DMG_PATH}"
xcrun stapler validate "${DMG_PATH}"
hdiutil verify "${DMG_PATH}"
spctl --assess --type open --context context:primary-signature --verbose=2 "${DMG_PATH}"

(
  cd "${OUTPUT_DIR}"
  shasum -a 256 "${DMG_PATH:t}" > "${CHECKSUM_PATH:t}"
)

print "Signed and notarized DMG: ${DMG_PATH}"
print "SHA-256 checksum: ${CHECKSUM_PATH}"

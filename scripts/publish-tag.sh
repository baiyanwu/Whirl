#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
REPOSITORY_DIR="${SCRIPT_DIR:h}"
GITHUB_REPOSITORY="baiyanwu/Whirl"
NOTARY_PROFILE="${NOTARY_PROFILE:-whirl-local}"

usage() {
  print -u2 "Usage: ./scripts/publish-tag.sh vX.Y.Z"
}

fail() {
  print -u2 "Error: $*"
  exit 1
}

if (( $# != 1 )); then
  usage
  exit 2
fi

TAG="$1"
if [[ ! "${TAG}" =~ '^v([0-9]+\.[0-9]+\.[0-9]+)$' ]]; then
  fail "Release tag must use the exact vX.Y.Z format."
fi
VERSION="${match[1]}"

for tool in git gh xcodegen xcodebuild security codesign hdiutil xcrun shasum plutil lipo ditto; do
  command -v "${tool}" >/dev/null 2>&1 || fail "Required tool not found: ${tool}"
done

REMOTE_URL="$(git -C "${REPOSITORY_DIR}" remote get-url origin)"
if [[ "${REMOTE_URL}" != "git@github.com:${GITHUB_REPOSITORY}.git" && \
      "${REMOTE_URL}" != "https://github.com/${GITHUB_REPOSITORY}.git" && \
      "${REMOTE_URL}" != "https://github.com/${GITHUB_REPOSITORY}" ]]; then
  fail "origin does not point to github.com/${GITHUB_REPOSITORY}: ${REMOTE_URL}"
fi

gh auth status >/dev/null
git -C "${REPOSITORY_DIR}" fetch origin main:refs/remotes/origin/main --tags

CURRENT_BRANCH="$(git -C "${REPOSITORY_DIR}" branch --show-current)"
[[ "${CURRENT_BRANCH}" == "main" ]] || fail "Run the publisher from the main branch."
[[ "$(git -C "${REPOSITORY_DIR}" rev-parse HEAD)" == \
   "$(git -C "${REPOSITORY_DIR}" rev-parse origin/main)" ]] || \
  fail "Local main is not synchronized with origin/main."
[[ -z "$(git -C "${REPOSITORY_DIR}" status --porcelain)" ]] || \
  fail "The repository must be clean before publishing."

git -C "${REPOSITORY_DIR}" show-ref --verify --quiet "refs/tags/${TAG}" || \
  fail "Tag does not exist locally after fetching origin: ${TAG}"

TAG_TYPE="$(git -C "${REPOSITORY_DIR}" cat-file -t "${TAG}")"
[[ "${TAG_TYPE}" == "tag" ]] || fail "Release tag must be annotated: ${TAG}"

TAG_COMMIT="$(git -C "${REPOSITORY_DIR}" rev-list -n 1 "${TAG}")"
REMOTE_TAG_COMMIT="$(git -C "${REPOSITORY_DIR}" ls-remote origin "refs/tags/${TAG}^{}" | awk 'NR == 1 { print $1 }')"
[[ -n "${REMOTE_TAG_COMMIT}" ]] || fail "Annotated tag is not present on origin: ${TAG}"
[[ "${REMOTE_TAG_COMMIT}" == "${TAG_COMMIT}" ]] || \
  fail "Local and remote tag commits differ for ${TAG}."

git -C "${REPOSITORY_DIR}" merge-base --is-ancestor "${TAG_COMMIT}" origin/main || \
  fail "Tagged commit is not contained in origin/main: ${TAG_COMMIT}"

PROJECT_VERSION="$(git -C "${REPOSITORY_DIR}" show "${TAG_COMMIT}:project.yml" | awk '/MARKETING_VERSION:/ { print $2; exit }')"
[[ "${PROJECT_VERSION}" == "${VERSION}" ]] || \
  fail "Tag version ${VERSION} does not match project version ${PROJECT_VERSION}."

if gh release view "${TAG}" --repo "${GITHUB_REPOSITORY}" >/dev/null 2>&1; then
  fail "A GitHub Release already exists for ${TAG}."
fi

for workflow in ci.yml codeql.yml; do
  CONCLUSION="$(gh run list \
    --repo "${GITHUB_REPOSITORY}" \
    --workflow "${workflow}" \
    --commit "${TAG_COMMIT}" \
    --limit 20 \
    --json conclusion,headSha \
    --jq "map(select(.headSha == \"${TAG_COMMIT}\")) | first | .conclusion // empty")"
  [[ "${CONCLUSION}" == "success" ]] || \
    fail "${workflow} has not passed for tagged commit ${TAG_COMMIT}."
done

print "Waiting for GitHub release-readiness checks for ${TAG_COMMIT}..."
RUN_ID=""
for _ in {1..60}; do
  RUN_ID="$(gh run list \
    --repo "${GITHUB_REPOSITORY}" \
    --workflow release.yml \
    --commit "${TAG_COMMIT}" \
    --event push \
    --limit 20 \
    --json databaseId,headSha \
    --jq "map(select(.headSha == \"${TAG_COMMIT}\")) | first | .databaseId // empty")"
  [[ -n "${RUN_ID}" ]] && break
  sleep 5
done
[[ -n "${RUN_ID}" ]] || fail "No release-readiness workflow run found for ${TAG_COMMIT}."
gh run watch "${RUN_ID}" --repo "${GITHUB_REPOSITORY}" --compact --exit-status

if [[ -z "${SIGNING_IDENTITY:-}" ]]; then
  IDENTITY_COUNT="$(security find-identity -v -p codesigning | awk -F '"' '/Developer ID Application:/ { count++ } END { print count + 0 }')"
  (( IDENTITY_COUNT == 1 )) || \
    fail "Expected exactly one Developer ID Application identity; found ${IDENTITY_COUNT}. Set SIGNING_IDENTITY explicitly when more than one exists."
  SIGNING_IDENTITY="$(security find-identity -v -p codesigning | awk -F '"' '/Developer ID Application:/ { print $2; exit }')"
fi
[[ -n "${SIGNING_IDENTITY}" ]] || \
  fail "No Developer ID Application identity is available in the local keychain."
[[ "${SIGNING_IDENTITY}" == "Developer ID Application:"* ]] || \
  fail "SIGNING_IDENTITY must name a Developer ID Application certificate."

DEVELOPMENT_TEAM="$(print -r -- "${SIGNING_IDENTITY}" | sed -n 's/.*(\([A-Z0-9]\{10\}\))$/\1/p')"
[[ -n "${DEVELOPMENT_TEAM}" ]] || \
  fail "Could not read the ten-character Team ID from SIGNING_IDENTITY."

security find-identity -v -p codesigning | grep -Fq "${SIGNING_IDENTITY}" || \
  fail "Signing identity is not available: ${SIGNING_IDENTITY}"

print "Validating local Apple notarization credentials..."
xcrun notarytool history \
  --keychain-profile "${NOTARY_PROFILE}" \
  --output-format json >/dev/null

FINAL_OUTPUT_DIR="${REPOSITORY_DIR}/release/out/signed"
FINAL_DMG="${FINAL_OUTPUT_DIR}/Whirl-${VERSION}.dmg"
FINAL_CHECKSUM="${FINAL_DMG}.sha256"
[[ ! -e "${FINAL_DMG}" && ! -e "${FINAL_CHECKSUM}" ]] || \
  fail "Final output already exists. Move it aside before publishing: ${FINAL_DMG}"

TEMP_ROOT="$(mktemp -d /private/tmp/whirl-publish.XXXXXX)"
WORKTREE_DIR="${TEMP_ROOT}/source"
DOWNLOAD_DIR="${TEMP_ROOT}/published"
MOUNT_DIR="${TEMP_ROOT}/mount"
RELEASE_NOTES="${TEMP_ROOT}/release-notes.md"
MOUNTED=0

cleanup() {
  if (( MOUNTED )); then
    hdiutil detach "${MOUNT_DIR}" >/dev/null 2>&1 || true
  fi
  if [[ -d "${WORKTREE_DIR}" ]]; then
    git -C "${REPOSITORY_DIR}" worktree remove --force "${WORKTREE_DIR}" >/dev/null 2>&1 || true
  fi
  if [[ -n "${TEMP_ROOT:-}" && "${TEMP_ROOT}" == /private/tmp/whirl-publish.* ]]; then
    rm -rf "${TEMP_ROOT}"
  fi
}
trap cleanup EXIT INT TERM

git -C "${REPOSITORY_DIR}" worktree add --detach "${WORKTREE_DIR}" "${TAG_COMMIT}"

print "Generating detailed bilingual release notes from the tagged changelogs..."
zsh "${WORKTREE_DIR}/scripts/generate-release-notes.sh" "${TAG}" > "${RELEASE_NOTES}"

xcodegen generate \
  --spec "${WORKTREE_DIR}/project.yml" \
  --project "${WORKTREE_DIR}"
git -C "${WORKTREE_DIR}" diff --exit-code -- Whirl.xcodeproj || \
  fail "Generated Xcode project differs from the tagged source."

if grep -q 'PBXShellScriptBuildPhase' "${WORKTREE_DIR}/Whirl.xcodeproj/project.pbxproj"; then
  fail "Tagged Xcode project contains a shell-script build phase."
fi

print "Running unit tests from tagged source..."
xcodebuild \
  -project "${WORKTREE_DIR}/Whirl.xcodeproj" \
  -scheme Whirl \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "${TEMP_ROOT}/TestDerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  test

print "Building, signing, notarizing, and verifying Whirl ${VERSION} locally..."
WHIRL_PROJECT_DIR="${WORKTREE_DIR}" \
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM}" \
SIGNING_IDENTITY="${SIGNING_IDENTITY}" \
NOTARY_PROFILE="${NOTARY_PROFILE}" \
"${SCRIPT_DIR}/release.sh"

SOURCE_DMG="${WORKTREE_DIR}/release/out/signed/Whirl-${VERSION}.dmg"
SOURCE_CHECKSUM="${SOURCE_DMG}.sha256"
[[ -f "${SOURCE_DMG}" && -f "${SOURCE_CHECKSUM}" ]] || \
  fail "Local release script did not produce the expected artifacts."

mkdir -p "${FINAL_OUTPUT_DIR}"
ditto "${SOURCE_DMG}" "${FINAL_DMG}"
ditto "${SOURCE_CHECKSUM}" "${FINAL_CHECKSUM}"

(
  cd "${FINAL_OUTPUT_DIR}"
  shasum -a 256 -c "${FINAL_CHECKSUM:t}"
)
codesign --verify --strict --verbose=2 "${FINAL_DMG}"
xcrun stapler validate "${FINAL_DMG}"
hdiutil verify "${FINAL_DMG}"
spctl --assess \
  --type open \
  --context context:primary-signature \
  --verbose=4 \
  "${FINAL_DMG}"

mkdir -p "${MOUNT_DIR}"
hdiutil attach "${FINAL_DMG}" -readonly -nobrowse -mountpoint "${MOUNT_DIR}" >/dev/null
MOUNTED=1

APP_PATH="${MOUNT_DIR}/Whirl.app"
INFO_PLIST="${APP_PATH}/Contents/Info.plist"
APP_BINARY="${APP_PATH}/Contents/MacOS/Whirl"
[[ -d "${APP_PATH}" && -f "${INFO_PLIST}" && -f "${APP_BINARY}" ]] || \
  fail "Final DMG does not contain a complete Whirl.app bundle."

codesign --verify --deep --strict --verbose=2 "${APP_PATH}"
spctl --assess --type execute --verbose=4 "${APP_PATH}"

SIGNING_DETAILS="$(codesign -dvvv "${APP_PATH}" 2>&1)"
print -r -- "${SIGNING_DETAILS}" | grep -Fq "Authority=${SIGNING_IDENTITY}" || \
  fail "Final app is not signed by the selected Developer ID identity."
print -r -- "${SIGNING_DETAILS}" | grep -Fq "TeamIdentifier=${DEVELOPMENT_TEAM}" || \
  fail "Final app Team ID does not match ${DEVELOPMENT_TEAM}."
print -r -- "${SIGNING_DETAILS}" | grep -Eq 'flags=.*runtime' || \
  fail "Final app is missing Hardened Runtime."

ENTITLEMENTS_PLIST="${TEMP_ROOT}/Whirl.entitlements.plist"
codesign -d --entitlements :- "${APP_PATH}" > "${ENTITLEMENTS_PLIST}" 2>/dev/null
if APP_SANDBOX="$(plutil -extract com.apple.security.app-sandbox raw -o - "${ENTITLEMENTS_PLIST}" 2>/dev/null)"; then
  :
else
  # Xcode may omit a false sandbox entitlement when exporting a Developer ID app.
  # An absent key and an explicit false value both mean App Sandbox is disabled.
  APP_SANDBOX="false"
fi
[[ "${APP_SANDBOX}" == "false" ]] || fail "Unexpected app sandbox entitlement: ${APP_SANDBOX}"

for nested_path in \
  "${APP_PATH}/Contents/Frameworks" \
  "${APP_PATH}/Contents/PlugIns" \
  "${APP_PATH}/Contents/XPCServices" \
  "${APP_PATH}/Contents/Library/LaunchServices"
do
  [[ ! -e "${nested_path}" ]] || fail "Unexpected nested code path: ${nested_path}"
done

BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw -o - "${INFO_PLIST}")"
BUNDLE_VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "${INFO_PLIST}")"
BUILD_NUMBER="$(plutil -extract CFBundleVersion raw -o - "${INFO_PLIST}")"
ARCHITECTURES="$(lipo -archs "${APP_BINARY}")"
[[ "${BUNDLE_ID}" == "com.baiyanwu.whirl" ]] || fail "Unexpected bundle identifier: ${BUNDLE_ID}"
[[ "${BUNDLE_VERSION}" == "${VERSION}" ]] || fail "Unexpected app version: ${BUNDLE_VERSION}"
[[ "${BUILD_NUMBER}" == <-> ]] || fail "Build number is not numeric: ${BUILD_NUMBER}"
[[ "${ARCHITECTURES}" == "arm64" ]] || fail "Unexpected architectures: ${ARCHITECTURES}"

hdiutil detach "${MOUNT_DIR}" >/dev/null
MOUNTED=0

print "Creating a draft GitHub Release..."
gh release create "${TAG}" \
  "${FINAL_DMG}" \
  "${FINAL_CHECKSUM}" \
  --repo "${GITHUB_REPOSITORY}" \
  --draft \
  --verify-tag \
  --notes-file "${RELEASE_NOTES}" \
  --title "Whirl ${VERSION}"

EXPECTED_RELEASE_BODY="$(< "${RELEASE_NOTES}")"
ACTUAL_RELEASE_BODY="$(gh release view "${TAG}" \
  --repo "${GITHUB_REPOSITORY}" \
  --json body \
  --jq .body)"
[[ "${ACTUAL_RELEASE_BODY}" == "${EXPECTED_RELEASE_BODY}" ]] || \
  fail "Draft GitHub Release notes differ from the generated bilingual notes."

mkdir -p "${DOWNLOAD_DIR}"
gh release download "${TAG}" \
  --repo "${GITHUB_REPOSITORY}" \
  --dir "${DOWNLOAD_DIR}" \
  --pattern "Whirl-${VERSION}.dmg*"

DOWNLOADED_DMG="${DOWNLOAD_DIR}/Whirl-${VERSION}.dmg"
DOWNLOADED_CHECKSUM="${DOWNLOADED_DMG}.sha256"
cmp -s "${FINAL_DMG}" "${DOWNLOADED_DMG}" || fail "Uploaded DMG differs from the local artifact."
cmp -s "${FINAL_CHECKSUM}" "${DOWNLOADED_CHECKSUM}" || fail "Uploaded checksum file differs from the local artifact."
(
  cd "${DOWNLOAD_DIR}"
  shasum -a 256 -c "${DOWNLOADED_CHECKSUM:t}"
)
codesign --verify --strict --verbose=2 "${DOWNLOADED_DMG}"
xcrun stapler validate "${DOWNLOADED_DMG}"
hdiutil verify "${DOWNLOADED_DMG}"
spctl --assess \
  --type open \
  --context context:primary-signature \
  --verbose=4 \
  "${DOWNLOADED_DMG}"

gh release edit "${TAG}" \
  --repo "${GITHUB_REPOSITORY}" \
  --verify-tag \
  --draft=false \
  --latest

RELEASE_URL="$(gh release view "${TAG}" --repo "${GITHUB_REPOSITORY}" --json url --jq .url)"
print "Published signed and notarized release: ${RELEASE_URL}"
print "Local DMG: ${FINAL_DMG}"
print "Local checksum: ${FINAL_CHECKSUM}"

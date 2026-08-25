#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
OUTPUT_DIR="${PROJECT_DIR}/release/out/unsigned"
ARCHIVE_PATH="${OUTPUT_DIR}/Whirl.xcarchive"
DERIVED_DATA_PATH="${OUTPUT_DIR}/DerivedData"

mkdir -p "${OUTPUT_DIR}"
trap 'rm -rf "${DERIVED_DATA_PATH}"' EXIT

xcodegen generate --spec "${PROJECT_DIR}/project.yml" --project "${PROJECT_DIR}"
xcodebuild \
  -project "${PROJECT_DIR}/Whirl.xcodeproj" \
  -scheme Whirl \
  -configuration Release \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  -archivePath "${ARCHIVE_PATH}" \
  CODE_SIGNING_ALLOWED=NO \
  archive

print "Unsigned archive: ${ARCHIVE_PATH}"

#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
REPOSITORY_DIR="${SCRIPT_DIR:h}"
GITHUB_REPOSITORY="baiyanwu/Whirl"

usage() {
  print -u2 "Usage: ./scripts/generate-release-notes.sh vX.Y.Z"
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

extract_release_date() {
  local changelog_path="$1"

  awk -v version="${VERSION}" '
    BEGIN {
      prefix = "## [" version "] - "
    }

    index($0, prefix) == 1 {
      release_date = substr($0, length(prefix) + 1)
      if (release_date !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) {
        exit 2
      }
      print release_date
      found = 1
      exit
    }

    END {
      if (!found) {
        exit 3
      }
    }
  ' "${changelog_path}"
}

extract_version_section() {
  local changelog_path="$1"

  awk -v version="${VERSION}" '
    BEGIN {
      target = "## [" version "]"
    }

    $0 == target || index($0, target " - ") == 1 {
      found = 1
      next
    }

    found && /^## / {
      exit
    }

    found && /^\[[^]]+\]: / {
      exit
    }

    found {
      lines[++line_count] = $0
    }

    END {
      if (!found) {
        exit 2
      }

      first = 1
      while (first <= line_count && lines[first] == "") {
        first++
      }

      last = line_count
      while (last >= first && lines[last] == "") {
        last--
      }

      has_change = 0
      for (cursor = first; cursor <= last; cursor++) {
        if (lines[cursor] ~ /^- /) {
          normalized = tolower(lines[cursor])
          if (normalized ~ /full changelog/ ||
              normalized ~ /^- *(bug fixes and improvements|various bug fixes|miscellaneous improvements)[.!]*$/ ||
              lines[cursor] ~ /(完整更新日志|全部更新日志)/ ||
              lines[cursor] ~ /^- *(修复问题并改进体验|修复若干问题|其他优化)[。.!]*$/ ||
              lines[cursor] ~ /^- *<?https?:\/\// ||
              lines[cursor] ~ /^- *\[[^]]+\]\(https?:\/\/[^)]+\)[。.!]*$/) {
            exit 4
          }
          has_change = 1
        }
      }

      if (!has_change) {
        exit 3
      }

      for (cursor = first; cursor <= last; cursor++) {
        print lines[cursor]
      }
    }
  ' "${changelog_path}"
}

ENGLISH_CHANGELOG="${REPOSITORY_DIR}/CHANGELOG.md"
CHINESE_CHANGELOG="${REPOSITORY_DIR}/CHANGELOG.zh-CN.md"
[[ -f "${ENGLISH_CHANGELOG}" ]] || fail "English changelog not found: ${ENGLISH_CHANGELOG}"
[[ -f "${CHINESE_CHANGELOG}" ]] || fail "Simplified Chinese changelog not found: ${CHINESE_CHANGELOG}"

ENGLISH_RELEASE_DATE="$(extract_release_date "${ENGLISH_CHANGELOG}")" || \
  fail "CHANGELOG.md must use a dated ## [${VERSION}] - YYYY-MM-DD release heading."
CHINESE_RELEASE_DATE="$(extract_release_date "${CHINESE_CHANGELOG}")" || \
  fail "CHANGELOG.zh-CN.md must use a dated ## [${VERSION}] - YYYY-MM-DD release heading."
[[ "${ENGLISH_RELEASE_DATE}" == "${CHINESE_RELEASE_DATE}" ]] || \
  fail "English and Simplified Chinese changelogs must use the same release date."

ENGLISH_NOTES="$(extract_version_section "${ENGLISH_CHANGELOG}")" || \
  fail "CHANGELOG.md must contain a non-empty ## [${VERSION}] section with concrete bullet points, not a bare link or Full Changelog entry."
CHINESE_NOTES="$(extract_version_section "${CHINESE_CHANGELOG}")" || \
  fail "CHANGELOG.zh-CN.md must contain a non-empty ## [${VERSION}] section with concrete bullet points, not a bare link or Full Changelog entry."

ENGLISH_CHANGE_COUNT="$(print -r -- "${ENGLISH_NOTES}" | awk '/^- / { count++ } END { print count + 0 }')"
CHINESE_CHANGE_COUNT="$(print -r -- "${CHINESE_NOTES}" | awk '/^- / { count++ } END { print count + 0 }')"
[[ "${ENGLISH_CHANGE_COUNT}" == "${CHINESE_CHANGE_COUNT}" ]] || \
  fail "English and Simplified Chinese release sections must contain the same number of change entries."

ENGLISH_CATEGORY_COUNT="$(print -r -- "${ENGLISH_NOTES}" | awk '/^### (Added|Changed|Deprecated|Removed|Fixed|Security)$/ { count++ } END { print count + 0 }')"
CHINESE_CATEGORY_COUNT="$(print -r -- "${CHINESE_NOTES}" | awk '/^### (新增|变更|弃用|移除|修复|安全)$/ { count++ } END { print count + 0 }')"
(( ENGLISH_CATEGORY_COUNT > 0 && CHINESE_CATEGORY_COUNT > 0 )) || \
  fail "Both release sections must use recognized Keep a Changelog category headings."
[[ "${ENGLISH_CATEGORY_COUNT}" == "${CHINESE_CATEGORY_COUNT}" ]] || \
  fail "English and Simplified Chinese release sections must contain the same number of categories."

print -r -- "## English"
print
print -r -- "${ENGLISH_NOTES}"
print
print -r -- "### Download and verification"
print
print -r -- "- \`Whirl-${VERSION}.dmg\` is the signed and Apple-notarized installer."
print -r -- "- \`Whirl-${VERSION}.dmg.sha256\` contains its SHA-256 checksum."
print
print -r -- "After downloading both files, verify the installer with:"
print
print -r -- '```sh'
print -r -- "shasum -a 256 -c Whirl-${VERSION}.dmg.sha256"
print -r -- '```'
print
print -r -- "[Source code for ${TAG}](https://github.com/${GITHUB_REPOSITORY}/tree/${TAG})"
print
print -r -- "---"
print
print -r -- "## 简体中文"
print
print -r -- "${CHINESE_NOTES}"
print
print -r -- "### 下载与校验"
print
print -r -- "- \`Whirl-${VERSION}.dmg\` 是经过签名和 Apple 公证的安装程序。"
print -r -- "- \`Whirl-${VERSION}.dmg.sha256\` 是对应的 SHA-256 校验文件。"
print
print -r -- "下载两个文件后，使用以下命令验证安装包："
print
print -r -- '```sh'
print -r -- "shasum -a 256 -c Whirl-${VERSION}.dmg.sha256"
print -r -- '```'
print
print -r -- "[${TAG} 版本源代码](https://github.com/${GITHUB_REPOSITORY}/tree/${TAG})"

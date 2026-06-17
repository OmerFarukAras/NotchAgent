#!/usr/bin/env bash
set -euo pipefail

APP_NAME="NotchAgent"
SCHEME="NotchAgent"
CONFIGURATION="Release"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_DIR="${ROOT_DIR}/.derivedData/release"
DIST_DIR="${ROOT_DIR}/dist"
DMG_STAGING_DIR="${DIST_DIR}/dmg"
ARCHIVE_PATH="${DIST_DIR}/archive/${APP_NAME}.xcarchive"
APP_PATH="${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app"
DMG_PATH="${DIST_DIR}/${APP_NAME}.dmg"

rm -rf "${DIST_DIR}"
mkdir -p "${DMG_STAGING_DIR}"

xcodebuild \
  -project "${ROOT_DIR}/${APP_NAME}.xcodeproj" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -derivedDataPath "${DERIVED_DATA_DIR}" \
  -archivePath "${ARCHIVE_PATH}" \
  -destination "generic/platform=macOS" \
  archive

if [ ! -d "${APP_PATH}" ]; then
  echo "Archive did not produce ${APP_PATH}" >&2
  exit 1
fi

ditto "${APP_PATH}" "${DMG_STAGING_DIR}/${APP_NAME}.app"
ln -s /Applications "${DMG_STAGING_DIR}/Applications"

hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${DMG_STAGING_DIR}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}"

rm -rf "${DMG_STAGING_DIR}"

echo "Created ${DMG_PATH}"

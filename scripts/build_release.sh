#!/usr/bin/env bash
set -euo pipefail

APP_NAME="NotchAgent"
SCHEME="NotchAgent"
CONFIGURATION="Release"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_DIR="${ROOT_DIR}/.derivedData/release"
DIST_DIR="${ROOT_DIR}/dist"
DMG_STAGING_DIR="${DIST_DIR}/dmg"
APP_PATH="${DERIVED_DATA_DIR}/Build/Products/${CONFIGURATION}/${APP_NAME}.app"
DMG_PATH="${DIST_DIR}/${APP_NAME}.dmg"

rm -rf "${DERIVED_DATA_DIR}" "${DIST_DIR}"
mkdir -p "${DMG_STAGING_DIR}"

xcodebuild \
  -project "${ROOT_DIR}/${APP_NAME}.xcodeproj" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -derivedDataPath "${DERIVED_DATA_DIR}" \
  clean build

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

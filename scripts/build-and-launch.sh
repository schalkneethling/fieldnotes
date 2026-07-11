#!/usr/bin/env bash
set -euo pipefail

PROJECT="Fieldnotes.xcodeproj"
SCHEME="Fieldnotes"
CONFIGURATION="Debug"
SIMULATOR_NAME="iPhone 17 Pro"
SIMULATOR_OS="26.2"
SIMULATOR_ID="E291849F-D50D-49F7-89AB-D0FDA5723080"
BUNDLE_ID="com.schalkneethling.fieldnotes"
BUILD_PRODUCTS=".build/Products"
BUILD_INTERMEDIATES=".build/Intermediates"
APP_PATH="${BUILD_PRODUCTS}/${CONFIGURATION}-iphonesimulator/Fieldnotes.app"

build_app() {
  xcodebuild \
    -project "${PROJECT}" \
    -target "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -sdk iphonesimulator \
    SYMROOT="${BUILD_PRODUCTS}" \
    OBJROOT="${BUILD_INTERMEDIATES}" \
    CODE_SIGNING_ALLOWED=NO \
    build
}

xcrun simctl boot "${SIMULATOR_ID}" 2>/dev/null || true
xcrun simctl bootstatus "${SIMULATOR_ID}" -b

build_app || {
  sleep 2
  build_app
}

xcrun simctl install "${SIMULATOR_ID}" "${APP_PATH}"
xcrun simctl launch "${SIMULATOR_ID}" "${BUNDLE_ID}"

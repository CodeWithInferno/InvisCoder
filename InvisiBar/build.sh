#!/bin/bash

APP_NAME="InvisiBar"
PRODUCT_NAME="InvisiBar"
BUILD_DIR=".build/release"
APP_BUNDLE_PATH="./${APP_NAME}.app"

# Clean previous build
rm -rf "${APP_BUNDLE_PATH}"

# Build the Swift project
swift build -c release

# Create the .app bundle structure
mkdir -p "${APP_BUNDLE_PATH}/Contents/MacOS"
mkdir -p "${APP_BUNDLE_PATH}/Contents/Resources"

# Copy the executable
cp "${BUILD_DIR}/${PRODUCT_NAME}" "${APP_BUNDLE_PATH}/Contents/MacOS/${PRODUCT_NAME}"

# Copy the Info.plist
cp "Sources/Info.plist" "${APP_BUNDLE_PATH}/Contents/Info.plist"

# Make the script executable
chmod +x "${APP_BUNDLE_PATH}/Contents/MacOS/${PRODUCT_NAME}"

echo "Build complete. ${APP_BUNDLE_PATH} created."

#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo " Building Mac Mouse Fix (Paywall-Free)   "
echo "=========================================="

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "Error: Mac Mouse Fix requires macOS and Xcode to build."
    echo "Current OS: $OSTYPE"
    exit 1
fi

# Ensure submodules
echo "Updating git submodules..."
git submodule update --init --recursive

# Clean previous build artifacts
BUILD_DIR="$(pwd)/build"
PRODUCTS_DIR="$BUILD_DIR/Build/Products/Release"
APP_NAME="Mac Mouse Fix.app"
ZIP_NAME="Mac Mouse Fix.zip"

rm -rf "$BUILD_DIR"
rm -f "$ZIP_NAME"

echo "Building Mac Mouse Fix via xcodebuild..."
xcodebuild -project "Mouse Fix.xcodeproj" \
           -scheme "App - Release" \
           -configuration Release \
           -derivedDataPath "$BUILD_DIR" \
           CODE_SIGN_IDENTITY="-" \
           CODE_SIGN_STYLE="Manual" \
           DEVELOPMENT_TEAM="" \
           CODE_SIGNING_REQUIRED=NO \
           CODE_SIGNING_ALLOWED=YES

if [[ ! -d "$PRODUCTS_DIR/$APP_NAME" ]]; then
    echo "Error: Built app not found at $PRODUCTS_DIR/$APP_NAME"
    exit 1
fi

echo "Signing bundle and embedded components (ad-hoc)..."
codesign --force --deep -s - "$PRODUCTS_DIR/$APP_NAME"

echo "Creating distribution zip archive..."
cd "$PRODUCTS_DIR"
zip -r -y "$BUILD_DIR/$ZIP_NAME" "$APP_NAME"
cd - > /dev/null

cp "$BUILD_DIR/$ZIP_NAME" "./$ZIP_NAME"

echo "=========================================="
echo " BUILD SUCCESSFUL! "
echo " Output App: $PRODUCTS_DIR/$APP_NAME"
echo " Output Zip: $(pwd)/$ZIP_NAME"
echo "=========================================="
echo ""
echo "To install:"
echo "1. Unzip $ZIP_NAME (or drag '$APP_NAME' to /Applications)"
echo "2. If macOS Gatekeeper blocks opening on first run, run:"
echo "   xattr -cr \"/Applications/$APP_NAME\""
echo "   or right-click the app in Finder and choose 'Open'."
echo "3. Grant Accessibility and Input Monitoring permissions when prompted."

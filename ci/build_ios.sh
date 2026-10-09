#!/bin/bash
set -euo pipefail
mkdir -p build/evidence build/export

"$GODOT" --version | tee build/evidence/godot-version.txt
xcodebuild -version | tee build/evidence/xcode-version.txt
"$GODOT" --headless --path game --editor --import 2>&1 | tee build/evidence/import.log
if grep -Eq 'SCRIPT ERROR:|ERROR: Failed to load' build/evidence/import.log; then
    echo 'Import contains blocking script/resource errors' >&2
    exit 1
fi
"$GODOT" --headless --path game --export-release iOS "$PWD/build/export/BuckshotMobile.zip" \
    2>&1 | tee build/evidence/export.log
test -d build/export/BuckshotMobile.xcodeproj

xcodebuild -project build/export/BuckshotMobile.xcodeproj -scheme BuckshotMobile \
    -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
    -derivedDataPath build/device CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY='' DEVELOPMENT_TEAM='' IPHONEOS_DEPLOYMENT_TARGET=16.0 \
    ARCHS=arm64 ONLY_ACTIVE_ARCH=NO build 2>&1 | tee build/evidence/device-build.log

APP="$PWD/build/device/Build/Products/Release-iphoneos/BuckshotMobile.app"
test -d "$APP"
python3 ci/verify_app.py "$APP" | tee build/evidence/ipa-validation.json
mkdir -p build/package/Payload
ditto "$APP" build/package/Payload/BuckshotMobile.app
(cd build/package && /usr/bin/zip -qry ../BuckshotMobile-unsigned.ipa Payload)
(cd build && shasum -a 256 BuckshotMobile-unsigned.ipa > BuckshotMobile-unsigned.ipa.sha256)

xcodebuild -project build/export/BuckshotMobile.xcodeproj -scheme BuckshotMobile \
    -configuration Release -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath build/simulator CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY='' DEVELOPMENT_TEAM='' IPHONEOS_DEPLOYMENT_TARGET=16.0 \
    ARCHS=arm64 ONLY_ACTIVE_ARCH=NO build 2>&1 | tee build/evidence/simulator-build.log
python3 ci/simulator_check.py build/simulator/Build/Products/Release-iphonesimulator/BuckshotMobile.app


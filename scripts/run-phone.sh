#!/usr/bin/env bash
# Membangun AplPhone untuk iPhone fisik, memasangnya, dan menjalankannya.
# Pemakaian: scripts/run-phone.sh [UDID]   (default: iPhone 17 "Egaaaaa")
set -euo pipefail

DEVICE="${1:-00008150-00024C841A0A401C}"
DERIVED="build/phone"

xcodegen generate >/dev/null
xcodebuild build -project DinoPocket.xcodeproj -scheme AplPhone \
  -destination "platform=iOS,id=${DEVICE}" -derivedDataPath "$DERIVED" \
  -allowProvisioningUpdates 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"

xcrun devicectl device install app --device "$DEVICE" \
  "$DERIVED/Build/Products/Debug-iphoneos/Apl.app"
xcrun devicectl device process launch --device "$DEVICE" --terminate-existing com.ega.apl.ios

#!/usr/bin/env bash
# Pembungkus perintah verifikasi tunggal Wave 0.
# Pemakaian: scripts/test.sh [project] [scheme]
set -euo pipefail

PROJECT="${1:-Jarvis}"
SCHEME="${2:-Jarvis}"

xcodebuild test \
  -project "${PROJECT}.xcodeproj" \
  -scheme "${SCHEME}" \
  -destination 'platform=macOS,arch=arm64' \
  2>&1 | grep -E "Test run with|TEST (SUCCEEDED|FAILED)|error:|❌"

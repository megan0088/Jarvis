#!/usr/bin/env bash
# Menegakkan batas SharedCore. Karena SharedCore adalah folder (bukan framework),
# compiler tidak menegakkan apa pun — skrip ini yang melakukannya.
set -uo pipefail

CORE="SharedCore"
fail=0

if [ ! -d "$CORE" ]; then
  echo "verify-boundaries: $CORE/ belum ada — dilewati"
  exit 0
fi

check() {                      # check <pola> <penjelasan>
  local hits
  hits=$(grep -rn "$1" "$CORE" --include="*.swift" || true)
  if [ -n "$hits" ]; then
    echo "❌ $2"
    echo "$hits"
    fail=1
  fi
}

check '^import SwiftUI'  "SharedCore tidak boleh mengimpor SwiftUI"
check '^import AppKit'   "SharedCore tidak boleh mengimpor AppKit"
check '^import UIKit'    "SharedCore tidak boleh mengimpor UIKit"
check '#if os('          "SharedCore tidak boleh punya guard platform"

if [ "$fail" -eq 0 ]; then
  echo "✅ batas SharedCore aman"
fi
exit "$fail"

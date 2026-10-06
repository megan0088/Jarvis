#!/usr/bin/env bash
# Menegakkan arah ketergantungan Clean Architecture di AplPhone (spec H §3.2).
# Lapisnya folder, bukan modul, jadi compiler tidak menegakkan apa pun.
set -uo pipefail

ROOT="AplPhone"
fail=0

if [ ! -d "$ROOT" ]; then
  echo "verify-phone-layers: $ROOT/ belum ada — dilewati"
  exit 0
fi

report() {                     # report <hasil grep> <penjelasan>
  if [ -n "$1" ]; then
    echo "❌ $2"
    echo "$1"
    fail=1
  fi
}

if [ -d "$ROOT/Domain" ]; then
  report "$(grep -rnE '^import ' "$ROOT/Domain" --include='*.swift' | grep -vE ':import Foundation$' || true)" \
         "Domain hanya boleh mengimpor Foundation"
  report "$(grep -rn 'UserDefaults' "$ROOT/Domain" --include='*.swift' || true)" \
         "Domain tidak boleh menyentuh penyimpanan"
fi

if [ -d "$ROOT/Data" ]; then
  report "$(grep -rnE '^import (SwiftUI|UIKit)$' "$ROOT/Data" --include='*.swift' || true)" \
         "Data tidak boleh mengimpor SwiftUI atau UIKit"
fi

if [ -d "$ROOT/Presentation" ]; then
  report "$(grep -rnE '(^|[^A-Za-z_.])(ReminderStore|ProfileStore|AppleBrain|FileChatSessionStore)\(' \
            "$ROOT/Presentation" --include='*.swift' | grep -v 'PreviewSupport.swift' || true)" \
         "Presentation tidak boleh membuat store atau layanan sendiri (pakai PhoneDependencies)"
  report "$(grep -rnE '^import UIKit$' "$ROOT/Presentation" --include='*.swift' | grep -v 'PhoneColors.swift' || true)" \
         "Presentation tidak mengimpor UIKit (kecuali PhoneColors)"
fi

if [ "$fail" -eq 0 ]; then
  echo "✅ lapis AplPhone aman"
fi
exit "$fail"

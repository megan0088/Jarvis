#!/usr/bin/env bash
# Memeriksa konfigurasi Release SEBELUM archive.
#
# Ada karena satu bug nyata: `configs:` di project.yml sempat ter-indent satu
# tingkat terlalu rendah, XcodeGen mengabaikannya diam-diam, dan
# `xcodebuild archive` melaporkan ** ARCHIVE SUCCEEDED ** — hijau palsu, karena
# entitlement Sign in with Apple tidak pernah ikut. App rilis akan mengunci user
# di layar login yang mati, dan tidak ada satu pun error yang muncul.
set -uo pipefail

PROJECT="${1:-DinoPocket}"
TARGET="${2:-DinoPocketMac}"
fail=0

settings() {
  xcodebuild -project "${PROJECT}.xcodeproj" -target "$TARGET" \
    -showBuildSettings -configuration "$1" 2>/dev/null
}

check() {   # check <config> <key> <pola-yang-diharapkan> <penjelasan>
  local value
  value=$(settings "$1" | grep -E "^\s+$2 = " | sed 's/.*= //' | tr -d ' ')
  if [[ "$value" == $3 ]]; then
    printf "  ✅ %-8s %-38s = %s\n" "$1" "$2" "$value"
  else
    printf "  ❌ %-8s %-38s = '%s' (harusnya %s) — %s\n" "$1" "$2" "$value" "$3" "$4"
    fail=1
  fi
}

echo "Konfigurasi Release:"
check Release CODE_SIGN_ENTITLEMENTS  "*DinoPocketMac.entitlements" "Sign in with Apple tidak akan berfungsi"
check Release ENABLE_APP_SANDBOX      "YES"  "wajib untuk Mac App Store"
check Release ENABLE_HARDENED_RUNTIME "YES"  "wajib untuk notarization"
check Release ENABLE_OUTGOING_NETWORK_CONNECTIONS "NO" "keputusan all-Apple"
check Release INFOPLIST_KEY_LSApplicationCategoryType "public.app-category.*" "App Store butuh kategori"

echo "Isi berkas entitlements:"
if grep -q "com.apple.developer.applesignin" DinoPocketMac/DinoPocketMac.entitlements 2>/dev/null; then
  echo "  ✅ com.apple.developer.applesignin ada"
else
  echo "  ❌ com.apple.developer.applesignin HILANG"; fail=1
fi

echo "Aset wajib:"
for f in DinoPocketMac/Resources/PrivacyInfo.xcprivacy DinoPocketMac/Resources/Robot.usdz; do
  [ -f "$f" ] && echo "  ✅ $f" || { echo "  ❌ $f hilang"; fail=1; }
done

[ "$fail" -eq 0 ] && echo "✅ konfigurasi Release siap" || echo "❌ ada yang perlu diperbaiki"
exit "$fail"

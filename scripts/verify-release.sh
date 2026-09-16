#!/usr/bin/env bash
# Memeriksa konfigurasi Release SEBELUM archive.
#
# Ada karena satu bug nyata: `configs:` di project.yml sempat ter-indent satu
# tingkat terlalu rendah, XcodeGen mengabaikannya diam-diam, dan
# `xcodebuild archive` melaporkan ** ARCHIVE SUCCEEDED ** — hijau palsu. Setiap
# pemeriksaan di bawah menjaga keputusan yang, bila dilanggar, tetap
# menghasilkan build hijau.
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
check Release ENABLE_APP_SANDBOX      "YES"  "wajib untuk Mac App Store"
check Release ENABLE_HARDENED_RUNTIME "YES"  "wajib untuk notarization"
check Release ENABLE_OUTGOING_NETWORK_CONNECTIONS "NO" "keputusan all-Apple"
check Release INFOPLIST_KEY_LSApplicationCategoryType "public.app-category.*" "App Store butuh kategori"

# Identitas produk. Bundle id PERMANEN begitu record App Store Connect dibuat —
# ketiganya pernah kosong atau memakai codename, dan tidak satu pun menghasilkan
# error saat build.
check Release PRODUCT_BUNDLE_IDENTIFIER "com.ega.apl" "bundle id salah — permanen setelah submit pertama"
check Release PRODUCT_NAME "Apl" "nama produk masih codename; CFBundleName ikut PRODUCT_NAME"
check Release INFOPLIST_KEY_CFBundleDisplayName "Apl" "nama di Finder/Dock salah"
check Release INFOPLIST_KEY_ITSAppUsesNonExemptEncryption "NO" "App Store Connect akan menanyakan ekspor enkripsi tiap submit"

echo "Hak cipta:"
if settings Release | grep -q "INFOPLIST_KEY_NSHumanReadableCopyright = ."; then
  echo "  ✅ NSHumanReadableCopyright terisi"
else
  echo "  ❌ NSHumanReadableCopyright kosong — key-nya hilang total dari Info.plist"; fail=1
fi

echo "Tanpa akun (spec A §5):"
entitlements=$(settings Release | grep -E "^\s+CODE_SIGN_ENTITLEMENTS = " | sed 's/.*= //' | tr -d ' ')
if [ -z "$entitlements" ]; then
  echo "  ✅ Release tanpa CODE_SIGN_ENTITLEMENTS"
else
  echo "  ❌ Release masih menunjuk '$entitlements' — Sign in with Apple sudah dihapus"; fail=1
fi
siwa=$(grep -rl "applesignin" DinoPocketMac --include="*.entitlements" 2>/dev/null || true)
if [ -z "$siwa" ]; then
  echo "  ✅ tidak ada entitlement Sign in with Apple"
else
  echo "  ❌ masih ada entitlement Sign in with Apple:"; echo "$siwa"; fail=1
fi

echo "Brain tunggal (spec A §2 #7):"
ollama=$(grep -rl "Ollama" SharedCore DinoPocketMac --include="*.swift" 2>/dev/null \
  | grep -vE "/Legacy/|/ContentView|PetActivityWidgets\.swift|Haptics\.swift" || true)
if [ -z "$ollama" ]; then
  echo "  ✅ tidak ada Ollama di kode yang di-build"
else
  echo "  ❌ Ollama muncul lagi:"; echo "$ollama"; fail=1
fi

echo "Aset wajib:"
if [ -f DinoPocketMac/Resources/PrivacyInfo.xcprivacy ]; then
  echo "  ✅ DinoPocketMac/Resources/PrivacyInfo.xcprivacy"
else
  echo "  ❌ DinoPocketMac/Resources/PrivacyInfo.xcprivacy hilang"; fail=1
fi

# Nama model dibaca dari CharacterAsset.robot, bukan disalin ke skrip ini:
# daftar tangan di sini pernah basi (Robot.usdz) setelah asetnya diganti.
models=$(awk '/static let robot = CharacterAsset\(/,/^    \)$/' \
           DinoPocketMac/Presentation/Character/CharacterAsset.swift \
         | grep -oE '"[A-Za-z0-9_]+"' | tr -d '"' | sort -u)
if [ -z "$models" ]; then
  echo "  ❌ tidak menemukan nama model di CharacterAsset.robot"; fail=1
fi
for name in $models; do
  file="DinoPocketMac/Resources/$name.usdz"
  if [ -f "$file" ]; then
    echo "  ✅ $file"
  else
    echo "  ❌ $file hilang — dirujuk CharacterAsset.robot"; fail=1
  fi
done

echo "Kompilasi Release:"
# Test suite berjalan pada konfigurasi Debug, jadi simbol yang tersembunyi di
# balik #if DEBUG lolos begitu saja — sampai archive. Itu pernah terjadi: helper
# .preview dibungkus #if DEBUG padahal blok #Preview ikut dikompilasi di Release.
# Kompilasi Release di sini menangkapnya sebelum langkah submit.
# CODE_SIGNING_ALLOWED=NO disengaja: yang diperiksa di sini adalah KODE, dan
# menggabungkannya dengan penandatanganan membuat kegagalan provisioning
# menyamar sebagai kegagalan kompilasi — dua masalah yang perbaikannya sama
# sekali berbeda. Provisioning diperiksa terpisah di bawah.
if xcodebuild build -project "${PROJECT}.xcodeproj" -scheme "$TARGET" \
     -configuration Release -derivedDataPath /tmp/dp-verify-release \
     CODE_SIGNING_ALLOWED=NO 2>&1 | grep -q "BUILD SUCCEEDED"; then
  echo "  ✅ konfigurasi Release terkompilasi"
else
  echo "  ❌ konfigurasi Release GAGAL dikompilasi"; fail=1
fi

echo "Provisioning (prasyarat submit, bukan masalah kode):"
if xcodebuild build -project "${PROJECT}.xcodeproj" -scheme "$TARGET" \
     -configuration Release -derivedDataPath /tmp/dp-verify-signed 2>&1 \
     | grep -q "BUILD SUCCEEDED"; then
  echo "  ✅ Release bisa ditandatangani"
else
  BID=$(settings Release | grep -E "^\s+PRODUCT_BUNDLE_IDENTIFIER = " | sed 's/.*= //' | tr -d ' ')
  echo "  ⚠️  belum bisa ditandatangani untuk '$BID'"
  echo "     Daftarkan App ID itu di developer.apple.com > Identifiers, lalu build"
  echo "     dengan -allowProvisioningUpdates. TIDAK memblokir pekerjaan kode."
fi

[ "$fail" -eq 0 ] && echo "✅ konfigurasi Release siap" || echo "❌ ada yang perlu diperbaiki"
exit "$fail"

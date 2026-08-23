# Wave 0 — Restrukturisasi Taggo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mengubah project multiplatform bertumpuk `#if` jadi struktur ala Taggo — `SharedCore/` + `DinoPocketMac/` yang di-generate XcodeGen — tanpa satu pun dari 28 test gagal.

**Architecture:** `project.yml` menjadi sumber kebenaran struktur target, `xcodegen` menghasilkan `DinoPocket.xcodeproj` di samping `Jarvis.xcodeproj` lama. File dipindah bertahap dengan `git mv` (riwayat per file terbawa), satu jenis perubahan per task, verifikasi test di tiap batas task. Target dipersempit ke macOS saja; jalur iOS dibekukan di tempat untuk spec companion iPhone. `SharedCore` adalah **folder dengan keanggotaan target**, bukan framework — jadi tidak ada anotasi `public` yang perlu ditambahkan.

**Tech Stack:** Swift 5.0 (naik ke 6.0 di Wave 2), SwiftUI, AppKit, RealityKit, Foundation Models, Swift Testing, XcodeGen 2.x, macOS 26.2+

**Spec:** `docs/superpowers/specs/2026-08-24-dinopocket-mac-real-design.md`

## Global Constraints

- **Branch:** `refactor/taggo-architecture`. Jangan commit ke `main`.
- **Perintah verifikasi tunggal** (dipakai di setiap task):
  `xcodebuild test -project <proj>.xcodeproj -scheme <scheme> -destination 'platform=macOS,arch=arm64'`
- **Baseline yang tidak boleh turun:** `Test run with 28 tests in 6 suites passed` · `** TEST SUCCEEDED **`
- **`SharedCore/` haram mengandung:** `import SwiftUI`, `import AppKit`, `import UIKit`, dan `#if os(`
- **`SharedCore` bukan framework target** — semua tipe tetap `internal`. Jangan menambahkan `public`.
- **Jangan hapus `Jarvis.xcodeproj`** sampai Task 8.
- **Pindahkan file dengan `git mv`**, bukan `mv` — riwayat per file harus terbawa.
- **Jangan ubah logika** di Wave 0. Hanya lokasi file, keanggotaan target, dan penghapusan kode mati/perancah demo. Perubahan semantik adalah Wave 1.
- **Nama produk masih codename** `DinoPocket`; bundle id tetap `com.Jarvis.Ega` sampai keputusan nama (spec §14).
- Build settings yang wajib direplikasi ada di spec §3.6.

---

### Task 1: Repo hygiene + skrip penegak batas

Karena `SharedCore` bukan modul terpisah, compiler **tidak** akan menegakkan batasnya. Skrip di task ini adalah satu-satunya penegak — jadi ia dibuat lebih dulu, sebelum ada yang bisa dilanggar.

**Files:**
- Create: `.gitignore`
- Create: `scripts/verify-boundaries.sh`
- Create: `scripts/test.sh`

**Interfaces:**
- Produces: `scripts/verify-boundaries.sh` (exit 0 = batas aman, exit 1 = dilanggar); `scripts/test.sh <project> <scheme>` membungkus perintah xcodebuild

- [ ] **Step 1: Buat `.gitignore`**

Repo saat ini tidak punya `.gitignore` sama sekali — itu sebabnya `xcuserdata` ikut ter-track.

```gitignore
# Xcode
build/
DerivedData/
*.xcuserstate
*.xcscmblueprint
**/xcuserdata/

# XcodeGen menghasilkan ini dari project.yml
DinoPocket.xcodeproj/

# macOS
.DS_Store

# Scratch
*.moved-aside
*.hmap
*.ipa
*.dSYM.zip
```

- [ ] **Step 2: Untrack xcuserdata yang sudah terlanjur masuk**

```bash
git rm -r --cached Jarvis.xcodeproj/xcuserdata Jarvis.xcodeproj/project.xcworkspace/xcuserdata 2>/dev/null || true
git rm --cached .DS_Store 2>/dev/null || true
find . -name .DS_Store -not -path "./.git/*" -exec git rm --cached {} \; 2>/dev/null || true
```

- [ ] **Step 3: Tulis `scripts/verify-boundaries.sh`**

```bash
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
```

- [ ] **Step 4: Tulis `scripts/test.sh`**

```bash
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
```

- [ ] **Step 5: Beri izin eksekusi dan jalankan keduanya**

```bash
chmod +x scripts/verify-boundaries.sh scripts/test.sh
./scripts/verify-boundaries.sh
./scripts/test.sh Jarvis Jarvis
```

Expected:
```
verify-boundaries: SharedCore/ belum ada — dilewati
Test run with 28 tests in 6 suites passed after ... seconds.
** TEST SUCCEEDED **
```

- [ ] **Step 6: Commit**

```bash
git add .gitignore scripts/
git add -u
git commit -m "chore: .gitignore + skrip penegak batas SharedCore

SharedCore akan jadi folder, bukan framework target, jadi compiler tidak
menegakkan batasnya. verify-boundaries.sh yang melakukannya.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: `project.yml` — macOS-only, layout file belum berubah

Memisahkan dua pertanyaan yang tidak boleh dijawab bersamaan: *"apakah XcodeGen mereproduksi build ini?"* dan *"apakah pemindahan file merusak sesuatu?"*. Task ini hanya menjawab yang pertama — nol file dipindah.

**Files:**
- Create: `project.yml`
- Test: seluruh `JarvisTests/` lewat skema baru

**Interfaces:**
- Consumes: `scripts/test.sh` dari Task 1
- Produces: `DinoPocket.xcodeproj` (tidak di-commit, ada di `.gitignore`); skema `DinoPocketMac`

- [ ] **Step 1: Tulis `project.yml`**

Path `sources` masih menunjuk folder lama `Jarvis/`. Lima file jalur iOS di-exclude — spec §5.4.

```yaml
name: DinoPocket

options:
  bundleIdPrefix: com.Jarvis
  createIntermediateGroups: true
  deploymentTarget:
    macOS: "26.2"
  groupSortPosition: top

settings:
  base:
    SWIFT_VERSION: "5.0"
    SWIFT_APPROACHABLE_CONCURRENCY: YES
    SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY: YES
    DEVELOPMENT_TEAM: R93K2HFM78
    CODE_SIGN_STYLE: Automatic
    MARKETING_VERSION: "1.0"
    CURRENT_PROJECT_VERSION: "1"
    ENABLE_PREVIEWS: YES
    ENABLE_USER_SCRIPT_SANDBOXING: YES

targets:
  DinoPocketMac:
    type: application
    platform: macOS
    sources:
      - path: Jarvis
        excludes:
          - "Presentation/Views/ContentView.swift"
          - "Presentation/Views/ContentView+iOS.swift"
          - "Presentation/Views/PetActivityWidgets.swift"
          - "Presentation/Views/PetWidgetsBundle.swift"
          - "Infrastructure/Services/Haptics.swift"
          - "DEMO_NOTES.md"
          - "DinoPocket.entitlements"
    settings:
      base:
        PRODUCT_NAME: DinoPocket
        # Nama modul SENGAJA dipertahankan sebagai Jarvis sepanjang Wave 0.
        # Keenam file test memakai `@testable import Jarvis`; mengubah nama modul
        # akan mematahkan 28 test sekaligus — justru jaring pengaman yang dipakai
        # setiap task di bawah — dan membuat Jarvis.xcodeproj lama tidak bisa lagi
        # mengompilasi test-nya, sehingga properti "dua project sama-sama hijau"
        # yang menjadi jalan mundur kita ikut hilang.
        # Nama modul ikut daftar rename terpusat (spec §14), bukan di Wave 0.
        PRODUCT_MODULE_NAME: Jarvis
        PRODUCT_BUNDLE_IDENTIFIER: com.Jarvis.Ega
        GENERATE_INFOPLIST_FILE: YES
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor
        INFOPLIST_KEY_NSHumanReadableCopyright: ""
        ENABLE_APP_SANDBOX: YES
        ENABLE_HARDENED_RUNTIME: YES
        ENABLE_OUTGOING_NETWORK_CONNECTIONS: NO
        ENABLE_INCOMING_NETWORK_CONNECTIONS: NO
        ENABLE_USER_SELECTED_FILES: readwrite
        COMBINE_HIDPI_IMAGES: YES

  DinoPocketTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: JarvisTests
    dependencies:
      - target: DinoPocketMac
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES

schemes:
  DinoPocketMac:
    build:
      targets:
        DinoPocketMac: all
    run:
      config: Debug
    test:
      config: Debug
      targets:
        - DinoPocketTests
    archive:
      config: Release
```

- [ ] **Step 2: Generate dan periksa target yang dihasilkan**

```bash
xcodegen generate
xcodebuild -list -project DinoPocket.xcodeproj
```

Expected: target `DinoPocketMac` dan `DinoPocketTests`; skema `DinoPocketMac`.

- [ ] **Step 3: Jalankan test lewat project baru**

```bash
./scripts/test.sh DinoPocket DinoPocketMac
```

Expected: `Test run with 28 tests in 6 suites passed` · `** TEST SUCCEEDED **`

Bila gagal karena simbol jalur iOS tidak ketemu, tambahkan file bersangkutan ke daftar `excludes` — **jangan** menambahkannya kembali ke build.

- [ ] **Step 4: Pastikan project lama masih hijau**

```bash
./scripts/test.sh Jarvis Jarvis
```

Expected: tetap `** TEST SUCCEEDED **`. Dua project hidup berdampingan sampai Task 8.

- [ ] **Step 5: Commit**

```bash
git add project.yml
git commit -m "build: project.yml — DinoPocket macOS-only via XcodeGen

Belum ada file yang dipindah. Task ini hanya membuktikan XcodeGen
mereproduksi build yang sama: 28 test hijau lewat skema baru, dan
Jarvis.xcodeproj lama tetap hijau.

Jalur iOS (5 file, spec §5.4) di-exclude, dibekukan untuk spec companion.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: Rename folder `Jarvis/` → `DinoPocketMac/`

Perubahan murni lokasi. Tidak ada isi file yang disentuh, sehingga kegagalan di sini pasti soal path, bukan kode.

**Files:**
- Move: `Jarvis/**` → `DinoPocketMac/**` (semua)
- Move: `JarvisTests/` → `DinoPocketTests/`
- Modify: `project.yml` (path `sources`)

**Interfaces:**
- Consumes: skema `DinoPocketMac` dari Task 2
- Produces: struktur folder `DinoPocketMac/{App,Infrastructure,Presentation,Resources,Assets.xcassets}` dan `DinoPocketTests/`

- [ ] **Step 1: Pindahkan folder dengan `git mv`**

```bash
git mv Jarvis DinoPocketMac
git mv JarvisTests DinoPocketTests
```

- [ ] **Step 2: Perbarui path di `project.yml`**

Ganti `- path: Jarvis` jadi `- path: DinoPocketMac`, dan `- path: JarvisTests` jadi `- path: DinoPocketTests`. Daftar `excludes` tidak berubah (relatif terhadap path).

- [ ] **Step 3: Generate ulang dan test**

```bash
xcodegen generate
./scripts/test.sh DinoPocket DinoPocketMac
```

Expected: `Test run with 28 tests in 6 suites passed` · `** TEST SUCCEEDED **`

- [ ] **Step 4: Verifikasi riwayat file ikut terbawa**

```bash
git log --follow --oneline -- DinoPocketMac/Infrastructure/Persistence/PetStore.swift | tail -3
```

Expected: menampilkan commit dari sebelum rename (bukti `git mv` mempertahankan riwayat).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: rename Jarvis/ -> DinoPocketMac/, JarvisTests/ -> DinoPocketTests/

Murni pemindahan lokasi lewat git mv; nol perubahan isi file.
Riwayat per file terbawa (diverifikasi dengan git log --follow).

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: Bedah Buddy Mode + karantina karakter 2D

Verifikasi menunjukkan `walkingScene` **tidak pernah di-assign** (`startBuddyMode` memanggil `skView.presentScene(nil)`), sehingga ketujuh tombol demo memanggil optional `nil` dan **sudah** no-op. Menghapusnya tidak mengubah perilaku apa pun kecuali hilangnya tombol dari layar.

**Files:**
- Modify: `DinoPocketMac/Infrastructure/Services/JarvisBuddyWindowController.swift`
- Move: `DinoPocketMac/Presentation/Views/WalkingJarvisScene.swift` → `DinoPocketMac/Legacy/`
- Move: `DinoPocketMac/Presentation/Views/JarvisScene.swift` → `DinoPocketMac/Legacy/`
- Move: `DinoPocketMac/Presentation/Views/RobotStyle.swift` → `DinoPocketMac/Legacy/`
- Modify: `project.yml` (tambah `Legacy/**` ke `excludes`)

**Interfaces:**
- Consumes: struktur folder dari Task 3
- Produces: `JarvisBuddyWindowController` tanpa dependensi SpriteKit-character; hanya `stopBuddyMode()` dan `startBuddyMode(store:onDismiss:)` yang tersisa sebagai API publik

- [ ] **Step 1: Hapus properti dan tombol demo dari controller**

Di `JarvisBuddyWindowController.swift`, hapus deklarasi berikut:

```swift
    private var walkingScene: WalkingJarvisScene?
    private let smallButton = NSButton(title: "Small", target: nil, action: nil)
    private let waterButton = NSButton(title: "Minum", target: nil, action: nil)
    private let stretchButton = NSButton(title: "Stretch", target: nil, action: nil)
    private let mealButton = NSButton(title: "Makan", target: nil, action: nil)
    private let resetWaterButton = NSButton(title: "Reset Water", target: nil, action: nil)
    private let resetStretchButton = NSButton(title: "Reset Stretch", target: nil, action: nil)
    private let resetMealButton = NSButton(title: "Reset Meal", target: nil, action: nil)
```

Simpan `stopButton` dan `controlStack` — keduanya masih dipakai; penggantian `stopButton` dengan tombol Esc adalah pekerjaan Wave 1, bukan Wave 0.

- [ ] **Step 2: Hapus pemanggilan tombol demo di `init`**

Hapus tujuh baris `configureTriggerButton(...)` dan ganti isi `controlStack` menjadi hanya `stopButton`:

```swift
        [stopButton].forEach(controlStack.addArrangedSubview)
```

Hapus juga fungsi `configureTriggerButton(_:title:action:)` yang kini tak terpakai.

- [ ] **Step 3: Hapus tujuh selector demo**

Hapus seluruh blok `@objc private func` berikut beserta atributnya: `makeCharacterSmall`, `triggerWaterReminder`, `triggerStretchReminder`, `triggerMealReminder`, `resetWaterGoal`, `resetStretchGoal`, `resetMealGoal`.

Pertahankan `stopButtonTapped`.

- [ ] **Step 4: Bersihkan `stopBuddyMode` dari referensi scene**

Ganti dua baris pertama:

```swift
    func stopBuddyMode() {
        walkingScene?.stopWalking()
        walkingScene = nil
        robotHostingView?.removeFromSuperview()
```

menjadi:

```swift
    func stopBuddyMode() {
        robotHostingView?.removeFromSuperview()
```

- [ ] **Step 5: Pindahkan tiga file 2D ke karantina**

```bash
mkdir -p DinoPocketMac/Legacy
git mv DinoPocketMac/Presentation/Views/WalkingJarvisScene.swift DinoPocketMac/Legacy/
git mv DinoPocketMac/Presentation/Views/JarvisScene.swift        DinoPocketMac/Legacy/
git mv DinoPocketMac/Presentation/Views/RobotStyle.swift         DinoPocketMac/Legacy/
```

- [ ] **Step 6: Kecualikan `Legacy/` dari build**

Tambahkan satu baris ke `excludes` target `DinoPocketMac` di `project.yml`:

```yaml
          - "Legacy/**"
```

- [ ] **Step 7: Buat `DinoPocketMac/Legacy/README.md`**

Supaya orang berikutnya tidak menyangka folder ini kode aktif.

```markdown
# Legacy — karakter SpriteKit 2D

Tidak ikut build (`excludes: ["Legacy/**"]` di `project.yml`).

Karakter 2D generasi pertama: `WalkingJarvisScene` (1.196 baris),
`JarvisScene`, `RobotStyle`. Digantikan karakter RealityKit 3D
(`RobotCharacterView` + `Robot.usdz`).

Disimpan karena desain 3D belum final. Bila 2D dipanggil kembali, ia menjadi
implementasi kedua dari `CharacterPresenting` (Wave 1) — bukan dihidupkan
kembali apa adanya.

Untuk mengaktifkan sementara: hapus `Legacy/**` dari `excludes`, lalu
`xcodegen generate`.
```

- [ ] **Step 8: Generate ulang dan test**

```bash
xcodegen generate
./scripts/test.sh DinoPocket DinoPocketMac
```

Expected: `Test run with 28 tests in 6 suites passed` · `** TEST SUCCEEDED **`

- [ ] **Step 9: Verifikasi tidak ada referensi tersisa**

```bash
grep -rn "WalkingJarvisScene\|JarvisScene\|RobotStyle\|PlatformColor" \
  DinoPocketMac --include="*.swift" | grep -v "^DinoPocketMac/Legacy/"
```

Expected: **tidak ada output.**

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "refactor(buddy): buang kontrol demo, karantina karakter 2D ke Legacy/

walkingScene tidak pernah di-assign (startBuddyMode memanggil presentScene(nil)),
jadi ketujuh tombol demo sudah no-op sebelum perubahan ini. Yang hilang dari
layar hanyalah tombol yang memang tidak melakukan apa-apa.

Tiga file SpriteKit (~1.700 baris) pindah ke Legacy/ dan dikecualikan dari
build. Tidak dihapus: desain 3D belum final.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: Ekstraksi `SharedCore/`

Tujuh file yang tidak punya guard platform dan tidak menyentuh UI naik ke folder bersama. Karena SharedCore bukan framework, tidak ada `public` yang perlu ditambahkan dan tidak ada `import SharedCore` di sisi pemakai.

**Files:**
- Move: 7 file (lihat Step 1) → `SharedCore/`
- Modify: `project.yml` (tambah `- path: SharedCore` ke `sources` kedua target)

**Interfaces:**
- Consumes: struktur folder dari Task 4
- Produces: `SharedCore/{Data/Models,Data/Enums,Infrastructure/Persistence,Infrastructure/Services}` berisi `ChatMessage`/`Persona`/`BrainKind`, `PetStore`, `Brain`, `AppleBrain`, `OllamaBrain`, `ReminderIntent`, `WellnessNotificationCenter` — semua tetap `internal`

- [ ] **Step 1: Pindahkan tujuh file**

`BrainTypes.swift` dipindah utuh dulu; pemecahannya jadi `Data/Models` + `Data/Enums` adalah pekerjaan Wave 1.

```bash
mkdir -p SharedCore/Data SharedCore/Infrastructure/Persistence SharedCore/Infrastructure/Services

git mv DinoPocketMac/Infrastructure/Services/BrainTypes.swift               SharedCore/Data/
git mv DinoPocketMac/Infrastructure/Persistence/PetStore.swift             SharedCore/Infrastructure/Persistence/
git mv DinoPocketMac/Infrastructure/Services/Brain.swift                   SharedCore/Infrastructure/Services/
git mv DinoPocketMac/Infrastructure/Services/AppleBrain.swift              SharedCore/Infrastructure/Services/
git mv DinoPocketMac/Infrastructure/Services/OllamaBrain.swift             SharedCore/Infrastructure/Services/
git mv DinoPocketMac/Infrastructure/Services/ReminderIntent.swift          SharedCore/Infrastructure/Services/
git mv DinoPocketMac/Infrastructure/Services/WellnessNotificationCenter.swift SharedCore/Infrastructure/Services/
```

- [ ] **Step 2: Tambahkan `SharedCore` ke `sources` kedua target**

Di `project.yml`, target `DinoPocketMac`:

```yaml
    sources:
      - path: SharedCore
      - path: DinoPocketMac
        excludes:
          ...
```

Target `DinoPocketTests` tidak perlu diubah — ia sudah `dependencies: [target: DinoPocketMac]` dan mengaksesnya lewat `@testable import`.

- [ ] **Step 3: Jalankan skrip penegak batas**

```bash
./scripts/verify-boundaries.sh
```

Expected: `✅ batas SharedCore aman`

Bila gagal: file yang dilaporkan salah kamar — kembalikan ke `DinoPocketMac/`, jangan longgarkan skripnya.

- [ ] **Step 4: Generate ulang dan test**

```bash
xcodegen generate
./scripts/test.sh DinoPocket DinoPocketMac
```

Expected: `Test run with 28 tests in 6 suites passed` · `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: ekstraksi SharedCore/ (7 file bebas platform)

SharedCore adalah folder dengan keanggotaan target, bukan framework —
mengikuti Taggo, yang tidak punya target SharedCore dan nol deklarasi public.
Konsekuensinya tidak ada anotasi public yang perlu ditambahkan, tapi batasnya
tidak ditegakkan compiler; verify-boundaries.sh yang menegakkan.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: Hapus guard `#if os(macOS)` dari target Mac

Target kini macOS-only, sehingga setiap `#if os(macOS)` selalu benar dan setiap cabang `#else` adalah kode mati. Menghapusnya tidak mengubah semantik.

**Files:**
- Modify: 27 file di `DinoPocketMac/` yang mengandung guard platform

**Interfaces:**
- Consumes: struktur dari Task 5
- Produces: `DinoPocketMac/` tanpa `#if os(` kecuali di `Legacy/`

- [ ] **Step 1: Daftar file yang terdampak sebelum menyentuh apa pun**

```bash
grep -rln "#if os(" DinoPocketMac --include="*.swift" | grep -v "^DinoPocketMac/Legacy/" | sort | tee /tmp/guard-files.txt
wc -l < /tmp/guard-files.txt
```

- [ ] **Step 2: Hapus guard satu file dulu, verifikasi polanya**

Mulai dari file paling sederhana, `DinoPocketMac/Presentation/Views/Spacing.swift` — isinya konstanta murni yang dibungkus `#if os(macOS) … #endif`. Hapus baris `#if os(macOS)` pembuka dan `#endif` penutupnya, sisakan isinya.

```bash
xcodegen generate && ./scripts/test.sh DinoPocket DinoPocketMac
```

Expected: tetap `** TEST SUCCEEDED **`

- [ ] **Step 3: Tangani satu-satunya file yang punya cabang `#else`**

Dari seluruh target Mac, hanya `DinoPocketMac/App/JarvisApp.swift` yang punya `#else`
(di `rootView`). Sebelum:

```swift
    @ViewBuilder
    private var rootView: some View {
#if os(macOS)
        DashboardTemplate(
            store: store,
            chat: chat,
            onBuddyMode: toggleBuddyMode,
            isBuddyModeActive: isBuddyMode
        )
        .onChange(of: isBuddyMode) { _, active in
            if active {
                JarvisBuddyWindowController.shared.startBuddyMode(
                    store: store,
                    onDismiss: { dismissFromBuddy() }
                )
                hidePrimaryWindows()
            } else {
                JarvisBuddyWindowController.shared.stopBuddyMode()
                showPrimaryWindows()
            }
        }
#else
        ContentView(store: store)
#endif
    }
```

Sesudah — tiga baris penanda dan cabang `#else` hilang:

```swift
    @ViewBuilder
    private var rootView: some View {
        DashboardTemplate(
            store: store,
            chat: chat,
            onBuddyMode: toggleBuddyMode,
            isBuddyModeActive: isBuddyMode
        )
        .onChange(of: isBuddyMode) { _, active in
            if active {
                JarvisBuddyWindowController.shared.startBuddyMode(
                    store: store,
                    onDismiss: { dismissFromBuddy() }
                )
                hidePrimaryWindows()
            } else {
                JarvisBuddyWindowController.shared.stopBuddyMode()
                showPrimaryWindows()
            }
        }
    }
```

Ini sekaligus menghapus referensi terakhir ke `ContentView` yang dibekukan.

- [ ] **Step 4: Kerjakan sisa file, satu per suntingan**

Untuk tiap file di `/tmp/guard-files.txt`:
- `#if os(macOS)` … `#endif` yang membungkus seluruh file → hapus kedua baris penanda saja
- `#if os(iOS)` … `#endif` → hapus blok berikut isinya (kode mati di target macOS)

Jangan pakai `sed` global — posisi `#endif` tiap file berbeda dan salah potong akan
menghapus kode yang masih dipakai.

- [ ] **Step 5: Verifikasi tidak ada guard tersisa**

```bash
grep -rn "#if os(" DinoPocketMac --include="*.swift" | grep -v "^DinoPocketMac/Legacy/"
```

Expected: **tidak ada output.**

- [ ] **Step 6: Test**

```bash
xcodegen generate && ./scripts/test.sh DinoPocket DinoPocketMac
```

Expected: `Test run with 28 tests in 6 suites passed` · `** TEST SUCCEEDED **`

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "refactor: hapus guard platform dari target Mac

Target macOS-only membuat setiap #if os(macOS) selalu benar dan setiap
cabang #else jadi kode mati. Keanggotaan target yang kini memisahkan
platform, bukan preprocessor.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 7: Buang sisa perancah demo

**Files:**
- Delete: `Untitled.swift`
- Delete: `DinoPocketMac/DEMO_NOTES.md`
- Delete: `DinoPocketMac/Presentation/Views/PetWidgetsBundle.swift`
- Modify: `DinoPocketMac/Presentation/Views/RobotCharacterView.swift` (hapus 6 `print`)
- Modify: `DinoPocketMac/Infrastructure/Services/JarvisBuddyWindowController.swift` (hapus 4 `print`)
- Modify: `DinoPocketMac/App/JarvisApp.swift` (hapus hook `JARVIS_AUTO_BUDDY`)

**Interfaces:**
- Consumes: struktur dari Task 6
- Produces: nol `[JARVIS-DIAG]` di seluruh basis kode; satu sumber kebenaran widget

- [ ] **Step 1: Hapus tiga file mati**

`Untitled.swift` isinya hanya header komentar. `DEMO_NOTES.md` mendokumentasikan tombol
yang sudah dihapus di Task 4.

`PetWidgetsBundle.swift` menutup item duplikasi widget di spec §5.4 — dan resolusinya
ternyata sepele. Seluruh isinya dibungkus `#if WIDGET_EXTENSION`, sementara
`grep -rn "WIDGET_EXTENSION" project.pbxproj` menghasilkan **nol** — flag itu tidak pernah
didefinisikan di mana pun. Ia juga memanggil `PetActivityWidget()` yang tidak pernah
didefinisikan (hanya `PetWidget` ada, di `PetActivityWidgets.swift:85`), jadi seandainya
flag itu diaktifkan pun ia tidak akan terkompilasi. Kode mati total.

`JarvisWidget/JarvisWidgetBundle.swift` adalah bundle widget yang sungguhan dan tetap
dibekukan untuk spec companion iPhone.

```bash
git rm Untitled.swift \
       DinoPocketMac/DEMO_NOTES.md \
       DinoPocketMac/Presentation/Views/PetWidgetsBundle.swift
```

Hapus juga baris `- "Presentation/Views/PetWidgetsBundle.swift"` dari `excludes`
di `project.yml`, karena file-nya sudah tidak ada.

- [ ] **Step 2: Hapus seluruh logging diagnostik**

```bash
grep -rn "JARVIS-DIAG" DinoPocketMac --include="*.swift"
```

Hapus setiap baris yang muncul. Di `RobotCharacterView.swift`, `guard` yang tadinya berisi `print` dikembalikan ke bentuk satu baris:

```swift
            guard let robot = try? await Entity(named: "Robot", in: Bundle.main) else { return }
```

Fallback avatar untuk kasus gagal-muat adalah pekerjaan Wave 1 (spec §9); Wave 0 hanya membuang logging.

- [ ] **Step 3: Hapus hook `JARVIS_AUTO_BUDDY` dari `JarvisApp.swift`**

Hapus blok ini seluruhnya:

```swift
#if os(macOS)
                    // Temporary diagnostic hook: JARVIS_AUTO_BUDDY=1 opens Buddy Mode on launch.
                    if ProcessInfo.processInfo.environment["JARVIS_AUTO_BUDDY"] == "1" {
                        isBuddyMode = true
                    }
#endif
```

- [ ] **Step 4: Verifikasi bersih**

```bash
grep -rn "JARVIS-DIAG\|JARVIS_AUTO_BUDDY" . --include="*.swift" | grep -v "^./DinoPocketMac/Legacy/"
```

Expected: **tidak ada output.**

- [ ] **Step 5: Test**

```bash
xcodegen generate && ./scripts/test.sh DinoPocket DinoPocketMac
```

Expected: `Test run with 28 tests in 6 suites passed` · `** TEST SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore: buang perancah demo dan logging diagnostik

Untitled.swift (file kosong), DEMO_NOTES.md (mendokumentasikan tombol yang
sudah dihapus), 10 print [JARVIS-DIAG], dan hook peluncuran JARVIS_AUTO_BUDDY.
Semuanya terjaga di riwayat git bila diperlukan lagi.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 8: Pensiunkan `Jarvis.xcodeproj`

Baru dilakukan setelah tujuh task di atas hijau, sehingga selalu ada jalan mundur selama restrukturisasi.

**Files:**
- Delete: `Jarvis.xcodeproj/`
- Modify: `.gitignore` (hapus baris yang tak lagi relevan)
- Create: `README.md` (bagian cara build)

**Interfaces:**
- Consumes: `DinoPocket.xcodeproj` yang sudah terbukti dari Task 2–7
- Produces: satu-satunya jalur build adalah `xcodegen generate` + skema `DinoPocketMac`

- [ ] **Step 1: Konfirmasi project baru berdiri sendiri dari nol**

```bash
rm -rf DinoPocket.xcodeproj
xcodegen generate
./scripts/test.sh DinoPocket DinoPocketMac
```

Expected: `** TEST SUCCEEDED **` dari project yang dihasilkan sepenuhnya dari `project.yml`.

- [ ] **Step 2: Hapus project lama**

```bash
git rm -r Jarvis.xcodeproj
```

- [ ] **Step 3: Perbarui `README.md`**

```markdown
# DinoPocket

Companion AI on-device untuk Mac — karakter 3D di desktop, chat Apple
Intelligence, dan pengingat kebiasaan sehat. Seluruhnya berjalan lokal.

> Nama produk masih codename; lihat spec §14.

## Build

Project Xcode di-generate dari `project.yml`, tidak di-commit.

```bash
brew install xcodegen      # sekali saja
xcodegen generate
open DinoPocket.xcodeproj
```

## Test

```bash
./scripts/test.sh DinoPocket DinoPocketMac
./scripts/verify-boundaries.sh
```

## Struktur

| Folder | Isi |
|---|---|
| `SharedCore/` | Bebas platform. Haram mengimpor SwiftUI/AppKit/UIKit atau memakai `#if os(`. Ditegakkan `scripts/verify-boundaries.sh` |
| `DinoPocketMac/` | Aplikasi macOS |
| `DinoPocketMac/Legacy/` | Karakter SpriteKit 2D, tidak ikut build |
| `DinoPocketTests/` | Swift Testing |
| `docs/superpowers/` | Spec dan rencana |

Jalur iOS (`ContentView.swift`, `ContentView+iOS.swift`, `Haptics.swift`,
`PetActivityWidgets.swift`, `PetWidgetsBundle.swift`, `JarvisWidget/`) ada di
repo tapi dikecualikan dari build — menunggu spec companion iPhone.
```

- [ ] **Step 4: Hapus baris usang di `.gitignore` dan test terakhir**

Hapus dua baris `git rm --cached` yang menyebut path `Jarvis.xcodeproj/xcuserdata` bila ada, lalu:

```bash
xcodegen generate && ./scripts/test.sh DinoPocket DinoPocketMac
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "build: pensiunkan Jarvis.xcodeproj, DinoPocket.xcodeproj digenerate penuh

Struktur target kini hidup di project.yml. Menambah target iOS untuk
companion nanti = beberapa baris YAML, bukan diff pbxproj ribuan baris.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 9: Verifikasi sinyal Mac di build ber-sandbox

Kriteria hijau terakhir Wave 0 (spec §3.4). Probe sebelumnya berjalan sebagai CLI **tanpa sandbox**; sandbox App Store bisa mengubah hasilnya, dan seluruh desain wellness v1 bergantung pada sinyal-sinyal ini.

**Files:**
- Create: `DinoPocketMac/Infrastructure/Services/SignalProbe.swift` (sementara, dihapus di Step 5)
- Modify: `docs/superpowers/specs/2026-08-24-dinopocket-mac-real-design.md` (§3.4 dengan hasil sandbox)

**Interfaces:**
- Consumes: aplikasi ber-sandbox dari Task 8
- Produces: catatan terverifikasi di §3.4 tentang sinyal mana yang selamat di sandbox — masukan wajib untuk `IdleTimeProviding` dan `SystemStatusProviding` di Wave 1

- [ ] **Step 1: Tambahkan probe sementara yang dipanggil saat app start**

```swift
//  SignalProbe.swift — SEMENTARA, dihapus di akhir Task 9.
//  Memverifikasi sinyal wellness mana yang selamat di App Sandbox.

import Foundation
import CoreGraphics
import IOKit.ps

enum SignalProbe {
    static func run() {
        let anyInput = CGEventType(rawValue: ~0)!
        let idle = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: anyInput)
        print("SANDBOX-PROBE idle=\(idle)")
        print("SANDBOX-PROBE thermal=\(ProcessInfo.processInfo.thermalState.rawValue)")
        print("SANDBOX-PROBE lowPower=\(ProcessInfo.processInfo.isLowPowerModeEnabled)")
        print("SANDBOX-PROBE uptime=\(ProcessInfo.processInfo.systemUptime)")

        if let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] {
            print("SANDBOX-PROBE powerSources=\(list.count)")
            for ps in list {
                if let d = IOPSGetPowerSourceDescription(blob, ps)?.takeUnretainedValue() as? [String: Any] {
                    print("SANDBOX-PROBE power state=\(d[kIOPSPowerSourceStateKey] ?? "?") capacity=\(d[kIOPSCurrentCapacityKey] ?? "?")")
                }
            }
        } else {
            print("SANDBOX-PROBE powerSources=DIBLOKIR")
        }
    }
}
```

- [ ] **Step 2: Panggil sekali saat app start**

Di `DinoPocketMac/App/JarvisApp.swift`, di dalam `init()`, setelah `WellnessNotificationCenter.shared.configure()`:

```swift
        SignalProbe.run()
```

- [ ] **Step 3: Jalankan app ber-sandbox dan tangkap keluarannya**

```bash
xcodegen generate
xcodebuild -project DinoPocket.xcodeproj -scheme DinoPocketMac -configuration Debug -derivedDataPath /tmp/dp-build build
/tmp/dp-build/Build/Products/Debug/DinoPocket.app/Contents/MacOS/DinoPocket 2>&1 | grep SANDBOX-PROBE
```

Catat sinyal mana yang mengembalikan nilai nyata dan mana yang `0`, `false`, atau `DIBLOKIR`.

- [ ] **Step 4: Tulis hasilnya ke spec §3.4**

Ganti kalimat *"Wajib diverifikasi ulang di build ber-sandbox (gelombang 0) — probe berjalan tanpa sandbox"* dengan tabel hasil sandbox yang sebenarnya. Bila ada sinyal yang diblokir, catat sebagai batasan — Wave 1 harus memetakannya jadi `nil`, **bukan** `0` (spec §7).

- [ ] **Step 5: Hapus probe**

```bash
git rm DinoPocketMac/Infrastructure/Services/SignalProbe.swift
```

Hapus juga baris `SignalProbe.run()` dari `JarvisApp.swift`.

- [ ] **Step 6: Test terakhir Wave 0**

```bash
xcodegen generate
./scripts/test.sh DinoPocket DinoPocketMac
./scripts/verify-boundaries.sh
grep -rn "#if os(" DinoPocketMac --include="*.swift" | grep -v "^DinoPocketMac/Legacy/"
```

Expected:
```
Test run with 28 tests in 6 suites passed
** TEST SUCCEEDED **
✅ batas SharedCore aman
(tidak ada output dari grep)
```

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "docs(spec): hasil verifikasi sinyal Mac di build ber-sandbox

Menutup kriteria hijau terakhir Wave 0. Probe dijalankan di dalam app
ber-sandbox, bukan CLI, lalu dihapus kembali.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Kriteria selesai Wave 0

Keempatnya harus benar bersamaan:

- [ ] `./scripts/test.sh DinoPocket DinoPocketMac` → `28 tests in 6 suites passed` · `TEST SUCCEEDED`
- [ ] `./scripts/verify-boundaries.sh` → `✅ batas SharedCore aman`
- [ ] `grep -rn "#if os(" DinoPocketMac --include="*.swift" | grep -v Legacy` → kosong
- [ ] Sinyal Mac terverifikasi di sandbox, hasilnya tercatat di spec §3.4

## Yang secara eksplisit BUKAN bagian Wave 0

Ditolak bila muncul di review — semuanya Wave 1 atau 2:

| Pekerjaan | Gelombang |
|---|---|
| Lapisan UseCase, protokol `-ing`, `AppDependencies` | 1 |
| `CharacterPresenting` / `CharacterAsset` | 1 |
| `ChatSessionStore`, persistensi transcript | 1 |
| `ScreenTimeCard` → `DeskTimeCard` | 1 |
| Tombol Esc menggantikan `stopButton` | 1 |
| Memecah `BrainTypes.swift` jadi `Data/Models` + `Data/Enums` | 1 |
| Fallback avatar saat model 3D gagal dimuat | 1 |
| Swift 5.0 → 6.0, `Sendable`, `@MainActor` | 2 |
| Rename produk, bundle id | setelah keputusan nama (spec §14) |
| Menghapus target iOS/widget dari repo | spec companion iPhone |

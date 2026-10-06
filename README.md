# Apl

Asisten desktop on-device untuk Mac: karakter 3D yang hidup di desktop, chat yang
berjalan di Mac sendiri lewat Apple Intelligence, dan pengingat yang dibuat dengan
kalimat biasa. Satu tombol memanggilnya dari app mana pun, dan sesekali ia menyapa
lebih dulu — dengan kuota, dan hanya soal hal yang memang sedang terjadi.

Seluruhnya lokal: tidak ada akun, tidak ada server, tidak ada data yang keluar dari Mac.

Nama produk final: **Apl** · bundle id `com.ega.apl` · produk build `Apl.app`.

> Nama TARGET, FOLDER, dan project (`DinoPocketMac/`, `DinoPocketTests/`,
> `DinoPocket.xcodeproj`) masih memakai codename lama. Itu disengaja: keduanya
> tidak terlihat pengguna maupun App Review, dan menggantinya berarti memindah
> direktori plus menyetel ulang skema. Sisa daftarnya ada di spec §14.

## Build

Project Xcode digenerate dari `project.yml` dan **tidak** di-commit.

```bash
brew install xcodegen      # sekali saja
xcodegen generate
open DinoPocket.xcodeproj
```

## Test

```bash
./scripts/test.sh DinoPocket DinoPocketMac   # 301 test, 55 suite
./scripts/verify-boundaries.sh               # batas SharedCore

xcodebuild test -project DinoPocket.xcodeproj -scheme AplPhone \
  -destination 'platform=iOS Simulator,name=iPhone 17'   # test iPhone, 104 test
./scripts/verify-phone-layers.sh                         # lapis AplPhone
./scripts/run-phone.sh                                   # pasang ke iPhone fisik
```

## Struktur

| Folder | Isi |
|---|---|
| `SharedCore/` | Bebas platform. Haram mengimpor SwiftUI/AppKit/UIKit atau memakai `#if os(`. Ditegakkan `scripts/verify-boundaries.sh`, bukan compiler — SharedCore adalah folder, bukan framework |
| `DinoPocketMac/` | Aplikasi macOS |
| `DinoPocketMac/Legacy/` | Karakter SpriteKit 2D, tidak ikut build |
| `DinoPocketTests/` | Swift Testing |
| `AplPhone/` | Companion iPhone (spec H): Domain / Data / Presentation, ditegakkan `scripts/verify-phone-layers.sh`. Sebagian logikanya **kembaran** dari `DinoPocketMac/` — daftar di spec H §3.1 |
| `AplPhoneTests/` | Swift Testing, simulator iOS 26 |
| `docs/superpowers/` | Spec dan rencana |

Jalur iOS (`ContentView.swift`, `ContentView+iOS.swift`, `ContentView+macOS.swift`,
`Haptics.swift`, `PetActivityWidgets.swift`) ada di repo tapi dikecualikan dari build —
menunggu spec companion iPhone. `JarvisWidget/` dan `JarvisUITests/` dihapus di
sub-project D: keduanya tidak pernah disebut `project.yml`.

## Dokumen

- Spec: `docs/superpowers/specs/2026-08-24-dinopocket-mac-real-design.md`
- Rencana Wave 0: `docs/superpowers/plans/2026-08-24-wave0-taggo-restructure.md`

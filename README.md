# Apl

Companion AI on-device untuk Mac — karakter 3D di desktop, chat Apple Intelligence,
dan pengingat kebiasaan sehat. Seluruhnya berjalan lokal, tanpa server.

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
./scripts/test.sh DinoPocket DinoPocketMac   # 90 test, 19 suite
./scripts/verify-boundaries.sh               # batas SharedCore
```

## Struktur

| Folder | Isi |
|---|---|
| `SharedCore/` | Bebas platform. Haram mengimpor SwiftUI/AppKit/UIKit atau memakai `#if os(`. Ditegakkan `scripts/verify-boundaries.sh`, bukan compiler — SharedCore adalah folder, bukan framework |
| `DinoPocketMac/` | Aplikasi macOS |
| `DinoPocketMac/Legacy/` | Karakter SpriteKit 2D, tidak ikut build |
| `DinoPocketTests/` | Swift Testing |
| `docs/superpowers/` | Spec dan rencana |

Jalur iOS (`ContentView.swift`, `ContentView+iOS.swift`, `ContentView+macOS.swift`,
`Haptics.swift`, `PetActivityWidgets.swift`, `JarvisWidget/`) ada di repo tapi
dikecualikan dari build — menunggu spec companion iPhone.

## Dokumen

- Spec: `docs/superpowers/specs/2026-08-24-dinopocket-mac-real-design.md`
- Rencana Wave 0: `docs/superpowers/plans/2026-08-24-wave0-taggo-restructure.md`

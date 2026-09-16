# Apl — Jendela Utama Chat-First (Sub-project B) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ganti dashboard sementara dengan jendela utama layout **A · Companion stage** (robot 3D yang bereaksi, Up next, percakapan Markdown, composer), plus onboarding tanpa akun dan jendela Settings (⌘,), di atas fondasi A yang sudah hijau.

**Architecture:** Logika dibangun lebih dulu sebagai unit murni yang dites: token desain, `ChatMessage` dengan lampiran dan status, `ChatStore` yang mencatat kejadian, `CharacterMoodResolver`, `CharacterExpressionCache`, `ReminderListViewModel`, `MarkdownBlocks`, dan `ComposerState`. View dibangun di atasnya per fitur (Chat, Stage, Window, Settings, Onboarding). Tiap view tipis dan punya `#Preview`. `MainWindow` baru disambungkan di Task 11, dan view lama dihapus di task yang sama supaya build tidak pernah merah.

**Tech Stack:** Swift 6, SwiftUI (macOS 26.2), RealityKit, Foundation Models, UserNotifications, Swift Testing, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-09-15-apl-main-window-design.md` (fondasi: `docs/superpowers/specs/2026-09-15-apl-foundation-design.md`, rencana A: `docs/superpowers/plans/2026-09-16-apl-foundation.md`)

## Global Constraints

- Repo: `/Users/egaaaa/Documents/DinoPocket`, branch `refactor/taggo-architecture`, dimulai dari `de16eba` (A selesai). Semua perintah dijalankan dari root repo. **Jangan push atau merge.**
- `DinoPocket.xcodeproj` di-gitignore dan dibuat oleh XcodeGen. **Setiap kali file Swift atau aset ditambah, dihapus, atau dipindah, jalankan `xcodegen generate` sebelum build/test.**
- Build: `xcodebuild build -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS,arch=arm64' 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"`
- Test semua: `xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS,arch=arm64' 2>&1 | grep -E "Test run with|TEST (SUCCEEDED|FAILED)|error:|✘"`
- Test satu suite: tambahkan `-only-testing:DinoPocketTests/<NamaStruct>` pada perintah test.
- Menjalankan dan memotret app: lihat "Alat verifikasi manual" di bawah.
- Nama modul app adalah `Apl`; test memakai `@testable import Apl`. Test host-nya `Apl.app`, jadi **test tidak boleh menulis ke `UserDefaults.standard`**. Pakai suite terisolasi (`UserDefaults(suiteName:)` + `removePersistentDomain`).
- Target **macOS 26.2**, `SWIFT_VERSION` 6.0, `SWIFT_APPROACHABLE_CONCURRENCY` YES. Tidak ada `static let` bertipe non-`Sendable`. Konstanta `static let` di tipe `@MainActor` yang dipakai dari luar actor ditandai `nonisolated`.
- Blok `#Preview` ikut dikompilasi di Release, jadi helper preview **tidak boleh** dibungkus `#if DEBUG`. Satu-satunya kode khusus DEBUG adalah tab Debug beserta `DebugAvailabilityBrain`.
- `SharedCore/` tidak boleh `import SwiftUI`/`AppKit`/`UIKit` dan tidak boleh `#if os(`. Dijaga oleh `scripts/verify-boundaries.sh`.
- **Copy UI dalam bahasa Inggris** (spec B §7). Komentar kode dan pesan commit dalam bahasa Indonesia, mengikuti gaya repo.
- Nilai layout dari spec B §5:
  - Jendela: awal 1000×680, minimum 720×520.
  - Stage: 320pt dengan inset 8pt dan radius 12. Di bawah 820pt diganti `CompactStageHeader`.
  - Header percakapan 52pt, padding kolom pesan 24pt.
  - Bubble pengguna maks. 420pt, teks asisten maks. 460pt.
  - Composer: kapsul 40pt, tombol kirim 28pt.
- Token dari spec B §7:
  - `AccentColor` dark `#5EC4D6`, light `#127A8A`.
  - `userBubble` 16% / 12%, `stageGlow` 20% / 12%.
  - Status memakai `systemGreen` / `systemOrange`.
  - Radius 7 / 8 / 12, spacing 4 / 8 / 12 / 16 / 24.
- Setiap view baru punya `#Preview` untuk state utamanya, dalam light dan dark.
- **Tidak ada test yang memanggil Apple Intelligence sungguhan.** `Brain` selalu di-mock.
- B **tidak** membuat placeholder untuk C: tidak ada tombol speaker, tidak ada tab Voice/Shortcut. Tampilan Buddy tidak berubah, selain ikut memakai cache ekspresi.
- Jangan sentuh file yang dibekukan: `DinoPocketMac/Presentation/Views/ContentView.swift`, `ContentView+iOS.swift`, `ContentView+macOS.swift`, `PetActivityWidgets.swift`, `DinoPocketMac/Infrastructure/Services/Haptics.swift`, `JarvisWidget/`, `DinoPocketMac/Legacy/`. Setelah B, `Presentation/Views/` hanya berisi file-file beku ini.
- **Jangan ubah pengaturan sistem macOS** (izin notifikasi, Reduce Motion, VoiceOver, Apple Intelligence, tampilan) dan jangan klik dialog izin sistem. Mode gelap/terang untuk verifikasi dipaksa lewat argumen peluncuran app.
- Setiap commit hanya memuat file task itu dan diakhiri trailer `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.
- Jumlah test yang disebut di tiap task adalah hitungan perkiraan (A berakhir di 90 test dalam 19 suite). Yang wajib adalah `** TEST SUCCEEDED **`.

## Alat verifikasi manual

**Jalankan app** (Debug, setelah build). `-AppleInterfaceStyle` hanya berlaku untuk proses Apl, bukan untuk sistem:

```bash
APP_DIR=$(xcodebuild -project DinoPocket.xcodeproj -scheme DinoPocketMac -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{print $2; exit}')
pkill -x Apl; open -n "$APP_DIR/Apl.app" --args -AppleInterfaceStyle Dark   # atau Light
```

**Potret jendela utama.** Skripnya dibuat sekali. Yang dipilih adalah jendela Apl terbesar di layer 0, jadi jendela Buddy tidak ikut terpotret.

```bash
cat > "$TMPDIR/apl-winid.swift" <<'EOF'
import CoreGraphics
import Foundation

func area(_ window: [String: Any]) -> CGFloat {
    guard let bounds = window[kCGWindowBounds as String] as? NSDictionary,
          let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return 0 }
    return rect.width * rect.height
}

let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
let main = windows
    .filter { ($0[kCGWindowOwnerName as String] as? String) == "Apl" && ($0[kCGWindowLayer as String] as? Int) == 0 }
    .max { area($0) < area($1) }
print(main?[kCGWindowNumber as String] as? Int ?? 0)
EOF

screencapture -x -o -l "$(swift "$TMPDIR/apl-winid.swift")" "$TMPDIR/apl-<nama>.png"
```

Setelah itu buka PNG-nya dan **lihat isinya**. Bingkai kosong berarti gagal.

**Interaksi.** Klik via CGEvent tidak bekerja di Mac ini. Untuk menekan tombol, gunakan aksi Accessibility `AXPress`. Untuk mengetik dan menekan tombol keyboard, gunakan System Events:

```bash
osascript -e 'tell application "Apl" to activate' \
  -e 'tell application "System Events" to keystroke "remind me to stretch in 2 minutes"' \
  -e 'tell application "System Events" to key code 36'   # Return
osascript -e 'tell application "System Events" to tell process "Apl" to set size of front window to {740, 520}'
```

## Deviasi yang disengaja dari spec B

Semua deviasi di bawah juga dicatat di spec B §13.

1. **Aksen merek memakai `Color("AccentColor")`, bukan `Color.accentColor`.** Di macOS, accent yang dipilih pengguna di System Settings menimpa accent app. Kontrol sistem tetap mengikuti pilihan pengguna, sedangkan elemen merek (bubble, glow, tombol kirim) tetap teal.
2. **Teks status `.sleepy` bergantung penyebabnya.** Saat stream gagal, teksnya "Something went wrong". "Apple Intelligence is off" hanya dipakai bila AI memang mati.
3. **⇧Return menambah baris baru di akhir draft.** SwiftUI tidak memberi akses ke posisi kursor. ⌥Return (bawaan field editor macOS) tetap menyisipkan baris di posisi kursor.
4. **Clear Conversation dan Erase All Data juga mengosongkan sesi Apple Intelligence** (`Brain.resetConversation()`). Tanpa ini, model tetap ingat percakapan yang sudah dihapus dari layar dan menyimpannya lagi ke disk.
5. **`ChatStore` menerima `defaults` dan `now`.** Tujuannya agar test tidak menulis ke data app sungguhan dan waktu kejadian bisa diuji.
6. **Pesan yang dihentikan memakai `status: .stopped`**, menggantikan sufiks teks " (cancelled)".
7. **Folder `Presentation` ditata per fitur:** `DesignSystem`, `Components`, `Chat`, `Stage`, `Window`, `Settings`, `Onboarding`, `Character`, `ViewModels`.
8. **Kategori App Store** (masih Health & Fitness) diserahkan ke sub-project D.
9. **`AIUnavailableBanner` tampil di atas composer, tidak menggantikannya.** Saat AI mati, composer tetap terbuka supaya reminder lewat chat tetap bisa dibuat. Pesan lain dijawab dengan `noticeMessage` yang tampil di bawah percakapan, bukan di dalam teks pesan. Composer hanya dikunci saat model sedang disiapkan ("Getting ready…"), sesuai spec §9.
10. **Jendela momen 3 detik berlaku setengah terbuka, `[t, t+3)`.** Tepat di detik ke-3 momen sudah berakhir. Dengan `≤`, evaluasi ulang di detik ke-3 akan menghasilkan jadwal yang sama dan karakter tertahan di ekspresi itu.
11. **Animasi robot di jendela utama dijeda saat jendela tidak aktif** (`appearsActive == false`) **atau Low Power Mode menyala.** SwiftUI tidak punya sinyal "tertutup jendela lain" yang andal (mitigasi spec §12).
12. **`ReminderChip` punya status ketiga, "Reminder passed".** Status ini dipakai untuk reminder sekali jalan yang sudah lewat atau sudah dibuang karena lewat lebih dari sehari. Spec hanya mendefinisikan status terjadwal dan "Reminder removed".
13. **`CompactStageHeader` punya tombol lonceng** yang membuka popover reminder, karena Up next tidak terlihat dalam mode compact.
14. **Clear Conversation memakai shortcut ⌘K.**

## Peta berkas

| Berkas | Tanggung jawab | Task |
|---|---|---|
| `DinoPocketMac/Assets.xcassets/AccentColor.colorset/Contents.json` | Aksen merek light/dark | 1 |
| `DinoPocketMac/Presentation/DesignSystem/AppColors.swift` (pindah), `Spacing.swift` (pindah), `Radius.swift`, `AppFont.swift` | Token desain | 1 |
| `DinoPocketMac/Presentation/Components/StatusDot.swift` (pindah), `IconButton.swift`, `StageButton.swift` | Komponen reusable | 1, 9 |
| `SharedCore/Data/Models/ChatMessage.swift` | `Attachment`, `Status`, decoding toleran | 2 |
| `DinoPocketMac/Presentation/ViewModels/ChatEvent.swift` | Kejadian chat untuk karakter | 3 |
| `DinoPocketMac/Presentation/ViewModels/ChatStore.swift` | Kejadian, lampiran, gagal/stop/retry/clear | 3, 4 |
| `SharedCore/Infrastructure/Services/Brain.swift`, `AppleBrain.swift` | `resetConversation()` | 4 |
| `DinoPocketMac/Presentation/Character/CharacterMoodResolver.swift` | Prioritas ekspresi, murni | 5 |
| `DinoPocketMac/Presentation/Character/CharacterStatusText.swift` | Teks status + label VoiceOver | 5 |
| `DinoPocketMac/Presentation/Character/CharacterExpressionCache.swift` | Muat USDZ sekali, bagikan salinan | 6 |
| `DinoPocketMac/Presentation/Character/USDZCharacterView.swift` | Pakai cache, pop, Reduce Motion, jeda | 6 |
| `SharedCore/Infrastructure/Services/ReminderScheduling.swift`, `ReminderNotificationCenter.swift` | `notificationsAllowed()` | 7 |
| `DinoPocketMac/Presentation/ViewModels/ReminderListViewModel.swift` | Up next, batal, undo, edit, chip | 7 |
| `DinoPocketMac/Presentation/PreviewSupport.swift` | Data dan store palsu untuk `#Preview` | 7 |
| `DinoPocketMac/Presentation/Chat/MarkdownBlocks.swift` | Pemisah teks/blok kode, toleran stream | 8 |
| `DinoPocketMac/Presentation/Chat/MessageViews.swift`, `ReminderChip.swift`, `MessageRow.swift` | Tampilan pesan | 8 |
| `DinoPocketMac/Presentation/Chat/ComposerState.swift`, `Composer.swift`, `AIUnavailableBanner.swift` | Kolom tulis dan banner AI | 9 |
| `DinoPocketMac/Presentation/Stage/ReminderDraft.swift`, `ReminderEditor.swift`, `RemindersPopover.swift`, `UpNextList.swift`, `StatusLine.swift`, `CharacterStage.swift`, `CompactStageHeader.swift` | Stage | 10 |
| `DinoPocketMac/Presentation/Window/MainWindowLayout.swift`, `MainWindow.swift`, `ConversationCommands.swift`, `DinoPocketMac/Presentation/Chat/ConversationView.swift` | Jendela utama + menu Conversation | 11 |
| `DinoPocketMac/App/AplApp.swift`, `AppDependencies.swift` | Wiring scene | 11, 12, 13 |
| `DinoPocketMac/Presentation/Settings/SettingsWindow.swift`, `DebugSettingsTab.swift` | Jendela Settings (⌘,) | 12 |
| `DinoPocketMac/Infrastructure/Services/DebugAvailabilityBrain.swift` | Paksa availability (DEBUG) | 12 |
| `DinoPocketMac/Presentation/Onboarding/OnboardingView.swift` (pindah) | Onboarding 3 langkah | 13 |
| Dihapus: `Presentation/Views/DashboardTemplate.swift`, `SidebarView.swift`, `ChatPage.swift`, `MessageBubble.swift`, `AIUnavailableCard.swift`, `SettingsPage.swift` | Digantikan | 11, 12 |

---

### Task 1: Token desain dan `AccentColor`

**Files:**
- Create: `DinoPocketMac/Assets.xcassets/Contents.json`
- Create: `DinoPocketMac/Assets.xcassets/AccentColor.colorset/Contents.json`
- Modify: `project.yml` (target `DinoPocketMac` → `settings.base`)
- Move: `DinoPocketMac/Presentation/Views/AppColors.swift` → `DinoPocketMac/Presentation/DesignSystem/AppColors.swift` (lalu ditulis ulang)
- Move: `DinoPocketMac/Presentation/Views/Spacing.swift` → `DinoPocketMac/Presentation/DesignSystem/Spacing.swift`
- Move: `DinoPocketMac/Presentation/Views/StatusDot.swift` → `DinoPocketMac/Presentation/Components/StatusDot.swift` (default warna diganti)
- Create: `DinoPocketMac/Presentation/DesignSystem/Radius.swift`, `DinoPocketMac/Presentation/DesignSystem/AppFont.swift`
- Test: `DinoPocketTests/DesignTokenTests.swift`

**Interfaces:**
- Consumes: —
- Produces:
  - `enum AppColor` dengan `static var`: `accent: Color`, `userBubbleNSColor: NSColor`, `userBubble: Color`, `stageGlowNSColor: NSColor`, `stageGlow: Color`, `statusOK: Color`, `statusWarning: Color`, `raisedSurface: Color`, `controlFill: Color`, `card: Color`. `online` dan `groupedBackground` dihapus.
  - `enum Radius { static let iconButton: CGFloat = 7; static let control: CGFloat = 8; static let card: CGFloat = 12 }`
  - `enum AppFont { static func title(_ size: CGFloat) -> Font; static var code: Font }`
  - `Spacing` tetap: `xs 4`, `sm 8`, `md 12`, `lg 16`, `xl 24`
  - `StatusDot(color: Color = AppColor.statusOK)`

- [ ] **Step 1: Tulis test token yang gagal**

Buat `DinoPocketTests/DesignTokenTests.swift`:

```swift
import AppKit
import Testing
@testable import Apl

/// Token warna diperiksa di kedua tampilan: mockup hanya digambar dalam dark,
/// jadi light mode paling mudah meleset tanpa ada yang sadar (spec B §12).
@MainActor
struct DesignTokenTests {

    private struct RGBA: Equatable {
        let red: Int
        let green: Int
        let blue: Int
        let alpha: Double
    }

    private static let darkAccent = (red: 0x5E, green: 0xC4, blue: 0xD6)
    private static let lightAccent = (red: 0x12, green: 0x7A, blue: 0x8A)

    private func resolved(_ color: NSColor, in name: NSAppearance.Name) -> RGBA? {
        var result: RGBA?
        NSAppearance(named: name)?.performAsCurrentDrawingAppearance {
            guard let rgb = color.usingColorSpace(.sRGB) else { return }
            result = RGBA(red: Int((rgb.redComponent * 255).rounded()),
                          green: Int((rgb.greenComponent * 255).rounded()),
                          blue: Int((rgb.blueComponent * 255).rounded()),
                          alpha: (Double(rgb.alphaComponent) * 100).rounded() / 100)
        }
        return result
    }

    private func accent(_ tone: (red: Int, green: Int, blue: Int), alpha: Double) -> RGBA {
        RGBA(red: tone.red, green: tone.green, blue: tone.blue, alpha: alpha)
    }

    @Test func accentComesFromTheAssetCatalogInBothAppearances() throws {
        let brand = try #require(NSColor(named: "AccentColor"))
        #expect(resolved(brand, in: .darkAqua) == accent(Self.darkAccent, alpha: 1))
        #expect(resolved(brand, in: .aqua) == accent(Self.lightAccent, alpha: 1))
    }

    @Test func userBubbleIsTheAccentAtSixteenAndTwelvePercent() {
        #expect(resolved(AppColor.userBubbleNSColor, in: .darkAqua) == accent(Self.darkAccent, alpha: 0.16))
        #expect(resolved(AppColor.userBubbleNSColor, in: .aqua) == accent(Self.lightAccent, alpha: 0.12))
    }

    @Test func stageGlowIsTheAccentAtTwentyAndTwelvePercent() {
        #expect(resolved(AppColor.stageGlowNSColor, in: .darkAqua) == accent(Self.darkAccent, alpha: 0.20))
        #expect(resolved(AppColor.stageGlowNSColor, in: .aqua) == accent(Self.lightAccent, alpha: 0.12))
    }
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS,arch=arm64' -only-testing:DinoPocketTests/DesignTokenTests 2>&1 | grep -E "Test run with|TEST (SUCCEEDED|FAILED)|error:|✘"`
Expected: FAIL, dengan `error: type 'AppColor' has no member 'userBubbleNSColor'`.

- [ ] **Step 3: Tambahkan `AccentColor` ke asset catalog**

Buat `DinoPocketMac/Assets.xcassets/Contents.json`:

```json
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

Buat `DinoPocketMac/Assets.xcassets/AccentColor.colorset/Contents.json`:

```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0x8A",
          "green" : "0x7A",
          "red" : "0x12"
        }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0xD6",
          "green" : "0xC4",
          "red" : "0x5E"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

Di `project.yml`, pada `targets.DinoPocketMac.settings.base`, tepat di bawah baris `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`, tambahkan:

```yaml
        # Aksen merek (spec B §7). Toggle, focus ring, dan tombol default ikut
        # teal tanpa kode tambahan — kecuali pengguna memilih accent sendiri di
        # System Settings, yang memang harus dihormati kontrol sistem.
        ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor
```

- [ ] **Step 4: Pindahkan token ke folder fitur**

```bash
mkdir -p DinoPocketMac/Presentation/DesignSystem DinoPocketMac/Presentation/Components
git mv DinoPocketMac/Presentation/Views/AppColors.swift DinoPocketMac/Presentation/DesignSystem/AppColors.swift
git mv DinoPocketMac/Presentation/Views/Spacing.swift DinoPocketMac/Presentation/DesignSystem/Spacing.swift
git mv DinoPocketMac/Presentation/Views/StatusDot.swift DinoPocketMac/Presentation/Components/StatusDot.swift
```

- [ ] **Step 5: Tulis ulang `AppColors.swift`**

Ganti seluruh isi `DinoPocketMac/Presentation/DesignSystem/AppColors.swift`:

```swift
//
//  AppColors.swift
//  Apl
//
//  Token warna (spec B §7). Warna semantik sistem dipakai di mana pun bisa;
//  token custom hanya turunan aksen merek dan warna status.
//

import AppKit
import SwiftUI

enum AppColor {

    /// Aksen merek dari asset catalog.
    ///
    /// SENGAJA bukan `Color.accentColor`: di macOS, accent yang dipilih pengguna
    /// di System Settings › Appearance menimpa accent app, sehingga bubble,
    /// glow, dan tombol kirim bisa berubah ungu. Kontrol sistem tetap mengikuti
    /// pilihan pengguna — itu memang benar.
    static var accent: Color { Color("AccentColor") }

    /// Bubble pengguna: aksen 16% (dark) / 12% (light).
    static var userBubbleNSColor: NSColor { accentTint(dark: 0.16, light: 0.12) }
    static var userBubble: Color { Color(nsColor: userBubbleNSColor) }

    /// Glow di belakang robot: aksen 20% (dark) / 12% (light).
    static var stageGlowNSColor: NSColor { accentTint(dark: 0.20, light: 0.12) }
    static var stageGlow: Color { Color(nsColor: stageGlowNSColor) }

    static var statusOK: Color { Color(nsColor: .systemGreen) }
    static var statusWarning: Color { Color(nsColor: .systemOrange) }

    /// Panel stage: sedikit berbeda dari latar jendela di kedua tampilan.
    static var raisedSurface: Color { Color(nsColor: .underPageBackgroundColor) }
    /// Isi kontrol ringan: composer, chip, blok kode.
    static var controlFill: Color { Color(nsColor: .quaternarySystemFill) }
    static var card: Color { Color(nsColor: .controlBackgroundColor) }

    /// Aksen dengan alpha berbeda per tampilan. Provider dipanggil ulang setiap
    /// kali sistem me-resolve warna, jadi hasilnya ikut berganti saat
    /// light/dark berubah. Aksen di-resolve di dalam `appearance` yang diminta,
    /// bukan tampilan yang kebetulan sedang aktif.
    private static func accentTint(dark: CGFloat, light: CGFloat) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            var base = NSColor.controlAccentColor
            appearance.performAsCurrentDrawingAppearance {
                if let brand = NSColor(named: "AccentColor")?.usingColorSpace(.sRGB) {
                    base = brand
                }
            }
            return base.withAlphaComponent(isDark ? dark : light)
        }
    }
}
```

- [ ] **Step 6: Tambahkan `Radius` dan `AppFont`, perbarui `StatusDot`**

Buat `DinoPocketMac/Presentation/DesignSystem/Radius.swift`:

```swift
//
//  Radius.swift
//  Apl
//
//  Skala radius sudut (spec B §7). Composer memakai kapsul, bukan token ini.
//

import CoreGraphics

enum Radius {
    /// Tombol ikon.
    static let iconButton: CGFloat = 7
    /// Kontrol dan blok kode.
    static let control: CGFloat = 8
    /// Bubble, card, dan stage.
    static let card: CGFloat = 12
}
```

Buat `DinoPocketMac/Presentation/DesignSystem/AppFont.swift`:

```swift
//
//  AppFont.swift
//  Apl
//
//  Tipografi (spec B §7). Teks biasa memakai text style sistem; hanya judul
//  dan kode yang punya gaya sendiri.
//

import SwiftUI

enum AppFont {
    /// Judul berkarakter: SF Pro Rounded, semibold.
    static func title(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static var code: Font {
        .system(.body, design: .monospaced)
    }
}
```

Di `DinoPocketMac/Presentation/Components/StatusDot.swift`, ganti baris

```swift
    var color: Color = AppColor.online
```

menjadi

```swift
    var color: Color = AppColor.statusOK
```

lalu ganti blok `#Preview` di bawahnya dengan:

```swift
#Preview("Light") {
    HStack(spacing: Spacing.sm) {
        StatusDot()
        StatusDot(color: AppColor.statusWarning)
    }
    .padding()
}

#Preview("Dark") {
    HStack(spacing: Spacing.sm) {
        StatusDot()
        StatusDot(color: AppColor.statusWarning)
    }
    .padding()
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 7: Jalankan test, pastikan lulus, lalu build penuh**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS,arch=arm64' -only-testing:DinoPocketTests/DesignTokenTests 2>&1 | grep -E "Test run with|TEST (SUCCEEDED|FAILED)|error:|✘"`
Expected: `Test run with 3 tests` … `** TEST SUCCEEDED **`

Run: perintah build dari Global Constraints.
Expected: `** BUILD SUCCEEDED **`. `ChatPage` dan `MessageBubble` masih memakai `AppColor.card` dan `AppColor.accent`, dan keduanya masih ada.

- [ ] **Step 8: Commit**

```bash
# Pemindahan dari Presentation/Views sudah di-stage oleh `git mv` di Step 4.
git add project.yml DinoPocketMac/Assets.xcassets/Contents.json DinoPocketMac/Assets.xcassets/AccentColor.colorset \
  DinoPocketMac/Presentation/DesignSystem DinoPocketMac/Presentation/Components \
  DinoPocketTests/DesignTokenTests.swift
git status --short   # harus berisi hanya berkas task ini (R = rename)
git commit -m "$(cat <<'EOF'
feat(b1): token desain dan AccentColor teal

AccentColor (#127A8A / #5EC4D6) masuk asset catalog dan dipasang sebagai
accent global. AppColor mendapat userBubble dan stageGlow yang dihitung
dari aksen per tampilan, warna status, dan permukaan; token lama yang
tidak dipakai dihapus. Radius dan AppFont ditambahkan, dan token
dipindah ke Presentation/DesignSystem.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: `ChatMessage` dengan lampiran dan status

**Files:**
- Modify: `SharedCore/Data/Models/ChatMessage.swift`
- Test: `DinoPocketTests/ChatMessageTests.swift`

**Interfaces:**
- Consumes: —
- Produces:
  - `ChatMessage.Attachment: Codable, Equatable { case reminder(UUID) }`
  - `ChatMessage.Status: String, Codable { case complete, failed, stopped }`
  - `var attachment: Attachment?`, `var status: Status`
  - `init(id: UUID = UUID(), role: Role, text: String, date: Date = .now, attachment: Attachment? = nil, status: Status = .complete)`. Pemanggil lama yang menulis `id:` dan `date:` tetap terkompilasi.
  - Decoding: `attachment` dan `status` boleh tidak ada (default `nil` / `.complete`)

- [ ] **Step 1: Tulis test yang gagal**

Buat `DinoPocketTests/ChatMessageTests.swift`:

```swift
import Foundation
import Testing
@testable import Apl

struct ChatMessageTests {

    @Test func attachmentAndStatusSurviveARoundTrip() throws {
        let message = ChatMessage(role: .assistant, text: "Done", date: TestTime.now,
                                  attachment: .reminder(UUID()), status: .stopped)

        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)

        #expect(decoded == message)
    }

    /// Percakapan yang tersimpan sebelum B tidak punya kedua kunci baru.
    /// Kalau decoding-nya gagal, seluruh riwayat lenyap diam-diam saat app dibuka.
    @Test func messagesSavedBeforeAttachmentsStillDecode() throws {
        let stored = """
        [{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","role":"user","text":"hi","date":800000000}]
        """

        let decoded = try JSONDecoder().decode([ChatMessage].self, from: Data(stored.utf8))

        #expect(decoded.count == 1)
        #expect(decoded[0].text == "hi")
        #expect(decoded[0].attachment == nil)
        #expect(decoded[0].status == .complete)
    }
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS,arch=arm64' -only-testing:DinoPocketTests/ChatMessageTests 2>&1 | grep -E "Test run with|TEST (SUCCEEDED|FAILED)|error:|✘"`
Expected: FAIL, dengan `error: extra arguments at positions #4, #5 in call` atau `value of type 'ChatMessage' has no member 'attachment'`.

- [ ] **Step 3: Tulis ulang `ChatMessage`**

Ganti seluruh isi `SharedCore/Data/Models/ChatMessage.swift`:

```swift
//
//  ChatMessage.swift
//  SharedCore
//

import Foundation

struct ChatMessage: Identifiable, Codable, Equatable {

    enum Role: String, Codable { case user, assistant }

    /// Data yang menempel pada pesan, supaya UI merender dari fakta — chip
    /// reminder tidak ditebak dari bunyi teks konfirmasi (spec B §6).
    enum Attachment: Codable, Equatable {
        case reminder(UUID)
    }

    /// Nasib jawaban. Kegagalan dan penghentian dicatat di sini, bukan
    /// ditulis sebagai teks peringatan di dalam isi pesan.
    enum Status: String, Codable {
        case complete
        case failed
        case stopped
    }

    let id: UUID
    let role: Role
    var text: String
    let date: Date
    var attachment: Attachment?
    var status: Status

    init(id: UUID = UUID(), role: Role, text: String, date: Date = .now,
         attachment: Attachment? = nil, status: Status = .complete) {
        self.id = id
        self.role = role
        self.text = text
        self.date = date
        self.attachment = attachment
        self.status = status
    }

    private enum CodingKeys: String, CodingKey {
        case id, role, text, date, attachment, status
    }

    /// Kunci baru boleh tidak ada: percakapan yang tersimpan sebelum B tetap
    /// terbaca. `encode(to:)` tetap disintesis.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        role = try container.decode(Role.self, forKey: .role)
        text = try container.decode(String.self, forKey: .text)
        date = try container.decode(Date.self, forKey: .date)
        attachment = try container.decodeIfPresent(Attachment.self, forKey: .attachment)
        status = try container.decodeIfPresent(Status.self, forKey: .status) ?? .complete
    }
}
```

- [ ] **Step 4: Jalankan test, pastikan lulus**

Run: perintah Step 2.
Expected: `Test run with 2 tests` … `** TEST SUCCEEDED **`

- [ ] **Step 5: Jalankan seluruh test**

Run: perintah test semua.
Expected: `** TEST SUCCEEDED **` (±95 test).

- [ ] **Step 6: Commit**

```bash
git add SharedCore/Data/Models/ChatMessage.swift DinoPocketTests/ChatMessageTests.swift
git commit -m "$(cat <<'EOF'
feat(b2): ChatMessage membawa lampiran reminder dan status

Chip reminder dirender dari attachment, bukan dari bunyi teks, dan
kegagalan atau penghentian dicatat sebagai status alih-alih teks
peringatan. Pesan yang tersimpan tanpa kedua kunci itu tetap terbaca.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: `ChatStore` mencatat kejadian dan melampirkan reminder

**Files:**
- Create: `DinoPocketMac/Presentation/ViewModels/ChatEvent.swift`
- Modify: `DinoPocketMac/Presentation/ViewModels/ChatStore.swift`
- Test: `DinoPocketTests/ChatStoreTests.swift` (ditulis ulang)

**Interfaces:**
- Consumes: `ChatMessage.Attachment`, `ChatMessage.init(id:role:text:date:attachment:status:)` (Task 2)
- Produces:
  - `struct ChatEvent: Equatable, Sendable { enum Kind: Equatable, Sendable { case reminderCreated(Reminder.ID); case failed }; let kind: Kind; let at: Date }`
  - `ChatStore.init(brain: Brain?, defaults: UserDefaults = .standard, now: @escaping () -> Date = { .now })`
  - `nonisolated static let ChatStore.recentKey = "jarvis.chat.recent"`
  - `private(set) var ChatStore.lastEvent: ChatEvent?`
  - Pesan konfirmasi reminder membawa `attachment: .reminder(id)`. Pertanyaan "jam berapa?" tidak membawa lampiran.

- [ ] **Step 1: Tulis ulang `ChatStoreTests` dengan test baru yang gagal**

Ganti seluruh isi `DinoPocketTests/ChatStoreTests.swift`. Test lama dipertahankan, tetapi masing-masing memakai `UserDefaults` sendiri, sehingga `.serialized` tidak diperlukan lagi.

```swift
import Foundation
import Testing
@testable import Apl

private struct StubBrain: Brain {
    var chunks: [String]
    var available: BrainAvailability = .ready
    func availability() async -> BrainAvailability { available }
    func reply(to history: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { c in
            for chunk in chunks { c.yield(chunk) }
            c.finish()
        }
    }
}

/// A Brain whose stream stays open until the test explicitly finishes it.
/// This lets a test deterministically overlap two `send()` calls: start
/// call N, wait until its stream has actually begun (no sleeps/polling —
/// `reply()` runs synchronously the moment the consuming Task reaches the
/// `for try await` line, which only happens after ChatStore has already
/// mutated all the shared state we want to assert on), then drive
/// completion of each call's stream at a time of the test's choosing.
private final class GatedBrain: Brain, @unchecked Sendable {
    var available: BrainAvailability = .ready
    private var continuations: [AsyncThrowingStream<String, Error>.Continuation] = []
    private var starters: [CheckedContinuation<Void, Never>] = []
    private var startedCount = 0

    func availability() async -> BrainAvailability { available }

    func reply(to history: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            self.continuations.append(continuation)
            self.startedCount += 1
            if !self.starters.isEmpty { self.starters.removeFirst().resume() }
        }
    }

    /// Suspends until the Nth (1-based) call to `reply` has begun.
    func waitUntilStreamStarted(_ n: Int) async {
        if startedCount >= n { return }
        await withCheckedContinuation { starters.append($0) }
    }

    /// Completes the Nth (1-based) call's stream, optionally yielding chunks first.
    func finishStream(_ n: Int, with chunks: [String] = []) {
        guard continuations.indices.contains(n - 1) else { return }
        for chunk in chunks { continuations[n - 1].yield(chunk) }
        continuations[n - 1].finish()
    }

    /// Fails the Nth (1-based) call's stream with an error, without yielding chunks.
    func throwStream(_ n: Int) {
        guard continuations.indices.contains(n - 1) else { return }
        continuations[n - 1].finish(throwing: StubStreamError())
    }
}

private struct StubStreamError: Error {}

/// Test host-nya Apl.app: tanpa suite sendiri, test menulis riwayat chat ke
/// data app sungguhan dan saling memuat pesan milik test lain.
private func isolatedDefaults(_ name: String) -> UserDefaults {
    let suite = "test.chat.\(name)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}

struct ChatStoreTests {
    @MainActor @Test func sendAppendsUserAndStreamedAssistantMessage() async {
        let store = ChatStore(brain: StubBrain(chunks: ["A", "AB", "ABC"]),
                              defaults: isolatedDefaults(#function))
        await store.send("halo")
        #expect(store.messages.count == 2)
        #expect(store.messages[0].role == .user)
        #expect(store.messages[1].role == .assistant)
        #expect(store.messages[1].text == "ABC")
        #expect(store.isStreaming == false)
    }

    @MainActor @Test func unavailableAppleIntelligenceLeavesANoticeAndNoReply() async {
        let store = ChatStore(brain: StubBrain(chunks: ["X"], available: .unavailable("nope")),
                              defaults: isolatedDefaults(#function))

        await store.send("tes")

        #expect(store.messages.map(\.role) == [.user])
        #expect(store.noticeMessage != nil)
    }

    /// Overlapping sends: a second `send()` arrives while the first is still
    /// streaming. Covers both cancellation findings deterministically:
    /// - FINDING 2: the first call's empty assistant placeholder must be
    ///   removed before the second user message is appended, and must not
    ///   appear in the history captured for the second `brain.reply(...)`.
    /// - FINDING 1: when the first (stale, cancelled) stream's completion
    ///   block finally runs — here, after the second stream has already
    ///   started — it must NOT flip `isStreaming` back to false or persist
    ///   a stale snapshot while the newer stream is still active.
    @MainActor @Test func overlappingSendFinalizesStalePlaceholderAndIgnoresStaleCleanup() async {
        let brain = GatedBrain()
        let store = ChatStore(brain: brain, defaults: isolatedDefaults(#function))

        let firstSend = Task { await store.send("pertama") }
        await brain.waitUntilStreamStarted(1)

        // Mid-first-stream: empty assistant placeholder present, streaming.
        #expect(store.messages.count == 2)
        #expect(store.messages[1].role == .assistant)
        #expect(store.messages[1].text == "")
        #expect(store.isStreaming == true)

        let secondSend = Task { await store.send("kedua") }
        await brain.waitUntilStreamStarted(2)

        // FINDING 2: stale empty placeholder from the first stream is gone;
        // history for the second call is [user "pertama", user "kedua"] only.
        #expect(store.messages.count == 3)
        #expect(store.messages[0].text == "pertama")
        #expect(store.messages[1].text == "kedua")
        #expect(store.messages[2].role == .assistant)
        #expect(store.messages[2].text == "")

        // Let the stale first stream complete now, after the second has begun.
        brain.finishStream(1)
        await firstSend.value

        // FINDING 1: stale cleanup must not clobber the still-active second stream.
        #expect(store.isStreaming == true)
        #expect(store.messages[2].text == "")

        // Finish the second stream for real and let it complete normally.
        brain.finishStream(2, with: ["OK"])
        await secondSend.value

        #expect(store.messages[2].text == "OK")
        #expect(store.isStreaming == false)
    }

    /// Regression test for round 2: `finalizeInterruptedAssistant()` can
    /// remove a message, shifting every later index down by one. If a stale
    /// (superseded) stream's `catch` block writes to its captured `index`
    /// without checking generation, that write now lands on whatever
    /// message slid into that slot — here, the NEWER user's own message —
    /// instead of being silently discarded. The catch block must be gated
    /// by the same generation check as the success path.
    @MainActor @Test func staleStreamErrorAfterSupersessionDoesNotCorruptNewerMessage() async {
        let brain = GatedBrain()
        let store = ChatStore(brain: brain, defaults: isolatedDefaults(#function))

        let firstSend = Task { await store.send("pertama") }
        await brain.waitUntilStreamStarted(1)

        let secondSend = Task { await store.send("kedua") }
        await brain.waitUntilStreamStarted(2)

        // messages == [user "pertama", user "kedua", assistant ""].
        // Stream 1's captured index (1) now points at the "kedua" user
        // message because finalizeInterruptedAssistant() removed stream 1's
        // own placeholder and shifted everything after it down by one.
        #expect(store.messages[1].role == .user)
        #expect(store.messages[1].text == "kedua")

        // Let the stale (superseded) first stream fail now.
        brain.throwStream(1)
        await firstSend.value

        // The catch block must be generation-gated: stream 1's error must
        // NOT land on messages[1], which is now the "kedua" user message.
        #expect(store.messages[1].role == .user)
        #expect(store.messages[1].text == "kedua")

        // isStreaming must still reflect only the newest (second) stream.
        #expect(store.isStreaming == true)

        // Finish the second stream normally; it should complete cleanly.
        brain.finishStream(2, with: ["OK"])
        await secondSend.value

        #expect(store.messages[1].text == "kedua")
        #expect(store.messages[2].text == "OK")
        #expect(store.isStreaming == false)
    }

    /// `suite` diisi `#function` milik pemanggil, jadi tiap test tetap
    /// mendapat UserDefaults-nya sendiri.
    @MainActor
    private func chatHandlingReminders(now: Date = TestTime.now, suite: String = #function)
        -> (ChatStore, InMemoryReminderStore, SpyReminderScheduler) {
        let chat = ChatStore(brain: nil, defaults: isolatedDefaults(suite), now: { now })
        let reminders = InMemoryReminderStore()
        let scheduler = SpyReminderScheduler()
        chat.createReminder = CreateReminderFromTextUseCase(
            store: reminders, notifications: scheduler, now: { now },
            calendar: TestTime.calendar, locale: TestTime.locale)
        return (chat, reminders, scheduler)
    }

    /// Reminder ditangani lokal: tidak ada otak di test ini (`brain: nil`),
    /// jadi pesan yang sampai ke jalur AI akan mengisi `noticeMessage`.
    @MainActor @Test func reminderRequestIsHandledWithoutTheBrain() async {
        let (chat, reminders, scheduler) = chatHandlingReminders()
        chat.noticeMessage = "stale banner"

        await chat.send("remind me to drink water at 3pm")

        #expect(reminders.reminders.map(\.title) == ["Drink water"])
        #expect(reminders.reminders.first?.rule == .once(TestTime.date(2026, 9, 16, 15, 0)))
        #expect(scheduler.syncCallCount == 1)
        #expect(chat.messages.map(\.role) == [.user, .assistant])
        #expect(chat.messages[1].text.hasPrefix("Done — I'll remind you to drink water today at"))
        #expect(chat.isStreaming == false)
        #expect(chat.noticeMessage == nil)
    }

    @MainActor @Test func missingTimeIsAskedThenCompletedOnTheNextTurn() async {
        let (chat, reminders, _) = chatHandlingReminders()

        await chat.send("remind me to call mom")

        #expect(reminders.reminders.isEmpty)
        #expect(chat.messages.last?.text == "What time should I remind you to call mom?")
        #expect(chat.noticeMessage == nil)

        await chat.send("5pm")

        #expect(reminders.reminders.map(\.title) == ["Call mom"])
        #expect(reminders.reminders.first?.rule == .once(TestTime.date(2026, 9, 16, 17, 0)))
        #expect(chat.messages.count == 4)
        #expect(chat.messages.last?.text.hasPrefix("Done — I'll remind you to call mom today at") == true)
    }

    /// Pertanyaan jam hanya berlaku satu giliran. Setelah pesan lain, "5pm"
    /// tidak boleh diam-diam menjadi reminder yang sudah dilupakan pengguna.
    @MainActor @Test func unansweredTimeQuestionExpiresAfterOneTurn() async {
        let (chat, reminders, _) = chatHandlingReminders()

        await chat.send("remind me to call mom")
        await chat.send("tell me a joke")
        #expect(chat.noticeMessage != nil)

        await chat.send("5pm")

        #expect(reminders.reminders.isEmpty)
    }

    @MainActor @Test func passedTimeIsConfirmedAsTomorrow() async {
        let (chat, reminders, _) = chatHandlingReminders(now: TestTime.date(2026, 9, 16, 16, 0))

        await chat.send("remind me to stretch at 3pm")

        #expect(reminders.reminders.first?.rule == .once(TestTime.date(2026, 9, 17, 15, 0)))
        #expect(chat.messages.last?.text.contains("tomorrow at") == true)
    }

    // MARK: - Kejadian dan lampiran (spec B §6)

    /// Chip di bawah konfirmasi dirender dari lampiran ini, bukan dari teks.
    @MainActor @Test func reminderConfirmationCarriesTheReminder() async throws {
        let (chat, reminders, _) = chatHandlingReminders()

        await chat.send("remind me to drink water at 3pm")

        let created = try #require(reminders.reminders.first)
        #expect(chat.messages[1].attachment == .reminder(created.id))
        #expect(chat.messages[0].attachment == nil)
    }

    @MainActor @Test func creatingAReminderRecordsTheEvent() async throws {
        let (chat, reminders, _) = chatHandlingReminders()

        await chat.send("remind me to drink water at 3pm")

        let created = try #require(reminders.reminders.first)
        #expect(chat.lastEvent == ChatEvent(kind: .reminderCreated(created.id), at: TestTime.now))
    }

    /// Pertanyaan balik bukan reminder: tidak ada chip dan karakter tidak merayakan apa pun.
    @MainActor @Test func timeQuestionIsPlainText() async {
        let (chat, _, _) = chatHandlingReminders()

        await chat.send("remind me to call mom")

        #expect(chat.messages.last?.attachment == nil)
        #expect(chat.lastEvent == nil)
    }

    @MainActor @Test func conversationIsSavedInItsOwnDefaults() async {
        let defaults = isolatedDefaults(#function)
        let first = ChatStore(brain: StubBrain(chunks: ["Hi!"]), defaults: defaults)

        await first.send("hello")
        let restored = ChatStore(brain: nil, defaults: defaults)

        #expect(defaults.data(forKey: ChatStore.recentKey) != nil)
        #expect(restored.messages == first.messages)
    }
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS,arch=arm64' -only-testing:DinoPocketTests/ChatStoreTests 2>&1 | grep -E "Test run with|TEST (SUCCEEDED|FAILED)|error:|✘"`
Expected: FAIL, dengan `error: extra arguments at positions #2, #3 in call` (atau `extra argument 'defaults'`) dan `cannot find 'ChatEvent' in scope`.

- [ ] **Step 3: Buat `ChatEvent`**

Buat `DinoPocketMac/Presentation/ViewModels/ChatEvent.swift`:

```swift
//
//  ChatEvent.swift
//  Apl
//
//  Kejadian di percakapan yang membuat karakter bereaksi sesaat (spec B §6).
//  ChatStore hanya mencatatnya; memilih ekspresi urusan CharacterMoodResolver.
//

import Foundation

struct ChatEvent: Equatable, Sendable {

    enum Kind: Equatable, Sendable {
        case reminderCreated(Reminder.ID)
        case failed
    }

    let kind: Kind
    let at: Date
}
```

- [ ] **Step 4: Perbarui `ChatStore`**

Ganti seluruh isi `DinoPocketMac/Presentation/ViewModels/ChatStore.swift`:

```swift
import Foundation
import Observation

@MainActor
@Observable
final class ChatStore {

    /// Kunci riwayat percakapan. Nama lama sengaja dipertahankan supaya
    /// percakapan yang sudah ada tidak hilang.
    nonisolated static let recentKey = "jarvis.chat.recent"

    var messages: [ChatMessage] = []
    var isStreaming = false
    var noticeMessage: String?

    /// Kejadian terakhir yang membuat karakter bereaksi (spec B §6). Dibaca
    /// `CharacterMoodResolver`; ChatStore tidak tahu apa-apa soal ekspresi.
    private(set) var lastEvent: ChatEvent?

    /// Pembuatan pengingat, disuntikkan sebagai UseCase.
    ///
    /// Dulu berupa closure `onCreateReminder` yang hanya menyimpan jadwal —
    /// pendaftaran notifikasi terjadi di tempat lain, sehingga apakah pengingat
    /// benar-benar berbunyi bergantung pada siapa yang memasang closure itu.
    /// UseCase menyatukan parse, simpan, dan jadwalkan jadi satu tanggung jawab.
    var createReminder: CreateReminderFromTextUseCase?

    /// Apple Intelligence — satu-satunya otak (spec A §2 #7). Opsional hanya
    /// supaya preview dan test bisa membuat ChatStore tanpa model.
    private let brain: Brain?
    /// Disuntikkan karena test host-nya Apl.app: tanpa ini, test menulis
    /// riwayat chat ke data app sungguhan.
    private let defaults: UserDefaults
    private let now: () -> Date
    private var streamTask: Task<Void, Never>?
    private var streamGeneration = 0

    /// Reminder yang sedang menunggu jawaban "jam berapa?". Hanya bertahan satu
    /// giliran: pesan berikutnya yang bukan ungkapan waktu membuangnya.
    private var reminderAwaitingTime: PendingReminder?

    private struct PendingReminder {
        let title: String?
    }

    /// Jawaban reminder yang dibuat tanpa AI.
    private struct LocalReply {
        let text: String
        /// Reminder yang baru dibuat; nil untuk pertanyaan "jam berapa?".
        let reminderID: Reminder.ID?
    }

    init(brain: Brain?, defaults: UserDefaults = .standard, now: @escaping () -> Date = { .now }) {
        self.brain = brain
        self.defaults = defaults
        self.now = now
        if let data = defaults.data(forKey: Self.recentKey),
           let restored = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            messages = restored
        }
    }

    /// Membuang riwayat percakapan yang tersimpan beserta yang ada di memori.
    func eraseAllStoredData() {
        messages = []
        noticeMessage = nil
        reminderAwaitingTime = nil
        lastEvent = nil
        defaults.removeObject(forKey: Self.recentKey)
    }

    /// Ketersediaan Apple Intelligence, tanpa efek samping — untuk jendela
    /// utama, onboarding, dan karakter.
    func availability() async -> BrainAvailability {
        guard let brain else {
            return .unavailable("Apple Intelligence isn't available in this build.")
        }
        return await brain.availability()
    }

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        streamTask?.cancel()
        finalizeInterruptedAssistant()
        messages.append(ChatMessage(role: .user, text: trimmed, date: now()))

        if let reply = await localReminderReply(to: trimmed) {
            noticeMessage = nil
            streamGeneration += 1
            messages.append(ChatMessage(role: .assistant, text: reply.text, date: now(),
                                        attachment: reply.reminderID.map { .reminder($0) }))
            if let id = reply.reminderID {
                lastEvent = ChatEvent(kind: .reminderCreated(id), at: now())
            }
            persistRecent()
            return
        }

        guard let brain, await brain.availability() == .ready else {
            noticeMessage = "Apple Intelligence isn't available yet. Enable it in System Settings to chat."
            return
        }
        noticeMessage = nil

        let history = messages
        var assistant = ChatMessage(role: .assistant, text: "", date: now())
        messages.append(assistant)
        let index = messages.count - 1
        streamGeneration += 1
        let generation = streamGeneration
        isStreaming = true

        let task = Task {
            do {
                for try await cumulative in brain.reply(to: history) {
                    if Task.isCancelled { break }
                    assistant.text = cumulative
                    if messages.indices.contains(index) { messages[index] = assistant }
                }
            } catch {
                if generation == self.streamGeneration, messages.indices.contains(index) {
                    messages[index].text += (messages[index].text.isEmpty ? "" : "\n\n") + "⚠️ Connection lost."
                }
            }
            guard generation == self.streamGeneration else { return }
            isStreaming = false
            persistRecent()
        }
        streamTask = task
        await task.value
    }

    /// Jawaban reminder tanpa AI, atau nil bila pesan harus diteruskan ke otak.
    ///
    /// Selama ada "remind me", pesan TIDAK PERNAH sampai ke model: model bisa
    /// menjawab "Sure!" tanpa membuat apa pun, dan reminder yang dijanjikan
    /// tetapi tidak ada lebih buruk daripada pertanyaan balik.
    private func localReminderReply(to text: String) async -> LocalReply? {
        guard let createReminder else { return nil }

        if let pending = reminderAwaitingTime {
            reminderAwaitingTime = nil
            if case .created(let reminder, let confirmation)? =
                await createReminder.complete(title: pending.title, timeText: text) {
                return LocalReply(text: confirmation, reminderID: reminder.id)
            }
        }

        switch await createReminder.execute(text: text) {
        case .created(let reminder, let confirmation):
            return LocalReply(text: confirmation, reminderID: reminder.id)
        case .needsTime(let title, let question):
            reminderAwaitingTime = PendingReminder(title: title)
            return LocalReply(text: question, reminderID: nil)
        case .notAReminder:
            return nil
        }
    }

    /// Kalau stream sebelumnya diputus di tengah jalan, rapikan bubble asisten-nya
    /// supaya tidak nyangkut di UI dan tidak ikut ke history berikutnya.
    private func finalizeInterruptedAssistant() {
        guard isStreaming, let last = messages.indices.last,
              messages[last].role == .assistant else { return }
        if messages[last].text.isEmpty {
            messages.remove(at: last)
        } else {
            messages[last].text += " (cancelled)"
        }
        isStreaming = false
    }

    private func persistRecent() {
        let recent = Array(messages.suffix(20))
        if let data = try? JSONEncoder().encode(recent) {
            defaults.set(data, forKey: Self.recentKey)
        }
    }
}

extension ChatStore: LocallyErasable {}
```

Teks "⚠️" dan " (cancelled)" masih ada di sini. Keduanya dihapus di Task 4, bersama perilaku yang menggantikannya.

- [ ] **Step 5: Jalankan test, pastikan lulus**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS,arch=arm64' -only-testing:DinoPocketTests/ChatStoreTests 2>&1 | grep -E "Test run with|TEST (SUCCEEDED|FAILED)|error:|✘"`
Expected: `Test run with 12 tests` … `** TEST SUCCEEDED **`

- [ ] **Step 6: Jalankan seluruh test**

Run: perintah test semua.
Expected: `** TEST SUCCEEDED **` (±99 test). `ChatAvailabilityTests` tetap memakai `ChatStore(brain:)` dan tetap lulus: argumen baru punya nilai default, dan test itu hanya membaca.

- [ ] **Step 7: Commit**

```bash
git add DinoPocketMac/Presentation/ViewModels/ChatEvent.swift DinoPocketMac/Presentation/ViewModels/ChatStore.swift \
  DinoPocketTests/ChatStoreTests.swift
git commit -m "$(cat <<'EOF'
feat(b3): ChatStore mencatat kejadian dan melampirkan reminder

Konfirmasi reminder membawa attachment .reminder(id), dan lastEvent
mencatat reminder yang baru dibuat untuk ekspresi karakter. UserDefaults
dan jam kini disuntikkan, sehingga test tidak lagi menulis riwayat chat
ke data Apl.app dan tidak perlu dijalankan serial.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Gagal, stop, retry, dan Clear Conversation di `ChatStore`

**Files:**
- Modify: `SharedCore/Infrastructure/Services/Brain.swift`
- Modify: `SharedCore/Infrastructure/Services/AppleBrain.swift`
- Modify: `DinoPocketMac/Presentation/ViewModels/ChatStore.swift`
- Modify: `DinoPocketTests/ChatStoreTests.swift`
- Modify: `DinoPocketTests/AppleBrainTests.swift`

**Interfaces:**
- Consumes: `ChatEvent` (Task 3), `ChatMessage.Status` (Task 2), `AplError.requestBlocked` (A)
- Produces:
  - `protocol Brain` bertambah `func resetConversation() async`, dengan implementasi kosong bawaan di extension
  - `AppleBrain.resetConversation()`: membuang sesi di memori dan transcript tersimpan
  - `nonisolated static let ChatStore.blockedReply = "I can't help with that one."`
  - `nonisolated static let ChatStore.unavailableNotice: String`
  - `ChatStore.stopStreaming()`: pesan yang sedang ditulis ditandai `.stopped` (atau dibuang bila masih kosong)
  - `ChatStore.retry(_ failedID: ChatMessage.ID) async`: hanya untuk pesan terakhir yang berstatus `.failed`
  - `ChatStore.clearConversation() async`: percakapan dan sesi model dikosongkan, reminder tetap ada
  - `ChatStore.eraseAllStoredData()` juga me-reset sesi model
  - Stream gagal → `status = .failed` + `lastEvent = .failed`. `AplError.requestBlocked` → teks `blockedReply` berstatus `.complete`.

- [ ] **Step 1: Tambahkan helper dan test yang gagal**

Di `DinoPocketTests/ChatStoreTests.swift`, ganti seluruh class `GatedBrain` (dari `private final class GatedBrain` sampai kurung tutupnya) dengan:

```swift
private final class GatedBrain: Brain, @unchecked Sendable {
    var available: BrainAvailability = .ready
    private(set) var resetCount = 0
    private var continuations: [AsyncThrowingStream<String, Error>.Continuation] = []
    private var starters: [CheckedContinuation<Void, Never>] = []
    private var startedCount = 0

    func availability() async -> BrainAvailability { available }

    func reply(to history: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            self.continuations.append(continuation)
            self.startedCount += 1
            if !self.starters.isEmpty { self.starters.removeFirst().resume() }
        }
    }

    func resetConversation() async {
        resetCount += 1
    }

    /// Suspends until the Nth (1-based) call to `reply` has begun.
    func waitUntilStreamStarted(_ n: Int) async {
        if startedCount >= n { return }
        await withCheckedContinuation { starters.append($0) }
    }

    /// Yields one cumulative chunk on the Nth (1-based) call's stream.
    func yield(_ n: Int, _ chunk: String) {
        guard continuations.indices.contains(n - 1) else { return }
        continuations[n - 1].yield(chunk)
    }

    /// Completes the Nth (1-based) call's stream, optionally yielding chunks first.
    func finishStream(_ n: Int, with chunks: [String] = []) {
        guard continuations.indices.contains(n - 1) else { return }
        for chunk in chunks { continuations[n - 1].yield(chunk) }
        continuations[n - 1].finish()
    }

    /// Fails the Nth (1-based) call's stream with an error, without yielding chunks.
    func throwStream(_ n: Int, error: Error = StubStreamError()) {
        guard continuations.indices.contains(n - 1) else { return }
        continuations[n - 1].finish(throwing: error)
    }
}
```

Tepat di bawah fungsi `isolatedDefaults`, tambahkan:

```swift
/// Menunggu kondisi yang dipenuhi task lain di MainActor. Batasnya satu
/// detik, supaya test yang salah gagal di `#expect`, bukan menggantung.
@MainActor
private func waitUntil(_ condition: () -> Bool) async {
    var attempts = 0
    while !condition(), attempts < 200 {
        attempts += 1
        try? await Task.sleep(for: .milliseconds(5))
    }
}
```

Di akhir `struct ChatStoreTests`, sebelum kurung tutupnya, tambahkan:

```swift
    // MARK: - Gagal, stop, retry, clear (spec B §9)

    /// Guardrail bukan kesalahan pengguna maupun jaringan: jawabannya netral.
    @MainActor @Test func blockedRequestGetsANeutralReply() async {
        let brain = GatedBrain()
        let store = ChatStore(brain: brain, defaults: isolatedDefaults(#function))

        let sending = Task { await store.send("something") }
        await brain.waitUntilStreamStarted(1)
        brain.throwStream(1, error: AplError.requestBlocked)
        await sending.value

        #expect(store.messages.last?.text == ChatStore.blockedReply)
        #expect(store.messages.last?.status == .complete)
        #expect(store.lastEvent == nil)
    }

    @MainActor @Test func failedStreamIsMarkedFailedWithoutWarningText() async {
        let brain = GatedBrain()
        let store = ChatStore(brain: brain, defaults: isolatedDefaults(#function), now: { TestTime.now })

        let sending = Task { await store.send("hello") }
        await brain.waitUntilStreamStarted(1)
        brain.yield(1, "Half an ans")
        await waitUntil { store.messages.last?.text == "Half an ans" }
        brain.throwStream(1)
        await sending.value

        #expect(store.messages.last?.text == "Half an ans")
        #expect(store.messages.last?.status == .failed)
        #expect(store.lastEvent == ChatEvent(kind: .failed, at: TestTime.now))
        #expect(store.isStreaming == false)
    }

    /// Retry mengganti jawaban yang gagal di tempat, tanpa menggandakan pesan pengguna.
    @MainActor @Test func retryReplacesTheFailedReply() async {
        let brain = GatedBrain()
        let store = ChatStore(brain: brain, defaults: isolatedDefaults(#function))
        let first = Task { await store.send("hello") }
        await brain.waitUntilStreamStarted(1)
        brain.throwStream(1)
        await first.value
        let failedID = store.messages[1].id

        let retrying = Task { await store.retry(failedID) }
        await brain.waitUntilStreamStarted(2)
        brain.finishStream(2, with: ["Hi!"])
        await retrying.value

        #expect(store.messages.map(\.role) == [.user, .assistant])
        #expect(store.messages[0].text == "hello")
        #expect(store.messages[1].text == "Hi!")
        #expect(store.messages[1].status == .complete)
    }

    @MainActor @Test func stopKeepsWhatWasWrittenAndMarksItStopped() async {
        let brain = GatedBrain()
        let store = ChatStore(brain: brain, defaults: isolatedDefaults(#function))

        let sending = Task { await store.send("tell me a story") }
        await brain.waitUntilStreamStarted(1)
        brain.yield(1, "Once upon")
        await waitUntil { store.messages.last?.text == "Once upon" }

        store.stopStreaming()
        brain.finishStream(1, with: ["Once upon a time"])
        await sending.value

        #expect(store.isStreaming == false)
        #expect(store.messages.last?.text == "Once upon")
        #expect(store.messages.last?.status == .stopped)
    }

    /// Clear Conversation mengosongkan layar DAN ingatan model, tapi reminder
    /// tetap ada (spec B §4).
    @MainActor @Test func clearConversationForgetsTheChatButKeepsReminders() async {
        let defaults = isolatedDefaults(#function)
        let brain = GatedBrain()
        let chat = ChatStore(brain: brain, defaults: defaults, now: { TestTime.now })
        let reminders = InMemoryReminderStore()
        chat.createReminder = CreateReminderFromTextUseCase(
            store: reminders, notifications: SpyReminderScheduler(), now: { TestTime.now },
            calendar: TestTime.calendar, locale: TestTime.locale)
        await chat.send("remind me to stretch at 3pm")

        await chat.clearConversation()

        #expect(chat.messages.isEmpty)
        #expect(chat.lastEvent == nil)
        #expect(defaults.data(forKey: ChatStore.recentKey) == nil)
        #expect(brain.resetCount == 1)
        #expect(reminders.reminders.count == 1)
    }

    @MainActor @Test func eraseAlsoMakesTheModelForget() async {
        let brain = GatedBrain()
        let store = ChatStore(brain: brain, defaults: isolatedDefaults(#function))

        store.eraseAllStoredData()
        await waitUntil { brain.resetCount == 1 }

        #expect(brain.resetCount == 1)
    }
```

Di `DinoPocketTests/AppleBrainTests.swift`, ganti baris import dengan:

```swift
import Foundation
import FoundationModels
import Testing
@testable import Apl

private final class SpySessionStore: ChatSessionStoring, @unchecked Sendable {
    private(set) var clearCount = 0
    func loadTranscript() -> Transcript? { nil }
    func save(_ transcript: Transcript) {}
    func clear() { clearCount += 1 }
}
```

lalu di akhir `struct AppleBrainTests`, sebelum kurung tutupnya, tambahkan:

```swift
    /// Clear Conversation harus membuat model lupa, bukan hanya layar kosong:
    /// tanpa ini transcript lama dimuat lagi saat pesan berikutnya dikirim.
    @MainActor @Test func resetConversationClearsTheSavedTranscript() async {
        let sessions = SpySessionStore()
        let brain = AppleBrain(sessionStore: sessions)

        await brain.resetConversation()

        #expect(sessions.clearCount == 1)
    }
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS,arch=arm64' -only-testing:DinoPocketTests/ChatStoreTests -only-testing:DinoPocketTests/AppleBrainTests 2>&1 | grep -E "Test run with|TEST (SUCCEEDED|FAILED)|error:|✘"`
Expected: FAIL, dengan `error: type 'ChatStore' has no member 'blockedReply'` dan `value of type 'AppleBrain' has no member 'resetConversation'`.

- [ ] **Step 3: Tambahkan `resetConversation` ke `Brain`**

Ganti seluruh isi `SharedCore/Infrastructure/Services/Brain.swift`:

```swift
import Foundation

/// Otak percakapan. Satu-satunya implementasi adalah `AppleBrain`
/// (spec A §2 #7); protokol ini ada supaya `ChatStore` bisa diuji dengan
/// otak palsu.
protocol Brain {
    func availability() async -> BrainAvailability
    /// Streaming balasan. Tiap nilai yang di-yield adalah teks balasan KUMULATIF.
    func reply(to history: [ChatMessage]) -> AsyncThrowingStream<String, Error>
    /// Melupakan percakapan yang dipegang model: sesi di memori dan yang
    /// tersimpan. Dipanggil Clear Conversation dan Erase All Data.
    func resetConversation() async
}

extension Brain {
    /// Otak tanpa ingatan sendiri tidak punya apa-apa untuk dilupakan.
    func resetConversation() async {}
}
```

Di `SharedCore/Infrastructure/Services/AppleBrain.swift`, tepat sebelum baris `#if canImport(FoundationModels)` yang mendahului `private func stream(history:`, tambahkan:

```swift
    nonisolated func resetConversation() async {
        await forgetSession()
    }

    /// Sesi di memori dibuang bersama transcript-nya. Stream yang masih
    /// berjalan tidak menyimpan ulang transcript lama: penyimpanan di akhir
    /// `stream` hanya terjadi bila `sessionBox.session` masih ada.
    private func forgetSession() {
        #if canImport(FoundationModels)
        sessionBox.session = nil
        (sessions as? any ChatSessionStoring)?.clear()
        #endif
    }

```

- [ ] **Step 4: Tulis ulang `ChatStore` dengan gagal, stop, retry, dan clear**

Ganti seluruh isi `DinoPocketMac/Presentation/ViewModels/ChatStore.swift`:

```swift
import Foundation
import Observation

@MainActor
@Observable
final class ChatStore {

    /// Kunci riwayat percakapan. Nama lama sengaja dipertahankan supaya
    /// percakapan yang sudah ada tidak hilang.
    nonisolated static let recentKey = "jarvis.chat.recent"

    /// Jawaban saat guardrail model menolak. Netral, bukan gaya error: tidak
    /// ada yang rusak, dan Retry tidak akan mengubah hasilnya (spec B §9).
    nonisolated static let blockedReply = "I can't help with that one."

    /// Ditampilkan di bawah percakapan saat pesan biasa dikirim tanpa Apple
    /// Intelligence. Tidak pernah masuk ke isi pesan.
    nonisolated static let unavailableNotice =
        "Apple Intelligence isn't available yet. Enable it in System Settings to chat."

    var messages: [ChatMessage] = []
    var isStreaming = false
    var noticeMessage: String?

    /// Kejadian terakhir yang membuat karakter bereaksi (spec B §6). Dibaca
    /// `CharacterMoodResolver`; ChatStore tidak tahu apa-apa soal ekspresi.
    private(set) var lastEvent: ChatEvent?

    /// Pembuatan pengingat, disuntikkan sebagai UseCase.
    ///
    /// Dulu berupa closure `onCreateReminder` yang hanya menyimpan jadwal —
    /// pendaftaran notifikasi terjadi di tempat lain, sehingga apakah pengingat
    /// benar-benar berbunyi bergantung pada siapa yang memasang closure itu.
    /// UseCase menyatukan parse, simpan, dan jadwalkan jadi satu tanggung jawab.
    var createReminder: CreateReminderFromTextUseCase?

    /// Apple Intelligence — satu-satunya otak (spec A §2 #7). Opsional hanya
    /// supaya preview dan test bisa membuat ChatStore tanpa model.
    private let brain: Brain?
    /// Disuntikkan karena test host-nya Apl.app: tanpa ini, test menulis
    /// riwayat chat ke data app sungguhan.
    private let defaults: UserDefaults
    private let now: () -> Date
    private var streamTask: Task<Void, Never>?
    /// Naik setiap kali jawaban baru dimulai atau yang berjalan dihentikan.
    /// Task stream yang generasinya sudah lewat tidak boleh menyentuh state.
    private var streamGeneration = 0

    /// Reminder yang sedang menunggu jawaban "jam berapa?". Hanya bertahan satu
    /// giliran: pesan berikutnya yang bukan ungkapan waktu membuangnya.
    private var reminderAwaitingTime: PendingReminder?

    private struct PendingReminder {
        let title: String?
    }

    /// Jawaban reminder yang dibuat tanpa AI.
    private struct LocalReply {
        let text: String
        /// Reminder yang baru dibuat; nil untuk pertanyaan "jam berapa?".
        let reminderID: Reminder.ID?
    }

    init(brain: Brain?, defaults: UserDefaults = .standard, now: @escaping () -> Date = { .now }) {
        self.brain = brain
        self.defaults = defaults
        self.now = now
        if let data = defaults.data(forKey: Self.recentKey),
           let restored = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            messages = restored
        }
    }

    /// Ketersediaan Apple Intelligence, tanpa efek samping — untuk jendela
    /// utama, onboarding, dan karakter.
    func availability() async -> BrainAvailability {
        guard let brain else {
            return .unavailable("Apple Intelligence isn't available in this build.")
        }
        return await brain.availability()
    }

    // MARK: - Percakapan

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        streamTask?.cancel()
        finalizeInterruptedAssistant()
        messages.append(ChatMessage(role: .user, text: trimmed, date: now()))

        if let reply = await localReminderReply(to: trimmed) {
            noticeMessage = nil
            streamGeneration += 1
            messages.append(ChatMessage(role: .assistant, text: reply.text, date: now(),
                                        attachment: reply.reminderID.map { .reminder($0) }))
            if let id = reply.reminderID {
                lastEvent = ChatEvent(kind: .reminderCreated(id), at: now())
            }
            persistRecent()
            return
        }

        await streamReply()
    }

    /// Mengulang jawaban yang gagal. Hanya jawaban TERAKHIR yang bisa diulang:
    /// jawaban baru selalu menanggapi pesan pengguna terakhir, jadi mengulang
    /// jawaban di tengah percakapan akan menjawab pertanyaan yang salah.
    func retry(_ failedID: ChatMessage.ID) async {
        guard !isStreaming, let last = messages.last,
              last.id == failedID, last.status == .failed else { return }
        messages.removeLast()
        await streamReply()
    }

    /// Esc atau tombol stop. Teks yang sudah tertulis dipertahankan dan
    /// ditandai `.stopped`.
    func stopStreaming() {
        guard isStreaming else { return }
        streamTask?.cancel()
        streamGeneration += 1
        finalizeInterruptedAssistant()
        persistRecent()
    }

    /// Menu Conversation › Clear Conversation…. Reminder tidak ikut terhapus.
    func clearConversation() async {
        resetConversationState()
        await brain?.resetConversation()
    }

    /// Membuang riwayat percakapan yang tersimpan beserta yang ada di memori,
    /// termasuk ingatan model — kalau tidak, sesi lama tersimpan lagi ke disk
    /// pada pesan berikutnya.
    func eraseAllStoredData() {
        resetConversationState()
        Task { await self.brain?.resetConversation() }
    }

    // MARK: - Internal

    private func streamReply() async {
        guard let brain, await brain.availability() == .ready else {
            noticeMessage = Self.unavailableNotice
            persistRecent()
            return
        }
        noticeMessage = nil

        // Jawaban gagal tidak dianggap bagian percakapan.
        let history = messages.filter { $0.status != .failed }
        var assistant = ChatMessage(role: .assistant, text: "", date: now())
        messages.append(assistant)
        let index = messages.count - 1
        streamGeneration += 1
        let generation = streamGeneration
        isStreaming = true

        let task = Task {
            do {
                for try await cumulative in brain.reply(to: history) {
                    if Task.isCancelled { break }
                    assistant.text = cumulative
                    if generation == self.streamGeneration, messages.indices.contains(index) {
                        messages[index] = assistant
                    }
                }
            } catch {
                if generation == self.streamGeneration, messages.indices.contains(index) {
                    if (error as? AplError) == .requestBlocked {
                        messages[index].text = Self.blockedReply
                    } else {
                        messages[index].status = .failed
                        lastEvent = ChatEvent(kind: .failed, at: now())
                    }
                }
            }
            guard generation == self.streamGeneration else { return }
            isStreaming = false
            persistRecent()
        }
        streamTask = task
        await task.value
    }

    /// Jawaban reminder tanpa AI, atau nil bila pesan harus diteruskan ke otak.
    ///
    /// Selama ada "remind me", pesan TIDAK PERNAH sampai ke model: model bisa
    /// menjawab "Sure!" tanpa membuat apa pun, dan reminder yang dijanjikan
    /// tetapi tidak ada lebih buruk daripada pertanyaan balik.
    private func localReminderReply(to text: String) async -> LocalReply? {
        guard let createReminder else { return nil }

        if let pending = reminderAwaitingTime {
            reminderAwaitingTime = nil
            if case .created(let reminder, let confirmation)? =
                await createReminder.complete(title: pending.title, timeText: text) {
                return LocalReply(text: confirmation, reminderID: reminder.id)
            }
        }

        switch await createReminder.execute(text: text) {
        case .created(let reminder, let confirmation):
            return LocalReply(text: confirmation, reminderID: reminder.id)
        case .needsTime(let title, let question):
            reminderAwaitingTime = PendingReminder(title: title)
            return LocalReply(text: question, reminderID: nil)
        case .notAReminder:
            return nil
        }
    }

    /// Kalau stream sebelumnya diputus di tengah jalan, rapikan bubble asisten-nya
    /// supaya tidak nyangkut di UI: yang masih kosong dibuang, yang sudah
    /// berisi ditandai `.stopped`.
    private func finalizeInterruptedAssistant() {
        guard isStreaming else { return }
        isStreaming = false
        guard let last = messages.indices.last, messages[last].role == .assistant else { return }
        if messages[last].text.isEmpty {
            messages.remove(at: last)
        } else {
            messages[last].status = .stopped
        }
    }

    private func resetConversationState() {
        streamTask?.cancel()
        streamTask = nil
        streamGeneration += 1
        isStreaming = false
        messages = []
        noticeMessage = nil
        reminderAwaitingTime = nil
        lastEvent = nil
        defaults.removeObject(forKey: Self.recentKey)
    }

    private func persistRecent() {
        let recent = Array(messages.suffix(20))
        if let data = try? JSONEncoder().encode(recent) {
            defaults.set(data, forKey: Self.recentKey)
        }
    }
}

extension ChatStore: LocallyErasable {}
```

- [ ] **Step 5: Jalankan test, pastikan lulus**

Run: perintah Step 2.
Expected: `Test run with 21 tests` (18 `ChatStoreTests` + 3 `AppleBrainTests`) … `** TEST SUCCEEDED **`

- [ ] **Step 6: Jalankan seluruh test dan pastikan teks peringatan hilang**

Run: perintah test semua.
Expected: `** TEST SUCCEEDED **` (±106 test).

Run: `grep -rn -e "⚠️" -e "(cancelled)" DinoPocketMac/Presentation/ViewModels SharedCore`
Expected: tidak ada keluaran.

- [ ] **Step 7: Commit**

```bash
git add SharedCore/Infrastructure/Services/Brain.swift SharedCore/Infrastructure/Services/AppleBrain.swift \
  DinoPocketMac/Presentation/ViewModels/ChatStore.swift DinoPocketTests/ChatStoreTests.swift \
  DinoPocketTests/AppleBrainTests.swift
git commit -m "$(cat <<'EOF'
feat(b4): kegagalan sebagai status, stop, retry, dan Clear Conversation

Stream yang gagal kini ditandai status .failed dan tercatat di
lastEvent, menggantikan teks "⚠️ Connection lost." di dalam pesan.
Guardrail dijawab netral. Esc menandai jawaban .stopped, menggantikan
sufiks " (cancelled)", dan Retry mengganti jawaban gagal di tempatnya.

Clear Conversation dan Erase All Data kini juga memanggil
Brain.resetConversation(). Tanpa itu, sesi Apple Intelligence tetap
ingat percakapan yang sudah dihapus dan menyimpannya lagi ke disk.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: `CharacterMoodResolver` dan teks status

**Files:**
- Create: `DinoPocketMac/Presentation/Character/CharacterMoodResolver.swift`
- Create: `DinoPocketMac/Presentation/Character/CharacterStatusText.swift`
- Test: `DinoPocketTests/CharacterMoodResolverTests.swift`, `DinoPocketTests/CharacterStatusTextTests.swift`

**Interfaces:**
- Consumes: `ChatEvent` (Task 3), `CharacterBehavior` (A), `ReminderPhrasing.time(_:calendar:locale:)` (A)
- Produces:
  - `struct CharacterMoodInput: Equatable { var intelligenceAvailable: Bool; var isStreaming: Bool; var lastEvent: ChatEvent?; var windowActivatedAt: Date? }`
  - `enum CharacterMoodResolver { static let momentDuration: TimeInterval = 3; struct Resolution: Equatable { let behavior: CharacterBehavior; let reevaluateAt: Date? }; static func resolve(_ input: CharacterMoodInput, now: Date) -> Resolution }`
  - `enum CharacterStatusText`:
    - `static func text(for: CharacterBehavior, now: Date, calendar: Calendar = .current, locale: Locale = .current, intelligenceAvailable: Bool, celebratedTime: Date?) -> String`
    - `static func greeting(at: Date, calendar: Calendar) -> String`
    - `static func accessibilityLabel(for: CharacterBehavior) -> String`

- [ ] **Step 1: Tulis test resolver yang gagal**

Buat `DinoPocketTests/CharacterMoodResolverTests.swift`:

```swift
import Foundation
import Testing
@testable import Apl

/// Urutan prioritas spec B §6, satu cabang per test. `t0` adalah detik ke-0;
/// semua waktu lain dihitung darinya.
struct CharacterMoodResolverTests {

    private typealias Resolution = CharacterMoodResolver.Resolution

    private let t0 = TestTime.now

    private func input(available: Bool = true, streaming: Bool = false,
                       event: ChatEvent.Kind? = nil, eventAt: TimeInterval = 0,
                       activatedAt: TimeInterval? = nil) -> CharacterMoodInput {
        CharacterMoodInput(
            intelligenceAvailable: available,
            isStreaming: streaming,
            lastEvent: event.map { ChatEvent(kind: $0, at: t0.addingTimeInterval(eventAt)) },
            windowActivatedAt: activatedAt.map { t0.addingTimeInterval($0) })
    }

    private func resolve(_ input: CharacterMoodInput, after seconds: TimeInterval) -> Resolution {
        CharacterMoodResolver.resolve(input, now: t0.addingTimeInterval(seconds))
    }

    private func moment(_ behavior: CharacterBehavior, until seconds: TimeInterval?) -> Resolution {
        Resolution(behavior: behavior, reevaluateAt: seconds.map { t0.addingTimeInterval($0) })
    }

    @Test func nothingRecentIsIdleWithoutATimer() {
        #expect(resolve(input(), after: 60) == moment(.idle, until: nil))
    }

    @Test func appleIntelligenceOffIsSleepyEvenWhileStreaming() {
        #expect(resolve(input(available: false, streaming: true), after: 0) == moment(.sleepy, until: nil))
    }

    @Test func recentFailureIsSleepyForThreeSeconds() {
        let failed = input(event: .failed)
        #expect(resolve(failed, after: 2.9) == moment(.sleepy, until: 3))
        #expect(resolve(failed, after: 3).behavior == .idle)
    }

    @Test func failureOutranksStreaming() {
        #expect(resolve(input(streaming: true, event: .failed), after: 1).behavior == .sleepy)
    }

    @Test func streamingIsThinkingWithoutATimer() {
        #expect(resolve(input(streaming: true), after: 0) == moment(.thinking, until: nil))
    }

    @Test func oldFailureNoLongerBlocksThinking() {
        #expect(resolve(input(streaming: true, event: .failed), after: 10).behavior == .thinking)
    }

    @Test func newReminderCelebratesForThreeSeconds() {
        let created = input(event: .reminderCreated(UUID()))
        #expect(resolve(created, after: 0) == moment(.celebrate, until: 3))
        #expect(resolve(created, after: 3).behavior == .idle)
    }

    @Test func streamingOutranksCelebration() {
        #expect(resolve(input(streaming: true, event: .reminderCreated(UUID())), after: 1).behavior == .thinking)
    }

    @Test func celebrationOutranksGreeting() {
        #expect(resolve(input(event: .reminderCreated(UUID()), activatedAt: 0), after: 1).behavior == .celebrate)
    }

    @Test func activatedWindowGreetsForThreeSeconds() {
        let activated = input(activatedAt: 5)
        #expect(resolve(activated, after: 6) == moment(.greet, until: 8))
        #expect(resolve(activated, after: 8).behavior == .idle)
    }

    /// Jam yang mundur (kejadian "di masa depan") tidak boleh membuat momen abadi.
    @Test func eventsFromTheFutureAreIgnored() {
        #expect(resolve(input(event: .failed, eventAt: 10), after: 0).behavior == .idle)
    }
}
```

- [ ] **Step 2: Tulis test teks status yang gagal**

Buat `DinoPocketTests/CharacterStatusTextTests.swift`:

```swift
import Foundation
import Testing
@testable import Apl

struct CharacterStatusTextTests {

    private func text(_ behavior: CharacterBehavior, at hour: Int = 10, minute: Int = 0,
                      available: Bool = true, celebrated: Date? = nil) -> String {
        CharacterStatusText.text(for: behavior, now: TestTime.date(2026, 9, 16, hour, minute),
                                 calendar: TestTime.calendar, locale: TestTime.locale,
                                 intelligenceAvailable: available, celebratedTime: celebrated)
    }

    @Test func greetingFollowsTheClock() {
        #expect(text(.greet, at: 0) == "Good morning!")
        #expect(text(.greet, at: 11, minute: 59) == "Good morning!")
        #expect(text(.greet, at: 12) == "Good afternoon!")
        #expect(text(.greet, at: 17, minute: 59) == "Good afternoon!")
        #expect(text(.greet, at: 18) == "Good evening!")
    }

    /// Format jam diambil dari ReminderPhrasing, supaya sama dengan kalimat
    /// konfirmasi di chat (en_US memakai spasi sempit sebelum "PM").
    @Test func celebrationNamesTheReminderTime() {
        let threePM = TestTime.date(2026, 9, 16, 15, 0)
        let clock = ReminderPhrasing.time(threePM, calendar: TestTime.calendar, locale: TestTime.locale)
        #expect(text(.celebrate, celebrated: threePM) == "Reminder set for \(clock)")
    }

    @Test func celebrationWithoutATimeStaysGeneric() {
        #expect(text(.celebrate) == "Reminder set")
    }

    @Test func sleepyExplainsWhy() {
        #expect(text(.sleepy, available: false) == "Apple Intelligence is off")
        #expect(text(.sleepy, available: true) == "Something went wrong")
    }

    @Test func idleAndThinkingUseFixedCopy() {
        #expect(text(.idle) == "Here when you need me")
        #expect(text(.thinking) == "Thinking…")
    }

    @Test func voiceOverLabelNamesTheCharacterAndItsState() {
        #expect(CharacterStatusText.accessibilityLabel(for: .thinking) == "Apl, thinking")
        let labels = Set(CharacterBehavior.allCases.map { CharacterStatusText.accessibilityLabel(for: $0) })
        #expect(labels.count == CharacterBehavior.allCases.count)
    }
}
```

- [ ] **Step 3: Jalankan test, pastikan gagal**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS,arch=arm64' -only-testing:DinoPocketTests/CharacterMoodResolverTests -only-testing:DinoPocketTests/CharacterStatusTextTests 2>&1 | grep -E "Test run with|TEST (SUCCEEDED|FAILED)|error:|✘"`
Expected: FAIL, dengan `error: cannot find 'CharacterMoodInput' in scope` dan `cannot find 'CharacterStatusText' in scope`.

- [ ] **Step 4: Tulis resolver**

Buat `DinoPocketMac/Presentation/Character/CharacterMoodResolver.swift`:

```swift
//
//  CharacterMoodResolver.swift
//  Apl
//
//  Memilih ekspresi robot dari keadaan chat (spec B §6).
//
//  Fungsi murni, tanpa timer: pemanggil menjadwalkan evaluasi ulang pada
//  `Resolution.reevaluateAt`. Dengan begitu setiap cabang dan batas waktunya
//  bisa dites dengan `now` yang disuntikkan.
//

import Foundation

struct CharacterMoodInput: Equatable {
    var intelligenceAvailable: Bool
    var isStreaming: Bool
    var lastEvent: ChatEvent?
    /// Kapan jendela terakhir menjadi aktif.
    var windowActivatedAt: Date?
}

enum CharacterMoodResolver {

    /// Lama sebuah momen — gagal, reminder dibuat, jendela dibuka — memengaruhi wajah.
    static let momentDuration: TimeInterval = 3

    struct Resolution: Equatable {
        let behavior: CharacterBehavior
        /// Kapan hasil ini berubah tanpa ada input yang berubah; nil bila tidak akan.
        let reevaluateAt: Date?
    }

    /// Dievaluasi berurutan; cabang pertama yang cocok menang.
    static func resolve(_ input: CharacterMoodInput, now: Date) -> Resolution {
        if !input.intelligenceAvailable {
            return Resolution(behavior: .sleepy, reevaluateAt: nil)
        }
        if let event = input.lastEvent, event.kind == .failed,
           let end = momentEnd(startedAt: event.at, now: now) {
            return Resolution(behavior: .sleepy, reevaluateAt: end)
        }
        if input.isStreaming {
            return Resolution(behavior: .thinking, reevaluateAt: nil)
        }
        if let event = input.lastEvent, case .reminderCreated = event.kind,
           let end = momentEnd(startedAt: event.at, now: now) {
            return Resolution(behavior: .celebrate, reevaluateAt: end)
        }
        if let activated = input.windowActivatedAt,
           let end = momentEnd(startedAt: activated, now: now) {
            return Resolution(behavior: .greet, reevaluateAt: end)
        }
        return Resolution(behavior: .idle, reevaluateAt: nil)
    }

    /// Akhir momen bila `now` masih berada di dalamnya.
    ///
    /// Setengah terbuka, [mulai, mulai + 3): tepat di detik ke-3 momen sudah
    /// selesai. Dengan batas inklusif, evaluasi ulang yang dijadwalkan tepat
    /// di detik itu menghasilkan jadwal yang sama, dan wajah tidak pernah
    /// kembali. Momen "di masa depan" (jam mundur) diabaikan.
    private static func momentEnd(startedAt start: Date, now: Date) -> Date? {
        let elapsed = now.timeIntervalSince(start)
        guard elapsed >= 0, elapsed < momentDuration else { return nil }
        return start.addingTimeInterval(momentDuration)
    }
}
```

- [ ] **Step 5: Tulis teks status**

Buat `DinoPocketMac/Presentation/Character/CharacterStatusText.swift`:

```swift
//
//  CharacterStatusText.swift
//  Apl
//
//  Kalimat di bawah nama robot dan label VoiceOver-nya (spec B §5, §7).
//

import Foundation

enum CharacterStatusText {

    static func text(for behavior: CharacterBehavior,
                     now: Date,
                     calendar: Calendar = .current,
                     locale: Locale = .current,
                     intelligenceAvailable: Bool,
                     celebratedTime: Date?) -> String {
        switch behavior {
        case .idle:
            return "Here when you need me"
        case .greet:
            return greeting(at: now, calendar: calendar)
        case .thinking:
            return "Thinking…"
        case .celebrate:
            guard let celebratedTime else { return "Reminder set" }
            return "Reminder set for \(ReminderPhrasing.time(celebratedTime, calendar: calendar, locale: locale))"
        case .sleepy:
            // Robot juga tertidur sesaat setelah jawaban gagal. Menyebut Apple
            // Intelligence mati di situ akan menyuruh pengguna memperbaiki
            // hal yang tidak rusak.
            return intelligenceAvailable ? "Something went wrong" : "Apple Intelligence is off"
        }
    }

    static func greeting(at date: Date, calendar: Calendar) -> String {
        switch calendar.component(.hour, from: date) {
        case ..<12: "Good morning!"
        case ..<18: "Good afternoon!"
        default: "Good evening!"
        }
    }

    static func accessibilityLabel(for behavior: CharacterBehavior) -> String {
        switch behavior {
        case .idle: "Apl, idle"
        case .greet: "Apl, saying hello"
        case .thinking: "Apl, thinking"
        case .celebrate: "Apl, celebrating"
        case .sleepy: "Apl, sleepy"
        }
    }
}
```

- [ ] **Step 6: Jalankan test, pastikan lulus**

Run: perintah Step 3.
Expected: `Test run with 17 tests` … `** TEST SUCCEEDED **`

- [ ] **Step 7: Commit**

```bash
git add DinoPocketMac/Presentation/Character/CharacterMoodResolver.swift \
  DinoPocketMac/Presentation/Character/CharacterStatusText.swift \
  DinoPocketTests/CharacterMoodResolverTests.swift DinoPocketTests/CharacterStatusTextTests.swift
git commit -m "$(cat <<'EOF'
feat(b5): CharacterMoodResolver dan teks status robot

Ekspresi dipilih oleh fungsi murni dengan prioritas spec B §6: AI mati,
gagal baru-baru ini, streaming, reminder dibuat, lalu jendela dibuka.
Momen berlaku setengah terbuka [t, t+3) supaya evaluasi ulang di detik
ke-3 benar-benar mengembalikan wajah. Teks status dan label VoiceOver
mengikuti ekspresi; sleepy karena gagal tidak lagi menyalahkan Apple
Intelligence.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: `CharacterExpressionCache` dan `USDZCharacterView` yang memakainya

**Files:**
- Create: `DinoPocketMac/Presentation/Character/CharacterExpressionCache.swift`
- Modify: `DinoPocketMac/Presentation/Character/CharacterAsset.swift` (tambah `allResourceNames`)
- Modify: `DinoPocketMac/Presentation/Character/USDZCharacterView.swift`
- Test: `DinoPocketTests/CharacterExpressionCacheTests.swift`

**Interfaces:**
- Consumes: `CharacterStatusText.accessibilityLabel(for:)` (Task 5), `CharacterAsset` (A)
- Produces:
  - `CharacterAsset.allResourceNames: [String]` (unik, terurut)
  - `@MainActor final class CharacterExpressionCache`:
    - `static let shared`
    - `init(bundle: Bundle = .main)`
    - `var loadedCount: Int`
    - `func entity(named: String) async -> Entity?`, yang mengembalikan salinan dan mengingat berkas yang hilang
    - `func preload(_ asset: CharacterAsset) async`
  - `USDZCharacterView(size:asset:behavior:isPaused:)`. `isPaused` baru dengan default `false`, jadi pemanggil lama (Buddy) tidak berubah.

- [ ] **Step 1: Tulis test yang gagal**

Buat `DinoPocketTests/CharacterExpressionCacheTests.swift`:

```swift
import Foundation
import RealityKit
import Testing
@testable import Apl

/// Memuat USDZ sungguhan dari bundle Apl.app (test host), bukan tiruan:
/// yang ingin dipastikan justru bahwa berkasnya terbaca dan hanya sekali.
@MainActor
struct CharacterExpressionCacheTests {

    @Test func everyExpressionIsListedOnce() {
        #expect(CharacterAsset.robot.allResourceNames
                == ["RobotBigSmile", "RobotFlat", "RobotO", "RobotSad", "RobotSmile"])
    }

    @Test func eachFileIsLoadedOnceAndHandedOutAsCopies() async throws {
        let cache = CharacterExpressionCache()

        let first = try #require(await cache.entity(named: "RobotFlat"))
        let second = try #require(await cache.entity(named: "RobotFlat"))

        #expect(first !== second)
        #expect(cache.loadedCount == 1)
    }

    @Test func missingFileYieldsNilEveryTime() async {
        let cache = CharacterExpressionCache()

        let first = await cache.entity(named: "NoSuchRobot")
        let second = await cache.entity(named: "NoSuchRobot")

        #expect(first == nil)
        #expect(second == nil)
        #expect(cache.loadedCount == 0)
    }
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS,arch=arm64' -only-testing:DinoPocketTests/CharacterExpressionCacheTests 2>&1 | grep -E "Test run with|TEST (SUCCEEDED|FAILED)|error:|✘"`
Expected: FAIL, dengan `error: value of type 'CharacterAsset' has no member 'allResourceNames'` dan `cannot find 'CharacterExpressionCache' in scope`.

- [ ] **Step 3: Tambahkan `allResourceNames`**

Di `DinoPocketMac/Presentation/Character/CharacterAsset.swift`, di dalam `struct CharacterAsset`, tepat setelah fungsi `resourceName(for:)`, tambahkan:

```swift

    /// Semua berkas yang mungkin tampil, tanpa duplikat — untuk dimuat di awal.
    var allResourceNames: [String] {
        Set(expressions.values).union([defaultExpression]).sorted()
    }
```

- [ ] **Step 4: Buat cache**

Buat `DinoPocketMac/Presentation/Character/CharacterExpressionCache.swift`:

```swift
//
//  CharacterExpressionCache.swift
//  AplMac
//
//  Memuat tiap ekspresi USDZ sekali, lalu membagikan salinannya (spec B §6).
//
//  Tanpa cache, setiap pergantian mood membaca berkas dari disk lagi: robot
//  tertahan di wajah lama selama model baru dimuat, dan saat jawaban pendek
//  wajah "berpikir" muncul setelah jawabannya selesai. Jendela utama dan
//  Buddy berbagi satu instance, jadi satu berkas tidak pernah dimuat dua kali.
//

import Foundation
import RealityKit

@MainActor
final class CharacterExpressionCache {

    static let shared = CharacterExpressionCache()

    private let bundle: Bundle
    /// Model asli, tidak pernah dipasang ke scene. Yang dipasang selalu salinannya,
    /// jadi normalisasi skala di view tidak menumpuk pada model asli.
    private var templates: [String: Entity] = [:]
    /// Berkas yang gagal dimuat tidak dicari lagi setiap kali mood berubah.
    private var missing: Set<String> = []
    /// Pemuatan yang sedang berjalan: dua permintaan serentak berbagi satu baca berkas.
    private var loading: [String: Task<Entity?, Never>] = [:]

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    var loadedCount: Int { templates.count }

    /// Salinan siap pakai, atau nil bila berkas tidak ada atau gagal dimuat.
    func entity(named name: String) async -> Entity? {
        if let template = templates[name] {
            return template.clone(recursive: true)
        }
        if missing.contains(name) {
            return nil
        }

        let task: Task<Entity?, Never>
        if let running = loading[name] {
            task = running
        } else {
            let bundle = self.bundle
            task = Task { try? await Entity(named: name, in: bundle) }
            loading[name] = task
        }

        let template = await task.value
        loading[name] = nil
        guard let template else {
            missing.insert(name)
            return nil
        }
        templates[name] = template
        return template.clone(recursive: true)
    }

    /// Dipanggil saat app dibuka, supaya pergantian ekspresi pertama pun instan.
    func preload(_ asset: CharacterAsset) async {
        for name in asset.allResourceNames {
            _ = await entity(named: name)
        }
    }
}
```

- [ ] **Step 5: Tulis ulang `USDZCharacterView`**

Ganti seluruh isi `DinoPocketMac/Presentation/Character/USDZCharacterView.swift`:

```swift
//
//  USDZCharacterView.swift
//  AplMac
//
//  Companion 3D HealthAssistantRobot, dirender lewat RealityView (SwiftUI).
//  Satu berkas USDZ per ekspresi; berkas mana yang dimuat ditentukan
//  `CharacterAsset.expressions`, bukan oleh view ini. Model diambil dari
//  `CharacterExpressionCache`, bukan dibaca dari disk setiap kali.
//
//  CATATAN — tiga jalan buntu yang tidak perlu diulang.
//
//  1. Latar buram di Buddy Mode BUKAN berasal dari view ini, melainkan dari
//     `SKView` overlay selebar layar di `AplBuddyWindowController` (SKView
//     tanpa scene merender latar buram). Sudah diganti `NSView` polos.
//
//  2. Sempat diganti ke `ARView` demi `Environment.Background.color(.clear)`,
//     lalu disimpulkan "ARView mengabaikan PerspectiveCamera" karena mengubah
//     jarak kamera 0.71 → 5.0 nyaris tak berpengaruh. Kesimpulan itu KELIRU.
//     Penyebab sebenarnya bug skala di bawah: modelnya selebar 35 unit, jadi
//     butuh kamera ~90 unit untuk memuatnya — perubahan ke 5.0 memang tak
//     terlihat. Kamera berfungsi normal di kedua view.
//
//  3. Mengganti ekspresi dengan `.id(resourceName)` pada RealityView memang
//     bekerja, tetapi membangun ulang seluruh scene: karakter berkedip hilang
//     setiap kali mood berubah. Yang ditukar sekarang hanya isi `stage`,
//     dan model lama tetap terlihat sampai model baru siap.
//

import SwiftUI
import RealityKit

struct USDZCharacterView: View {

    var size: CGFloat = 90
    var asset: CharacterAsset = .robot
    var behavior: CharacterBehavior = .idle
    /// Menjeda gerak napas tanpa membongkar scene — saat jendela tidak aktif
    /// atau Low Power Mode (spec B §12).
    var isPaused = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Wadah yang hidup selama view ada; hanya isinya yang berganti.
    @State private var stage = Entity()
    @State private var motion: AnimationPlaybackController?
    /// Naik setiap kali ekspresi berganti, memicu efek "pop".
    @State private var swapCount = 0

    /// Model dipasang ulang saat berkasnya ATAU Reduce Motion berubah, karena
    /// gerak napas dipasang bersama model.
    private struct Appearance: Hashable {
        let resourceName: String
        let reduceMotion: Bool
    }

    var body: some View {
        RealityView { content in
            content.add(stage)

            // Key light so the white body reads with some shading.
            let key = DirectionalLight()
            key.light.intensity = asset.keyLightIntensity
            key.look(at: .zero, from: [1, 2, 2], relativeTo: nil)
            content.add(key)

            // Camera framing the character head-on.
            let camera = PerspectiveCamera()
            camera.camera.fieldOfViewInDegrees = asset.fieldOfViewDegrees
            let eye = SIMD3<Float>(0, asset.cameraHeight, asset.cameraDistance)
            camera.position = eye
            camera.look(at: [0, 0, 0], from: eye, relativeTo: nil)
            content.add(camera)
        }
        // Dikunci ke nama berkas, bukan ke `behavior`: dua perilaku yang
        // memakai wajah sama tidak perlu memuat ulang apa pun.
        .task(id: Appearance(resourceName: asset.resourceName(for: behavior), reduceMotion: reduceMotion)) {
            await show(asset.resourceName(for: behavior))
        }
        .onChange(of: isPaused) { _, paused in
            if paused { motion?.pause() } else { motion?.resume() }
        }
        // "Pop" singkat saat wajah berganti, supaya pergantian terbaca
        // sebagai reaksi, bukan kedipan.
        .keyframeAnimator(initialValue: CGFloat(1), trigger: swapCount) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(0.92, duration: 0.05)
                SpringKeyframe(1, duration: 0.13)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel(CharacterStatusText.accessibilityLabel(for: behavior))
        .accessibilityAddTraits(.isImage)
    }

    /// Mengambil satu ekspresi dari cache dan menukarnya ke dalam `stage`.
    ///
    /// Gagal muat tidak mengosongkan panggung — wajah sebelumnya dipertahankan,
    /// dan stage tetap menampilkan nama, status, serta Up next (spec B §9).
    /// Task yang sudah dibatalkan tidak boleh menukar apa pun: dengan cache,
    /// permintaan lama bisa selesai SETELAH permintaan yang lebih baru.
    @MainActor
    private func show(_ resourceName: String) async {
        guard let character = await CharacterExpressionCache.shared.entity(named: resourceName),
              !Task.isCancelled else { return }

        // Normalisasi ke ukuran layar yang konsisten dan pusatkan di origin.
        // Origin model ada di kaki, jadi recentering inilah yang menahannya
        // agar tidak tenggelam.
        let bounds = character.visualBounds(relativeTo: nil)
        let maxDim = max(bounds.extents.x, bounds.extents.y, bounds.extents.z, 0.0001)
        let factor = asset.targetExtent / maxDim

        // KALIKAN skala, jangan timpa. Ekspor USDZ kerap membawa skala bawaan
        // (robot lama datang dengan `scale = 0.01`, khas konversi cm ke m), dan
        // `visualBounds` sudah memperhitungkannya. Menulis `character.scale =
        // factor` membuang skala itu sehingga model membengkak puluhan kali —
        // extents jadi 35.0 × 32.3 × 10.2 alih-alih 0.35 × 0.32 × 0.10, dan
        // karakter memenuhi layar sebagai close-up yang tak terkenali.
        // Diukur, bukan ditebak.
        character.scale *= factor
        character.position = -bounds.center * factor

        let isSwap = !stage.children.isEmpty
        stage.children.removeAll()
        stage.addChild(character)

        // Reduce Motion mematikan napas dan pop (spec B §7).
        motion = reduceMotion ? nil : playIdleMotion(on: character)
        if isPaused { motion?.pause() }
        if isSwap && !reduceMotion { swapCount += 1 }
    }

    /// Klip bawaan kalau ada; kalau tidak, napas buatan.
    ///
    /// Kelima ekspor HealthAssistantRobot statis — `availableAnimations`
    /// kosong — jadi cabang kedua inilah yang benar-benar jalan hari ini.
    /// Cabang pertama dibiarkan supaya ekspor beranimasi nanti langsung
    /// dipakai tanpa menyentuh view ini.
    @MainActor
    private func playIdleMotion(on character: Entity) -> AnimationPlaybackController? {
        if let baked = character.availableAnimations.first {
            return character.playAnimation(baked.repeat(), transitionDuration: 0.3, startsPaused: false)
        }

        guard asset.idleBobHeight > 0 else { return nil }

        var lifted = character.transform
        lifted.translation.y += asset.idleBobHeight

        let bob = FromToByAnimation(
            to: lifted,
            duration: asset.idleBobDuration,
            timing: .easeInOut,
            bindTarget: .transform,
            repeatMode: .autoReverse
        )

        guard let resource = try? AnimationResource.generate(with: bob) else { return nil }
        return character.playAnimation(resource.repeat(), transitionDuration: 0.3, startsPaused: false)
    }
}

#Preview("Idle · Light") {
    USDZCharacterView(size: 160)
        .padding()
}

#Preview("Thinking · Dark") {
    USDZCharacterView(size: 160, behavior: .thinking)
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Celebrate") {
    USDZCharacterView(size: 160, behavior: .celebrate)
        .padding()
}
```

- [ ] **Step 6: Jalankan test, pastikan lulus**

Run: perintah Step 2.
Expected: `Test run with 3 tests` … `** TEST SUCCEEDED **`

Bila `eachFileIsLoadedOnceAndHandedOutAsCopies` gagal karena `Entity(named:in:)` tidak bisa memuat berkas di test host, **berhenti dan laporkan**. Jangan melonggarkan test.

- [ ] **Step 7: Jalankan seluruh test dan build**

Run: perintah test semua, lalu perintah build.
Expected: `** TEST SUCCEEDED **` (±126 test) dan `** BUILD SUCCEEDED **`. `BuddyCharacterHost` tetap memanggil `USDZCharacterView(size:asset:behavior:)` tanpa perubahan.

- [ ] **Step 8: Commit**

```bash
git add DinoPocketMac/Presentation/Character/CharacterExpressionCache.swift \
  DinoPocketMac/Presentation/Character/CharacterAsset.swift \
  DinoPocketMac/Presentation/Character/USDZCharacterView.swift \
  DinoPocketTests/CharacterExpressionCacheTests.swift
git commit -m "$(cat <<'EOF'
feat(b6): cache ekspresi robot, pop, Reduce Motion, dan jeda animasi

Kelima USDZ dimuat sekali lalu dibagikan sebagai salinan, jadi
pergantian mood tidak lagi menunggu disk; jendela utama dan Buddy
berbagi cache yang sama. Task pemuatan yang sudah dibatalkan tidak lagi
menukar wajah. Pergantian ekspresi mendapat pop singkat, Reduce Motion
mematikan napas dan pop, dan robot punya label VoiceOver yang mengikuti
ekspresi.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: `ReminderListViewModel` dan data preview

**Files:**
- Modify: `SharedCore/Infrastructure/Services/ReminderScheduling.swift`
- Modify: `SharedCore/Infrastructure/Services/ReminderNotificationCenter.swift`
- Modify: `DinoPocketTests/ReminderFakes.swift`
- Create: `DinoPocketMac/Presentation/ViewModels/ReminderListViewModel.swift`
- Create: `DinoPocketMac/Presentation/PreviewSupport.swift`
- Test: `DinoPocketTests/ReminderListViewModelTests.swift`

**Interfaces:**
- Consumes:
  - `ReminderStoring`, `ReminderStore(defaults:now:)`, `CancelReminderUseCase(store:notifications:now:)`, `UpdateReminderUseCase(store:notifications:now:)`, `Reminder.nextOccurrence(after:calendar:)`, `ReminderPhrasing.time` (A)
  - `ChatStore.init(brain:defaults:now:)` (Task 3)
- Produces:
  - `ReminderScheduling.notificationsAllowed() async -> Bool`
  - `enum ReminderChipState: Equatable { case scheduled(title: String, whenText: String); case past; case removed }`
  - `@MainActor @Observable final class ReminderListViewModel`:
    - `init(store:notifications:now:calendar:locale:notificationsAllowed:)`
    - `struct Row: Identifiable, Equatable { reminder, next, whenText, id, repeatsDaily }`
    - `func rows(at: Date) -> [Row]`, `func upNext(at: Date) -> [Row]` (maks. 3)
    - `func reminder(withID:) -> Reminder?`, `func chipState(for:at:) -> ReminderChipState`
    - `func cancel(_:) async`, `func undo() async`, `func update(_:) async`, `func refreshPermission() async`
    - `private(set) var lastCancelled: Reminder?`, `private(set) var notificationsAllowed: Bool`
    - `nonisolated static func whenText(for:next:now:calendar:locale:) -> String`
  - `enum PreviewData { static let stretchID; static func reminders(now:) -> [Reminder]; static var messages: [ChatMessage] }`
  - `struct PreviewReminderScheduler: ReminderScheduling`
  - `ReminderListViewModel.preview(_:notificationsAllowed:)`, `ChatStore.preview(_:isStreaming:)`
  - `SpyReminderScheduler.notificationsAllowedAnswer: Bool`

- [ ] **Step 1: Tulis test yang gagal**

Buat `DinoPocketTests/ReminderListViewModelTests.swift`:

```swift
import Foundation
import Testing
@testable import Apl

@MainActor
struct ReminderListViewModelTests {

    private func makeViewModel(_ reminders: [Reminder] = [])
        -> (ReminderListViewModel, InMemoryReminderStore, SpyReminderScheduler) {
        let store = InMemoryReminderStore()
        for reminder in reminders { store.add(reminder) }
        let scheduler = SpyReminderScheduler()
        let viewModel = ReminderListViewModel(store: store, notifications: scheduler,
                                              now: { TestTime.now },
                                              calendar: TestTime.calendar, locale: TestTime.locale)
        return (viewModel, store, scheduler)
    }

    private func once(_ title: String, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Reminder {
        Reminder(title: title, rule: .once(TestTime.date(2026, 9, day, hour, minute)), createdAt: TestTime.now)
    }

    /// Format jam diambil dari ReminderPhrasing (en_US memakai spasi sempit sebelum AM/PM).
    private func clock(_ hour: Int, _ minute: Int) -> String {
        ReminderPhrasing.time(TestTime.date(2026, 9, 16, hour, minute),
                              calendar: TestTime.calendar, locale: TestTime.locale)
    }

    @Test func rowsAreOrderedByNextOccurrence() {
        let noon = Reminder(title: "Noon", rule: .daily(hour: 12, minute: 0), createdAt: TestTime.now)
        let (viewModel, _, _) = makeViewModel([once("Tomorrow", 17, 9), noon, once("Afternoon", 16, 15)])

        #expect(viewModel.rows(at: TestTime.now).map(\.reminder.title) == ["Noon", "Afternoon", "Tomorrow"])
    }

    @Test func passedOnceRemindersAreHidden() {
        let (viewModel, _, _) = makeViewModel([once("Passed", 16, 9)])

        #expect(viewModel.rows(at: TestTime.now).isEmpty)
    }

    @Test func upNextShowsTheNearestThree() {
        let reminders = (1...5).map { hour in
            Reminder(title: "R\(hour)", rule: .once(TestTime.now.addingTimeInterval(TimeInterval(hour * 3600))),
                     createdAt: TestTime.now)
        }
        let (viewModel, _, _) = makeViewModel(reminders.reversed())

        #expect(viewModel.upNext(at: TestTime.now).map(\.reminder.title) == ["R1", "R2", "R3"])
    }

    @Test func whenTextNamesTheDay() {
        func when(_ rule: Reminder.Rule) -> String? {
            let reminder = Reminder(title: "x", rule: rule, createdAt: TestTime.now)
            guard let next = reminder.nextOccurrence(after: TestTime.now, calendar: TestTime.calendar) else {
                return nil
            }
            return ReminderListViewModel.whenText(for: rule, next: next, now: TestTime.now,
                                                  calendar: TestTime.calendar, locale: TestTime.locale)
        }

        #expect(when(.once(TestTime.date(2026, 9, 16, 15, 0))) == "Today, \(clock(15, 0))")
        #expect(when(.once(TestTime.date(2026, 9, 17, 9, 0))) == "Tomorrow, \(clock(9, 0))")
        #expect(when(.daily(hour: 9, minute: 0)) == "Every day, \(clock(9, 0))")
        #expect(when(.once(TestTime.date(2026, 9, 19, 9, 0))) == "Sep 19, \(clock(9, 0))")
    }

    @Test func cancelRemovesTheReminderAndReschedules() async {
        let stretch = once("Stretch", 16, 15)
        let (viewModel, store, scheduler) = makeViewModel([stretch])

        await viewModel.cancel(stretch.id)

        #expect(store.reminders.isEmpty)
        #expect(scheduler.syncCallCount == 1)
        #expect(viewModel.lastCancelled == stretch)
    }

    /// Undo mengembalikan reminder yang SAMA — id tetap, jadi chip di chat
    /// kembali menunjuknya.
    @Test func undoBringsBackTheSameReminder() async {
        let stretch = once("Stretch", 16, 15)
        let (viewModel, store, scheduler) = makeViewModel([stretch])

        await viewModel.cancel(stretch.id)
        await viewModel.undo()

        #expect(store.reminders == [stretch])
        #expect(scheduler.syncCallCount == 2)
        #expect(scheduler.lastSynced == [stretch])
        #expect(viewModel.lastCancelled == nil)
    }

    @Test func updateSavesAndReschedules() async {
        var stretch = once("Stretch", 16, 15)
        let (viewModel, store, scheduler) = makeViewModel([stretch])

        stretch.title = "Stretch longer"
        stretch.rule = .daily(hour: 16, minute: 30)
        await viewModel.update(stretch)

        #expect(store.reminders == [stretch])
        #expect(scheduler.syncCallCount == 1)
    }

    @Test func chipFollowsTheReminderItBelongsTo() async {
        let upcoming = once("Stretch", 16, 15)
        let passed = once("Water", 16, 9)
        let (viewModel, _, _) = makeViewModel([upcoming, passed])

        #expect(viewModel.chipState(for: upcoming.id, at: TestTime.now)
                == .scheduled(title: "Stretch", whenText: "Today, \(clock(15, 0))"))
        #expect(viewModel.chipState(for: passed.id, at: TestTime.now) == .past)
        // Sudah dibuang ReminderStore karena lewat lebih dari sehari.
        #expect(viewModel.chipState(for: UUID(), at: TestTime.now) == .past)

        await viewModel.cancel(upcoming.id)

        #expect(viewModel.chipState(for: upcoming.id, at: TestTime.now) == .removed)
    }

    @Test func permissionIsReadFromTheScheduler() async {
        let (viewModel, _, scheduler) = makeViewModel()
        scheduler.notificationsAllowedAnswer = false

        await viewModel.refreshPermission()

        #expect(viewModel.notificationsAllowed == false)
    }
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS,arch=arm64' -only-testing:DinoPocketTests/ReminderListViewModelTests 2>&1 | grep -E "Test run with|TEST (SUCCEEDED|FAILED)|error:|✘"`
Expected: FAIL, dengan `error: cannot find 'ReminderListViewModel' in scope`.

- [ ] **Step 3: Tambahkan `notificationsAllowed()` ke penjadwal**

Di `SharedCore/Infrastructure/Services/ReminderScheduling.swift`, ganti protokolnya dengan:

```swift
protocol ReminderScheduling: Sendable {
    func requestAuthorization() async -> Bool
    /// Apakah macOS saat ini mengizinkan Apl menampilkan notifikasi. Tidak
    /// pernah memunculkan dialog; dipakai petunjuk "Notifications are off".
    func notificationsAllowed() async -> Bool
    /// Menyamakan notifikasi tertunda dengan daftar reminder: semua milik Apl
    /// dihapus, lalu kemunculan terdekat dijadwalkan ulang.
    func sync(_ reminders: [Reminder], now: Date) async
    func cancelAll() async
}
```

Di `SharedCore/Infrastructure/Services/ReminderNotificationCenter.swift`, tepat setelah fungsi `requestAuthorization()`, tambahkan:

```swift

    /// Hanya Bool yang keluar dari completion handler, dengan alasan yang
    /// sama seperti `pendingReminderIDs()`.
    func notificationsAllowed() async -> Bool {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                let status = settings.authorizationStatus
                continuation.resume(returning: status == .authorized || status == .provisional)
            }
        }
    }
```

Di `DinoPocketTests/ReminderFakes.swift`, di dalam `SpyReminderScheduler`, ganti baris

```swift
    var authorizationAnswer = true

    func requestAuthorization() async -> Bool { authorizationAnswer }
```

dengan

```swift
    var authorizationAnswer = true
    var notificationsAllowedAnswer = true

    func requestAuthorization() async -> Bool { authorizationAnswer }

    func notificationsAllowed() async -> Bool { notificationsAllowedAnswer }
```

- [ ] **Step 4: Buat `ReminderListViewModel`**

Buat `DinoPocketMac/Presentation/ViewModels/ReminderListViewModel.swift`:

```swift
//
//  ReminderListViewModel.swift
//  Apl
//
//  Reminder untuk Up next, popover, dan chip di chat (spec B §6). Membaca
//  store reminder dari A; setiap perubahan menjadwalkan ulang notifikasi
//  lewat UseCase yang sama dengan jalur chat.
//

import Foundation
import Observation

/// Isi chip di bawah konfirmasi reminder.
enum ReminderChipState: Equatable {
    case scheduled(title: String, whenText: String)
    /// Sudah lewat — termasuk yang sudah dibuang ReminderStore karena lewat
    /// lebih dari sehari.
    case past
    /// Dibatalkan pengguna di sesi ini (Undo di chip atau di popover).
    case removed
}

@MainActor
@Observable
final class ReminderListViewModel {

    struct Row: Identifiable, Equatable {
        let reminder: Reminder
        let next: Date
        let whenText: String

        var id: Reminder.ID { reminder.id }

        var repeatsDaily: Bool {
            if case .daily = reminder.rule { return true }
            return false
        }
    }

    nonisolated static let upNextLimit = 3

    /// Reminder terakhir yang dibatalkan, untuk Undo di popover.
    private(set) var lastCancelled: Reminder?
    private(set) var notificationsAllowed: Bool
    private var removedIDs: Set<Reminder.ID> = []

    private let store: any ReminderStoring
    private let notifications: any ReminderScheduling
    private let now: () -> Date
    private let calendar: Calendar
    private let locale: Locale

    init(store: any ReminderStoring,
         notifications: any ReminderScheduling,
         now: @escaping () -> Date = { .now },
         calendar: Calendar = .current,
         locale: Locale = .current,
         notificationsAllowed: Bool = true) {
        self.store = store
        self.notifications = notifications
        self.now = now
        self.calendar = calendar
        self.locale = locale
        self.notificationsAllowed = notificationsAllowed
    }

    // MARK: - Membaca

    /// Reminder yang masih akan muncul, terdekat dulu. `.once` yang sudah lewat tidak ikut.
    /// `date` diberikan view (TimelineView), supaya daftar ikut bergeser seiring waktu.
    func rows(at date: Date) -> [Row] {
        store.reminders
            .compactMap { reminder in
                reminder.nextOccurrence(after: date, calendar: calendar).map { (reminder, $0) }
            }
            .sorted { $0.1 < $1.1 }
            .map {
                Row(reminder: $0.0, next: $0.1,
                    whenText: Self.whenText(for: $0.0.rule, next: $0.1, now: date,
                                            calendar: calendar, locale: locale))
            }
    }

    func upNext(at date: Date) -> [Row] {
        Array(rows(at: date).prefix(Self.upNextLimit))
    }

    func reminder(withID id: Reminder.ID) -> Reminder? {
        store.reminders.first { $0.id == id }
    }

    func chipState(for id: Reminder.ID, at date: Date) -> ReminderChipState {
        guard let reminder = reminder(withID: id) else {
            return removedIDs.contains(id) ? .removed : .past
        }
        guard let next = reminder.nextOccurrence(after: date, calendar: calendar) else {
            return .past
        }
        return .scheduled(title: reminder.title,
                          whenText: Self.whenText(for: reminder.rule, next: next, now: date,
                                                  calendar: calendar, locale: locale))
    }

    // MARK: - Mengubah

    func cancel(_ id: Reminder.ID) async {
        guard let reminder = reminder(withID: id) else { return }
        lastCancelled = reminder
        removedIDs.insert(id)
        await CancelReminderUseCase(store: store, notifications: notifications, now: now).execute(id: id)
    }

    /// Mengembalikan reminder yang terakhir dibatalkan, dengan id yang sama.
    func undo() async {
        guard let reminder = lastCancelled else { return }
        lastCancelled = nil
        removedIDs.remove(reminder.id)
        store.add(reminder)
        await notifications.sync(store.reminders, now: now())
    }

    func update(_ reminder: Reminder) async {
        await UpdateReminderUseCase(store: store, notifications: notifications, now: now).execute(reminder)
    }

    func refreshPermission() async {
        notificationsAllowed = await notifications.notificationsAllowed()
    }

    // MARK: - Teks

    /// "Today, 3:00 PM" · "Tomorrow, 9:00 AM" · "Every day, 9:00 AM" · "Sep 19, 9:00 AM"
    nonisolated static func whenText(for rule: Reminder.Rule, next: Date, now: Date,
                                     calendar: Calendar, locale: Locale) -> String {
        let clock = ReminderPhrasing.time(next, calendar: calendar, locale: locale)
        if case .daily = rule {
            return "Every day, \(clock)"
        }
        if calendar.isDate(next, inSameDayAs: now) {
            return "Today, \(clock)"
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(next, inSameDayAs: tomorrow) {
            return "Tomorrow, \(clock)"
        }
        let dayStyle = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            .month(.abbreviated)
            .day()
        return "\(next.formatted(dayStyle)), \(clock)"
    }
}
```

- [ ] **Step 5: Buat data preview**

Buat `DinoPocketMac/Presentation/PreviewSupport.swift`:

```swift
//
//  PreviewSupport.swift
//  Apl
//
//  Data dan penyimpanan palsu untuk #Preview.
//
//  SENGAJA tidak dibungkus `#if DEBUG`: blok #Preview ikut dikompilasi di
//  Release, dan helper yang hilang di Release baru ketahuan saat archive.
//  Penyimpanan preview memakai suite UserDefaults sendiri, bukan data app.
//

import Foundation

enum PreviewData {

    static let stretchID = UUID(uuidString: "5A1E0000-0000-4000-8000-000000000001")!

    static func reminders(now: Date = .now) -> [Reminder] {
        [
            Reminder(id: stretchID, title: "Stretch",
                     rule: .once(now.addingTimeInterval(45 * 60)), createdAt: now),
            Reminder(title: "Drink water", rule: .daily(hour: 9, minute: 0), createdAt: now),
            Reminder(title: "Call mom", rule: .once(now.addingTimeInterval(26 * 60 * 60)), createdAt: now),
            Reminder(title: "Write stand-up notes", rule: .daily(hour: 16, minute: 30), createdAt: now),
        ]
    }

    static var messages: [ChatMessage] {
        [
            ChatMessage(role: .user, text: "Any tips to stay focused this afternoon?"),
            ChatMessage(role: .assistant, text: """
                Try **25-minute blocks** with a short break between them:

                - Close the tabs you don't need
                - Put your phone out of reach

                ```swift
                let block = Duration.seconds(25 * 60)
                ```
                """),
            ChatMessage(role: .user, text: "Remind me to stretch in 45 minutes"),
            ChatMessage(role: .assistant, text: "Done — I'll remind you to stretch in 45 minutes.",
                        attachment: .reminder(stretchID)),
        ]
    }
}

/// Penjadwal yang tidak menjadwalkan apa pun.
struct PreviewReminderScheduler: ReminderScheduling {
    var allowed = true

    func requestAuthorization() async -> Bool { allowed }
    func notificationsAllowed() async -> Bool { allowed }
    func sync(_ reminders: [Reminder], now: Date) async {}
    func cancelAll() async {}
}

extension ReminderListViewModel {
    static func preview(_ reminders: [Reminder] = PreviewData.reminders(),
                        notificationsAllowed: Bool = true) -> ReminderListViewModel {
        let store = ReminderStore(defaults: UserDefaults(suiteName: "apl.preview.reminders")!)
        store.eraseAllStoredData()
        for reminder in reminders {
            store.add(reminder)
        }
        return ReminderListViewModel(store: store,
                                     notifications: PreviewReminderScheduler(allowed: notificationsAllowed),
                                     notificationsAllowed: notificationsAllowed)
    }
}

extension ChatStore {
    static func preview(_ messages: [ChatMessage] = PreviewData.messages,
                        isStreaming: Bool = false) -> ChatStore {
        let store = ChatStore(brain: nil, defaults: UserDefaults(suiteName: "apl.preview.chat")!)
        store.messages = messages
        store.isStreaming = isStreaming
        return store
    }
}
```

- [ ] **Step 6: Jalankan test, pastikan lulus**

Run: perintah Step 2.
Expected: `Test run with 9 tests` … `** TEST SUCCEEDED **`

- [ ] **Step 7: Jalankan seluruh test**

Run: perintah test semua.
Expected: `** TEST SUCCEEDED **` (±135 test).

- [ ] **Step 8: Commit**

```bash
git add SharedCore/Infrastructure/Services/ReminderScheduling.swift \
  SharedCore/Infrastructure/Services/ReminderNotificationCenter.swift \
  DinoPocketTests/ReminderFakes.swift DinoPocketTests/ReminderListViewModelTests.swift \
  DinoPocketMac/Presentation/ViewModels/ReminderListViewModel.swift \
  DinoPocketMac/Presentation/PreviewSupport.swift
git commit -m "$(cat <<'EOF'
feat(b7): ReminderListViewModel untuk Up next, popover, dan chip

Reminder diurutkan menurut kemunculan terdekat, dan sekali jalan yang
sudah lewat disembunyikan. Batal dan edit memakai UseCase A. Undo
mengembalikan reminder dengan id yang sama, dan chip membedakan
terjadwal, sudah lewat, dan dibatalkan. Penjadwal kini bisa ditanya
apakah notifikasi diizinkan tanpa memunculkan dialog. Data preview
berbagi satu berkas dan tidak dibungkus #if DEBUG.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Pesan di percakapan — Markdown, bubble, chip, gagal

**Files:**
- Create: `DinoPocketMac/Presentation/Chat/MarkdownBlocks.swift`
- Create: `DinoPocketMac/Presentation/Chat/MessageViews.swift`
- Create: `DinoPocketMac/Presentation/Chat/ReminderChip.swift`
- Create: `DinoPocketMac/Presentation/Chat/MessageRow.swift`
- Test: `DinoPocketTests/MarkdownBlocksTests.swift`, `DinoPocketTests/MessageRowTests.swift`

**Interfaces:**
- Consumes:
  - `AppColor`, `Radius`, `AppFont`, `Spacing` (Task 1)
  - `ChatMessage.attachment` / `.status` (Task 2)
  - `ReminderListViewModel.chipState(for:at:)` / `.cancel(_:)`, `ReminderChipState`, `ReminderListViewModel.preview`, `PreviewData` (Task 7)
- Produces:
  - `enum MarkdownBlock: Equatable { case text(String); case code(language: String?, code: String, isClosed: Bool) }`
  - `enum MarkdownBlocks { static func split(_ source: String) -> [MarkdownBlock] }`
  - `UserBubble(text:)`
  - `AssistantMessage(text:isStopped:)` dengan `static func attributed(_:) -> AttributedString`
  - `FailedMessage(text:onRetry:)`, dengan `onRetry: (() -> Void)?`; nil menyembunyikan tombol
  - `TypingIndicator()`
  - `ReminderChip(state:onUndo:)`
  - `enum MessageRowKind: Equatable { case user; case assistant(stopped: Bool); case reminderConfirmation(Reminder.ID); case failed }`
  - `MessageRow(message:reminders:canRetry:onRetry:)` dengan `nonisolated static func kind(of: ChatMessage) -> MessageRowKind`

- [ ] **Step 1: Tulis test yang gagal**

Buat `DinoPocketTests/MarkdownBlocksTests.swift`:

```swift
import Testing
@testable import Apl

struct MarkdownBlocksTests {

    @Test func plainTextIsASingleBlock() {
        #expect(MarkdownBlocks.split("Hello **there**") == [.text("Hello **there**")])
    }

    @Test func fencedCodeIsSeparatedFromText() {
        let source = "Here you go:\n```swift\nlet a = 1\nprint(a)\n```\nThat's it."

        #expect(MarkdownBlocks.split(source) == [
            .text("Here you go:"),
            .code(language: "swift", code: "let a = 1\nprint(a)", isClosed: true),
            .text("That's it."),
        ])
    }

    /// Saat streaming, pagar penutup belum datang. Sisa teks tetap tampil
    /// sebagai kode, bukan hilang atau dirender sebagai Markdown rusak.
    @Test func unclosedFenceWhileStreamingStaysCode() {
        #expect(MarkdownBlocks.split("Try:\n```\nprint(1)") == [
            .text("Try:"),
            .code(language: nil, code: "print(1)", isClosed: false),
        ])
    }

    /// List dan paragraf tetap satu blok teks; baris kosong di dalamnya dipertahankan.
    @Test func blankLinesInsideTextAreKept() {
        #expect(MarkdownBlocks.split("First\n\n- one\n- two\n") == [.text("First\n\n- one\n- two")])
    }

    @Test func emptyInputHasNoBlocks() {
        #expect(MarkdownBlocks.split("").isEmpty)
        #expect(MarkdownBlocks.split("\n\n").isEmpty)
    }
}
```

Buat `DinoPocketTests/MessageRowTests.swift`:

```swift
import Foundation
import Testing
@testable import Apl

struct MessageRowTests {

    /// Cara pesan dirender ditentukan data (peran, status, lampiran), bukan bunyi teksnya.
    @Test func rowKindFollowsRoleStatusAndAttachment() {
        let id = UUID()

        #expect(MessageRow.kind(of: ChatMessage(role: .user, text: "hi")) == .user)
        #expect(MessageRow.kind(of: ChatMessage(role: .assistant, text: "yo")) == .assistant(stopped: false))
        #expect(MessageRow.kind(of: ChatMessage(role: .assistant, text: "yo", status: .stopped))
                == .assistant(stopped: true))
        #expect(MessageRow.kind(of: ChatMessage(role: .assistant, text: "Done", attachment: .reminder(id)))
                == .reminderConfirmation(id))
        #expect(MessageRow.kind(of: ChatMessage(role: .assistant, text: "", status: .failed)) == .failed)
    }
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS,arch=arm64' -only-testing:DinoPocketTests/MarkdownBlocksTests -only-testing:DinoPocketTests/MessageRowTests 2>&1 | grep -E "Test run with|TEST (SUCCEEDED|FAILED)|error:|✘"`
Expected: FAIL, dengan `error: cannot find 'MarkdownBlocks' in scope` dan `cannot find 'MessageRow' in scope`.

- [ ] **Step 3: Tulis `MarkdownBlocks`**

Buat `DinoPocketMac/Presentation/Chat/MarkdownBlocks.swift`:

```swift
//
//  MarkdownBlocks.swift
//  Apl
//
//  Memisahkan jawaban asisten menjadi teks dan blok kode berpagar (```).
//
//  `AttributedString(markdown:)` hanya dipakai untuk markup inline (tebal,
//  kode inline); blok kode butuh tampilannya sendiri. Pemisahan dibuat
//  toleran karena teks datang sepotong-sepotong: pagar yang belum ditutup
//  tetap menjadi blok kode sampai penutupnya tiba (spec B §9).
//

import Foundation

enum MarkdownBlock: Equatable {
    case text(String)
    case code(language: String?, code: String, isClosed: Bool)
}

enum MarkdownBlocks {

    static func split(_ source: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var textLines: [Substring] = []
        var codeLines: [Substring] = []
        var language: String?
        var inCode = false

        func flushText() {
            let text = textLines.joined(separator: "\n").trimmingCharacters(in: .newlines)
            if !text.isEmpty { blocks.append(.text(text)) }
            textLines.removeAll()
        }

        for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                if inCode {
                    blocks.append(.code(language: language, code: codeLines.joined(separator: "\n"),
                                        isClosed: true))
                    codeLines.removeAll()
                    language = nil
                    inCode = false
                } else {
                    flushText()
                    let tag = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
                    language = tag.isEmpty ? nil : tag
                    inCode = true
                }
            } else if inCode {
                codeLines.append(line)
            } else {
                textLines.append(line)
            }
        }

        if inCode {
            blocks.append(.code(language: language, code: codeLines.joined(separator: "\n"), isClosed: false))
        } else {
            flushText()
        }
        return blocks
    }
}
```

- [ ] **Step 4: Tulis tampilan pesan**

Buat `DinoPocketMac/Presentation/Chat/MessageViews.swift`:

```swift
//
//  MessageViews.swift
//  Apl
//
//  Potongan tampilan percakapan (spec B §5–§6): bubble pengguna, teks
//  asisten tanpa bubble, jawaban gagal, dan indikator mengetik.
//

import SwiftUI

/// Pesan pengguna: bubble beraksen di kanan, maksimal 420pt.
struct UserBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .textSelection(.enabled)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(AppColor.userBubble, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .frame(maxWidth: 420, alignment: .trailing)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

/// Jawaban asisten: teks polos menyatu dengan jendela, maksimal 460pt, Markdown.
struct AssistantMessage: View {
    let text: String
    var isStopped = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(Array(MarkdownBlocks.split(text).enumerated()), id: \.offset) { _, block in
                switch block {
                case .text(let paragraph):
                    Text(Self.attributed(paragraph))
                        .fixedSize(horizontal: false, vertical: true)
                case .code(let language, let code, _):
                    CodeBlock(language: language, code: code)
                }
            }
            if isStopped {
                Label("Stopped", systemImage: "stop.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .textSelection(.enabled)
        .frame(maxWidth: 460, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Markup inline saja; spasi dan baris baru dipertahankan sehingga list
    /// tetap terbaca. Markdown yang belum lengkap saat streaming tampil apa adanya.
    static func attributed(_ markdown: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: markdown, options: options)) ?? AttributedString(markdown)
    }
}

private struct CodeBlock: View {
    let language: String?
    let code: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if let language {
                Text(language)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(AppFont.code)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.controlFill, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
    }
}

/// Jawaban yang gagal (spec B §9). Teks yang sempat tertulis tetap tampil;
/// tombol Retry hanya ada untuk jawaban terakhir.
struct FailedMessage: View {
    let text: String
    let onRetry: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if !text.isEmpty {
                AssistantMessage(text: text)
            }
            HStack(spacing: Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppColor.statusWarning)
                Text("Apl couldn't finish this reply.")
                    .foregroundStyle(.secondary)
                if let onRetry {
                    Button("Retry", action: onRetry)
                        .buttonStyle(.link)
                }
            }
            .font(.callout)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Tiga titik bergantian menyala selama jawaban belum mulai tertulis.
struct TypingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.35, paused: reduceMotion)) { context in
            let lit = reduceMotion ? -1 : Int(context.date.timeIntervalSinceReferenceDate / 0.35) % 3
            HStack(spacing: Spacing.xs) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(.secondary)
                        .frame(width: 6, height: 6)
                        .opacity(index == lit ? 1 : 0.35)
                }
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement()
        .accessibilityLabel("Apl is typing")
    }
}

#Preview("Messages · Light") {
    VStack(spacing: Spacing.lg) {
        UserBubble(text: "Any tips to stay focused this afternoon?")
        AssistantMessage(text: PreviewData.messages[1].text)
        AssistantMessage(text: "Here's the first part of", isStopped: true)
        FailedMessage(text: "", onRetry: {})
        TypingIndicator()
    }
    .padding(Spacing.xl)
    .frame(width: 640)
}

#Preview("Messages · Dark") {
    VStack(spacing: Spacing.lg) {
        UserBubble(text: "Any tips to stay focused this afternoon?")
        AssistantMessage(text: PreviewData.messages[1].text)
        FailedMessage(text: "Half a reply", onRetry: {})
        TypingIndicator()
    }
    .padding(Spacing.xl)
    .frame(width: 640)
    .preferredColorScheme(.dark)
}
```

Buat `DinoPocketMac/Presentation/Chat/ReminderChip.swift`:

```swift
//
//  ReminderChip.swift
//  Apl
//
//  Chip di bawah konfirmasi reminder: bukti reminder itu ada, dan jalan
//  tercepat untuk membatalkannya (spec B §6).
//

import SwiftUI

struct ReminderChip: View {
    let state: ReminderChipState
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            switch state {
            case .scheduled(let title, let whenText):
                Image(systemName: "bell.fill")
                    .foregroundStyle(AppColor.accent)
                Text(title)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(whenText)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Button("Undo", action: onUndo)
                    .buttonStyle(.link)
            case .past:
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.secondary)
                Text("Reminder passed")
                    .foregroundStyle(.secondary)
            case .removed:
                Image(systemName: "bell.slash")
                    .foregroundStyle(.secondary)
                Text("Reminder removed")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.callout)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 6)
        .background(AppColor.controlFill, in: Capsule())
        .accessibilityElement(children: .contain)
    }
}

#Preview("Chip · Light") {
    VStack(alignment: .leading, spacing: Spacing.sm) {
        ReminderChip(state: .scheduled(title: "Stretch", whenText: "Today, 3:00 PM"), onUndo: {})
        ReminderChip(state: .past, onUndo: {})
        ReminderChip(state: .removed, onUndo: {})
    }
    .padding()
}

#Preview("Chip · Dark") {
    VStack(alignment: .leading, spacing: Spacing.sm) {
        ReminderChip(state: .scheduled(title: "Stretch", whenText: "Every day, 9:00 AM"), onUndo: {})
        ReminderChip(state: .removed, onUndo: {})
    }
    .padding()
    .preferredColorScheme(.dark)
}
```

Buat `DinoPocketMac/Presentation/Chat/MessageRow.swift`:

```swift
//
//  MessageRow.swift
//  Apl
//
//  Satu baris percakapan. Bentuknya dipilih dari data pesan — peran, status,
//  lampiran — tidak pernah dari bunyi teksnya.
//

import SwiftUI

enum MessageRowKind: Equatable {
    case user
    case assistant(stopped: Bool)
    case reminderConfirmation(Reminder.ID)
    case failed
}

struct MessageRow: View {
    let message: ChatMessage
    let reminders: ReminderListViewModel
    /// Hanya jawaban gagal yang TERAKHIR yang bisa diulang (lihat `ChatStore.retry`).
    let canRetry: Bool
    let onRetry: () -> Void

    nonisolated static func kind(of message: ChatMessage) -> MessageRowKind {
        if message.role == .user { return .user }
        if message.status == .failed { return .failed }
        if case .reminder(let id)? = message.attachment { return .reminderConfirmation(id) }
        return .assistant(stopped: message.status == .stopped)
    }

    var body: some View {
        switch Self.kind(of: message) {
        case .user:
            UserBubble(text: message.text)
        case .assistant(let stopped):
            // Placeholder kosong selama menunggu potongan pertama: yang tampil
            // TypingIndicator, bukan baris kosong.
            if !message.text.isEmpty {
                AssistantMessage(text: message.text, isStopped: stopped)
            }
        case .reminderConfirmation(let id):
            VStack(alignment: .leading, spacing: Spacing.sm) {
                AssistantMessage(text: message.text)
                ReminderChip(state: reminders.chipState(for: id, at: .now),
                             onUndo: { Task { await reminders.cancel(id) } })
            }
        case .failed:
            FailedMessage(text: message.text, onRetry: canRetry ? onRetry : nil)
        }
    }
}

#Preview("Rows · Light") {
    let reminders = ReminderListViewModel.preview()
    VStack(spacing: Spacing.lg) {
        ForEach(PreviewData.messages) { message in
            MessageRow(message: message, reminders: reminders, canRetry: false, onRetry: {})
        }
        MessageRow(message: ChatMessage(role: .assistant, text: "", status: .failed),
                   reminders: reminders, canRetry: true, onRetry: {})
    }
    .padding(Spacing.xl)
    .frame(width: 640)
}

#Preview("Rows · Dark") {
    let reminders = ReminderListViewModel.preview()
    VStack(spacing: Spacing.lg) {
        ForEach(PreviewData.messages) { message in
            MessageRow(message: message, reminders: reminders, canRetry: false, onRetry: {})
        }
    }
    .padding(Spacing.xl)
    .frame(width: 640)
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 5: Jalankan test, pastikan lulus, lalu build**

Run: perintah Step 2.
Expected: `Test run with 6 tests` … `** TEST SUCCEEDED **`

Run: perintah build.
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add DinoPocketMac/Presentation/Chat DinoPocketTests/MarkdownBlocksTests.swift DinoPocketTests/MessageRowTests.swift
git commit -m "$(cat <<'EOF'
feat(b8): tampilan pesan — Markdown, chip reminder, jawaban gagal

Jawaban asisten dipecah menjadi teks inline-Markdown dan blok kode yang
toleran terhadap pagar yang belum ditutup saat streaming. Bubble
pengguna dan teks asisten mengikuti lebar spec. Konfirmasi reminder
membawa chip dengan Undo. Jawaban gagal tampil dengan Retry, dan
indikator mengetik patuh Reduce Motion.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: Composer, banner AI, dan tombol

**Files:**
- Create: `DinoPocketMac/Presentation/Chat/ComposerState.swift`
- Create: `DinoPocketMac/Presentation/Chat/Composer.swift`
- Create: `DinoPocketMac/Presentation/Chat/AIUnavailableBanner.swift`
- Create: `DinoPocketMac/Presentation/Components/IconButton.swift`
- Create: `DinoPocketMac/Presentation/Components/StageButton.swift`
- Test: `DinoPocketTests/ComposerStateTests.swift`

**Interfaces:**
- Consumes: `BrainAvailability` (A), token Task 1
- Produces:
  - `enum ComposerState: Equatable`:
    - `case ready, streaming, preparing, unavailable(String)`
    - `static func current(availability: BrainAvailability?, isStreaming: Bool) -> ComposerState`
    - `var acceptsInput: Bool`, `var placeholder: String`
  - `Composer(draft: Binding<String>, state: ComposerState, onSend: () -> Void, onStop: () -> Void)`. Pemanggil yang mengosongkan draft.
  - `AIUnavailableBanner(availability: BrainAvailability, onOpenSettings: () -> Void)`
  - `IconButton(systemImage: String, label: String, isOn: Bool = false, action: () -> Void)`
  - `StageButton(title: String, systemImage: String, isOn: Bool = false, action: () -> Void)`

- [ ] **Step 1: Tulis test yang gagal**

Buat `DinoPocketTests/ComposerStateTests.swift`:

```swift
import Testing
@testable import Apl

struct ComposerStateTests {

    @Test func streamingWinsOverAvailability() {
        #expect(ComposerState.current(availability: .ready, isStreaming: true) == .streaming)
        #expect(ComposerState.current(availability: nil, isStreaming: true) == .streaming)
    }

    @Test func availabilityDecidesTheRest() {
        #expect(ComposerState.current(availability: .ready, isStreaming: false) == .ready)
        #expect(ComposerState.current(availability: .needsSetup("x"), isStreaming: false) == .preparing)
        #expect(ComposerState.current(availability: nil, isStreaming: false) == .preparing)
        #expect(ComposerState.current(availability: .unavailable("off"), isStreaming: false) == .unavailable("off"))
    }

    /// Apple Intelligence mati tidak mengunci composer: reminder lewat chat
    /// tetap harus bisa dibuat (deviasi 9). Hanya model yang sedang
    /// disiapkan yang mengunci (spec B §9).
    @Test func onlyAModelBeingPreparedLocksTheComposer() {
        #expect(ComposerState.ready.acceptsInput)
        #expect(ComposerState.streaming.acceptsInput)
        #expect(ComposerState.unavailable("off").acceptsInput)
        #expect(!ComposerState.preparing.acceptsInput)
    }
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS,arch=arm64' -only-testing:DinoPocketTests/ComposerStateTests 2>&1 | grep -E "Test run with|TEST (SUCCEEDED|FAILED)|error:|✘"`
Expected: FAIL, dengan `error: cannot find 'ComposerState' in scope`.

- [ ] **Step 3: Tulis `ComposerState`**

Buat `DinoPocketMac/Presentation/Chat/ComposerState.swift`:

```swift
//
//  ComposerState.swift
//  Apl
//
//  Keadaan kolom tulis, diturunkan dari availability dan streaming (spec B §9).
//

import Foundation

enum ComposerState: Equatable {
    case ready
    case streaming
    /// Model sedang diunduh, atau availability belum selesai dicek.
    case preparing
    case unavailable(String)

    static func current(availability: BrainAvailability?, isStreaming: Bool) -> ComposerState {
        if isStreaming { return .streaming }
        switch availability {
        case .ready?:
            return .ready
        case .needsSetup?, nil:
            return .preparing
        case .unavailable(let reason)?:
            return .unavailable(reason)
        }
    }

    /// Saat Apple Intelligence mati, composer TETAP terbuka: reminder dibuat
    /// tanpa AI, dan pesan lain dijawab ChatStore dengan pemberitahuan.
    /// Selama streaming, pengguna boleh mengetik pesan berikutnya.
    var acceptsInput: Bool {
        self != .preparing
    }

    var placeholder: String {
        switch self {
        case .ready, .streaming: "Message Apl…"
        case .preparing: "Getting ready…"
        case .unavailable: "Ask Apl for a reminder…"
        }
    }
}
```

- [ ] **Step 4: Jalankan test, pastikan lulus**

Run: perintah Step 2.
Expected: `Test run with 3 tests` … `** TEST SUCCEEDED **`

- [ ] **Step 5: Tulis tombol reusable**

Buat `DinoPocketMac/Presentation/Components/IconButton.swift`:

```swift
//
//  IconButton.swift
//  Apl
//
//  Tombol ikon 28pt tanpa bingkai; latarnya muncul saat disorot (spec B §7).
//

import SwiftUI

struct IconButton: View {
    let systemImage: String
    /// Dibacakan VoiceOver dan tampil sebagai tooltip.
    let label: String
    var isOn = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(IconButtonStyle(isOn: isOn))
        .help(label)
        .accessibilityLabel(label)
    }
}

private struct IconButtonStyle: ButtonStyle {
    let isOn: Bool

    func makeBody(configuration: Configuration) -> some View {
        IconButtonBody(configuration: configuration, isOn: isOn)
    }
}

/// View terpisah karena `ButtonStyle` sendiri tidak bisa memegang state hover.
private struct IconButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let isOn: Bool

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    var body: some View {
        configuration.label
            .foregroundStyle(isOn ? AppColor.accent : Color.secondary)
            .background(
                RoundedRectangle(cornerRadius: Radius.iconButton, style: .continuous)
                    .fill(isHovering || configuration.isPressed ? AppColor.controlFill : Color.clear)
            )
            .opacity(isEnabled ? 1 : 0.4)
            .contentShape(RoundedRectangle(cornerRadius: Radius.iconButton, style: .continuous))
            .onHover { isHovering = $0 }
    }
}

#Preview("Light") {
    HStack(spacing: Spacing.sm) {
        IconButton(systemImage: "gearshape", label: "Settings") {}
        IconButton(systemImage: "figure.stand", label: "Buddy Mode", isOn: true) {}
        IconButton(systemImage: "trash", label: "Remove") {}
            .disabled(true)
    }
    .padding()
}

#Preview("Dark") {
    HStack(spacing: Spacing.sm) {
        IconButton(systemImage: "gearshape", label: "Settings") {}
        IconButton(systemImage: "figure.stand", label: "Buddy Mode", isOn: true) {}
    }
    .padding()
    .preferredColorScheme(.dark)
}
```

Buat `DinoPocketMac/Presentation/Components/StageButton.swift`:

```swift
//
//  StageButton.swift
//  Apl
//
//  Tombol utama di kaki stage (Buddy Mode). Beraksen saat menyala.
//

import SwiftUI

struct StageButton: View {
    let title: String
    let systemImage: String
    var isOn = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(isOn ? AppColor.accent : nil)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

#Preview("Light") {
    VStack(spacing: Spacing.sm) {
        StageButton(title: "Buddy Mode", systemImage: "figure.stand") {}
        StageButton(title: "Hide Buddy", systemImage: "figure.stand", isOn: true) {}
    }
    .padding()
    .frame(width: 260)
}

#Preview("Dark") {
    StageButton(title: "Buddy Mode", systemImage: "figure.stand") {}
        .padding()
        .frame(width: 260)
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 6: Tulis `Composer` dan `AIUnavailableBanner`**

Buat `DinoPocketMac/Presentation/Chat/Composer.swift`:

```swift
//
//  Composer.swift
//  Apl
//
//  Kolom tulis (spec B §5, §7): kapsul 40pt, tombol kirim bulat 28pt.
//  Return mengirim, ⇧Return menambah baris, Esc menghentikan jawaban.
//

import SwiftUI

struct Composer: View {
    @Binding var draft: String
    let state: ComposerState
    let onSend: () -> Void
    let onStop: () -> Void

    @FocusState private var isFocused: Bool

    private var canSend: Bool {
        state.acceptsInput && state != .streaming
            && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.sm) {
            TextField(state.placeholder, text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .focused($isFocused)
                .disabled(!state.acceptsInput)
                .onSubmit { submit() }
                // SwiftUI tidak memberi akses ke posisi kursor, jadi ⇧Return
                // menambah baris di akhir draft (deviasi 3). ⌥Return bawaan
                // field editor tetap menyisipkan di posisi kursor.
                .onKeyPress(.return, phases: .down) { press in
                    guard press.modifiers.contains(.shift) else { return .ignored }
                    draft += "\n"
                    return .handled
                }
                .onKeyPress(.escape) {
                    guard state == .streaming else { return .ignored }
                    onStop()
                    return .handled
                }
                .padding(.vertical, 11)
            actionButton
                .padding(.bottom, 6)
        }
        .padding(.leading, Spacing.lg)
        .padding(.trailing, 6)
        .frame(minHeight: 40)
        .background(AppColor.controlFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.separator))
        .task { isFocused = true }
    }

    @ViewBuilder
    private var actionButton: some View {
        if state == .streaming {
            Button { onStop() } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(RoundActionButtonStyle(isActive: true))
            .help("Stop (Esc)")
            .accessibilityLabel("Stop")
        } else {
            Button { submit() } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 13, weight: .bold))
            }
            .buttonStyle(RoundActionButtonStyle(isActive: canSend))
            .disabled(!canSend)
            .help("Send (Return)")
            .accessibilityLabel("Send")
        }
    }

    private func submit() {
        guard canSend else { return }
        onSend()
    }
}

/// Tombol bulat 28pt berwarna aksen. Ikonnya memakai warna latar teks,
/// sehingga tetap kontras di atas teal gelap (light) maupun teal terang (dark).
private struct RoundActionButtonStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isActive ? Color(nsColor: .textBackgroundColor) : Color.secondary)
            .frame(width: 28, height: 28)
            .background(Circle().fill(isActive ? AppColor.accent : AppColor.controlFill))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(Circle())
    }
}

#Preview("Composer · Light") {
    @Previewable @State var draft = "Remind me to stretch at 3 PM"
    VStack(spacing: Spacing.md) {
        Composer(draft: $draft, state: .ready, onSend: {}, onStop: {})
        Composer(draft: .constant(""), state: .streaming, onSend: {}, onStop: {})
        Composer(draft: .constant(""), state: .preparing, onSend: {}, onStop: {})
    }
    .padding()
    .frame(width: 560)
}

#Preview("Composer · Dark") {
    @Previewable @State var draft = ""
    VStack(spacing: Spacing.md) {
        Composer(draft: $draft, state: .unavailable("Enable Apple Intelligence in System Settings."),
                 onSend: {}, onStop: {})
        Composer(draft: .constant("Hello"), state: .ready, onSend: {}, onStop: {})
    }
    .padding()
    .frame(width: 560)
    .preferredColorScheme(.dark)
}
```

Buat `DinoPocketMac/Presentation/Chat/AIUnavailableBanner.swift`:

```swift
//
//  AIUnavailableBanner.swift
//  Apl
//
//  Tampil di atas composer saat Apple Intelligence tidak siap (spec B §9).
//
//  Ini bukan hiasan. Reviewer App Store bisa saja memakai Mac tanpa Apple
//  Intelligence aktif; tanpa penjelasan yang jelas, chat yang diam tampak
//  seperti fitur rusak dan itu alasan penolakan yang sah. Banner menyatakan
//  penyebabnya, menawarkan jalan keluar, dan menegaskan reminder tetap jalan.
//

import SwiftUI

struct AIUnavailableBanner: View {
    let availability: BrainAvailability
    let onOpenSettings: () -> Void

    /// `.needsSetup` berarti model sedang disiapkan sistem — menawarkan tombol
    /// System Settings di situ hanya menyesatkan, yang dibutuhkan cuma menunggu.
    private var isPreparing: Bool {
        if case .needsSetup = availability { return true }
        return false
    }

    private var reason: String {
        switch availability {
        case .ready: ""
        case .needsSetup(let text), .unavailable(let text): text
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: isPreparing ? "arrow.down.circle" : "apple.intelligence")
                .font(.title3)
                .foregroundStyle(isPreparing ? Color.secondary : AppColor.statusWarning)
            VStack(alignment: .leading, spacing: 2) {
                Text(isPreparing ? "Getting Apple Intelligence ready" : "Chat needs Apple Intelligence")
                    .font(.callout.weight(.semibold))
                Text("\(reason) Reminders still work.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Spacing.sm)
            if !isPreparing {
                Button("Open System Settings", action: onOpenSettings)
                    .controlSize(.small)
            }
        }
        .padding(Spacing.md)
        .background(AppColor.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(.separator))
        .accessibilityElement(children: .contain)
    }
}

#Preview("Banner · Light") {
    VStack(spacing: Spacing.md) {
        AIUnavailableBanner(availability: .unavailable("Enable Apple Intelligence in System Settings."),
                            onOpenSettings: {})
        AIUnavailableBanner(availability: .needsSetup("The on-device model is downloading. Try again later."),
                            onOpenSettings: {})
    }
    .padding()
    .frame(width: 600)
}

#Preview("Banner · Dark") {
    AIUnavailableBanner(availability: .unavailable("Apple Intelligence isn't available on this device."),
                        onOpenSettings: {})
        .padding()
        .frame(width: 600)
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 7: Build**

Run: `xcodegen generate` lalu perintah build.
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: Commit**

```bash
git add DinoPocketMac/Presentation/Chat/ComposerState.swift DinoPocketMac/Presentation/Chat/Composer.swift \
  DinoPocketMac/Presentation/Chat/AIUnavailableBanner.swift \
  DinoPocketMac/Presentation/Components/IconButton.swift DinoPocketMac/Presentation/Components/StageButton.swift \
  DinoPocketTests/ComposerStateTests.swift
git commit -m "$(cat <<'EOF'
feat(b9): composer, banner Apple Intelligence, dan tombol reusable

Composer berbentuk kapsul dengan tombol kirim yang berubah menjadi stop
saat streaming. Return mengirim, ⇧Return menambah baris, dan Esc
menghentikan jawaban. Composer hanya terkunci saat model disiapkan;
saat Apple Intelligence mati, banner tampil di atasnya dan reminder
lewat chat tetap bisa dibuat. IconButton dan StageButton melengkapi
komponen spec B §7.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 10: Stage — Up next, popover reminder, dan header compact

**Files:**
- Create: `DinoPocketMac/Presentation/Stage/ReminderDraft.swift`
- Create: `DinoPocketMac/Presentation/Stage/ReminderEditor.swift`
- Create: `DinoPocketMac/Presentation/Stage/RemindersPopover.swift`
- Create: `DinoPocketMac/Presentation/Stage/UpNextList.swift`
- Create: `DinoPocketMac/Presentation/Stage/StatusLine.swift`
- Create: `DinoPocketMac/Presentation/Stage/CharacterStage.swift`
- Create: `DinoPocketMac/Presentation/Stage/CompactStageHeader.swift`
- Test: `DinoPocketTests/ReminderDraftTests.swift`

**Interfaces:**
- Consumes:
  - `ReminderListViewModel` (`rows(at:)`, `upNext(at:)`, `cancel`, `undo`, `update`, `lastCancelled`, `notificationsAllowed`, `Row.repeatsDaily`) dan `.preview`, `PreviewData` (Task 7)
  - `USDZCharacterView(size:asset:behavior:isPaused:)` (Task 6)
  - `IconButton`, `StageButton` (Task 9)
  - `StatusDot`, token (Task 1)
- Produces:
  - `struct ReminderDraft: Equatable`:
    - `enum Frequency { case once, daily }`
    - `var title`, `var time`, `var frequency`
    - `init(_ reminder: Reminder, now: Date, calendar: Calendar)`
    - `func applied(to: Reminder, now: Date, calendar: Calendar) -> Reminder?`
  - `ReminderEditor(reminder:now:onSave:onCancel:)`
  - `RemindersPopover(viewModel:)`
  - `UpNextList(viewModel:onOpenNotificationSettings:)`
  - `StatusLine(text:isWarning:)`
  - `CharacterStage(behavior:statusText:reminders:isBuddyModeOn:isAnimationPaused:onToggleBuddy:onOpenSettings:onOpenNotificationSettings:)`, dengan `nonisolated static let width: CGFloat = 320`
  - `CompactStageHeader(behavior:statusText:reminders:isBuddyModeOn:isAnimationPaused:onToggleBuddy:onOpenSettings:)`

- [ ] **Step 1: Tulis test yang gagal**

Buat `DinoPocketTests/ReminderDraftTests.swift`:

```swift
import Foundation
import Testing
@testable import Apl

struct ReminderDraftTests {

    private let calendar = TestTime.calendar

    private func stretch(at date: Date) -> Reminder {
        Reminder(title: "Stretch", rule: .once(date), createdAt: TestTime.now)
    }

    @Test func onceReminderKeepsItsDateAndTime() {
        let date = TestTime.date(2026, 9, 18, 15, 30)

        let draft = ReminderDraft(stretch(at: date), now: TestTime.now, calendar: calendar)

        #expect(draft.title == "Stretch")
        #expect(draft.frequency == .once)
        #expect(draft.time == date)
    }

    @Test func dailyReminderIsShownAsTodayAtItsTime() {
        let water = Reminder(title: "Water", rule: .daily(hour: 9, minute: 15), createdAt: TestTime.now)

        let draft = ReminderDraft(water, now: TestTime.now, calendar: calendar)

        #expect(draft.frequency == .daily)
        #expect(draft.time == TestTime.date(2026, 9, 16, 9, 15))
    }

    @Test func applyingSwitchesBetweenOnceAndDaily() {
        let original = stretch(at: TestTime.date(2026, 9, 16, 15, 0))
        var draft = ReminderDraft(original, now: TestTime.now, calendar: calendar)

        draft.frequency = .daily
        draft.time = TestTime.date(2026, 9, 16, 16, 45)
        let daily = draft.applied(to: original, now: TestTime.now, calendar: calendar)
        #expect(daily?.rule == .daily(hour: 16, minute: 45))
        #expect(daily?.id == original.id)

        // DatePicker membawa detik dari nilai awal; reminder tetap tepat di menitnya.
        draft.frequency = .once
        draft.time = TestTime.date(2026, 9, 17, 8, 0).addingTimeInterval(42)
        #expect(draft.applied(to: original, now: TestTime.now, calendar: calendar)?.rule
                == .once(TestTime.date(2026, 9, 17, 8, 0)))
    }

    @Test func emptyTitlesAndPastTimesAreRejected() {
        let original = stretch(at: TestTime.date(2026, 9, 16, 15, 0))
        var draft = ReminderDraft(original, now: TestTime.now, calendar: calendar)

        draft.title = "   "
        #expect(draft.applied(to: original, now: TestTime.now, calendar: calendar) == nil)

        draft.title = "  Stretch  "
        draft.time = TestTime.date(2026, 9, 16, 9, 0)
        #expect(draft.applied(to: original, now: TestTime.now, calendar: calendar) == nil)

        // Jam yang sudah lewat sah untuk reminder harian: ia berbunyi besok.
        draft.frequency = .daily
        #expect(draft.applied(to: original, now: TestTime.now, calendar: calendar)?.title == "Stretch")
    }
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS,arch=arm64' -only-testing:DinoPocketTests/ReminderDraftTests 2>&1 | grep -E "Test run with|TEST (SUCCEEDED|FAILED)|error:|✘"`
Expected: FAIL, dengan `error: cannot find 'ReminderDraft' in scope`.

- [ ] **Step 3: Tulis `ReminderDraft`**

Buat `DinoPocketMac/Presentation/Stage/ReminderDraft.swift`:

```swift
//
//  ReminderDraft.swift
//  Apl
//
//  Isian editor reminder di popover: judul, waktu, dan sekali/harian (spec B §5).
//

import Foundation

struct ReminderDraft: Equatable {

    enum Frequency: Hashable, CaseIterable {
        case once
        case daily
    }

    var title: String
    /// Tanggal dan jam untuk `.once`; untuk `.daily` hanya jam dan menitnya yang dipakai.
    var time: Date
    var frequency: Frequency

    init(_ reminder: Reminder, now: Date, calendar: Calendar) {
        title = reminder.title
        switch reminder.rule {
        case .once(let date):
            time = date
            frequency = .once
        case .daily(let hour, let minute):
            time = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
            frequency = .daily
        }
    }

    /// Reminder yang diperbarui dengan id yang sama, atau nil bila isian belum
    /// bisa disimpan: judul kosong, atau reminder sekali jalan di waktu lampau.
    func applied(to reminder: Reminder, now: Date, calendar: Calendar) -> Reminder? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return nil }

        var updated = reminder
        updated.title = trimmedTitle
        switch frequency {
        case .once:
            // DatePicker membawa detik dari nilai awal; reminder selalu tepat di menitnya.
            let minute = calendar.dateInterval(of: .minute, for: time)?.start ?? time
            guard minute > now else { return nil }
            updated.rule = .once(minute)
        case .daily:
            let parts = calendar.dateComponents([.hour, .minute], from: time)
            updated.rule = .daily(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
        }
        return updated
    }
}
```

- [ ] **Step 4: Jalankan test, pastikan lulus**

Run: perintah Step 2.
Expected: `Test run with 4 tests` … `** TEST SUCCEEDED **`

- [ ] **Step 5: Tulis editor dan popover reminder**

Buat `DinoPocketMac/Presentation/Stage/ReminderEditor.swift`:

```swift
//
//  ReminderEditor.swift
//  Apl
//
//  Editor sebaris di popover reminder.
//

import SwiftUI

struct ReminderEditor: View {
    let reminder: Reminder
    let onSave: (Reminder) -> Void
    let onCancel: () -> Void

    @State private var draft: ReminderDraft

    init(reminder: Reminder, now: Date = .now,
         onSave: @escaping (Reminder) -> Void, onCancel: @escaping () -> Void) {
        self.reminder = reminder
        self.onSave = onSave
        self.onCancel = onCancel
        _draft = State(initialValue: ReminderDraft(reminder, now: now, calendar: .current))
    }

    private var result: Reminder? {
        draft.applied(to: reminder, now: .now, calendar: .current)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            TextField("Title", text: $draft.title)
                .textFieldStyle(.roundedBorder)
            Picker("Repeat", selection: $draft.frequency) {
                Text("Once").tag(ReminderDraft.Frequency.once)
                Text("Every day").tag(ReminderDraft.Frequency.daily)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            DatePicker("Time", selection: $draft.time,
                       displayedComponents: draft.frequency == .once ? [.date, .hourAndMinute] : [.hourAndMinute])
                .labelsHidden()
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Save") {
                    if let result { onSave(result) }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(result == nil)
            }
        }
        .padding(Spacing.md)
        .background(AppColor.controlFill, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
    }
}

#Preview("Editor · Light") {
    ReminderEditor(reminder: PreviewData.reminders()[0], onSave: { _ in }, onCancel: {})
        .padding()
        .frame(width: 320)
}

#Preview("Editor · Dark") {
    ReminderEditor(reminder: PreviewData.reminders()[1], onSave: { _ in }, onCancel: {})
        .padding()
        .frame(width: 320)
        .preferredColorScheme(.dark)
}
```

Buat `DinoPocketMac/Presentation/Stage/RemindersPopover.swift`:

```swift
//
//  RemindersPopover.swift
//  Apl
//
//  "See all": semua reminder, dengan edit, batal, dan Undo (spec B §5).
//

import SwiftUI

struct RemindersPopover: View {
    let viewModel: ReminderListViewModel

    @State private var editingID: Reminder.ID?

    var body: some View {
        TimelineView(.everyMinute) { context in
            let rows = viewModel.rows(at: context.date)
            VStack(alignment: .leading, spacing: 0) {
                Text("Reminders")
                    .font(.headline)
                    .padding(Spacing.lg)
                Divider()
                if rows.isEmpty {
                    ContentUnavailableView {
                        Label("No reminders", systemImage: "bell")
                    } description: {
                        Text("Ask Apl in chat, like “Remind me to stretch at 3 PM”.")
                    }
                    .frame(height: 180)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(rows) { row in
                                if editingID == row.id {
                                    ReminderEditor(reminder: row.reminder,
                                                   onSave: { save($0) },
                                                   onCancel: { editingID = nil })
                                        .padding(Spacing.sm)
                                } else {
                                    rowView(row)
                                }
                                Divider()
                            }
                        }
                    }
                    .frame(maxHeight: 340)
                }
                if let cancelled = viewModel.lastCancelled {
                    Divider()
                    HStack {
                        Text("“\(cancelled.title)” removed")
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Undo") { Task { await viewModel.undo() } }
                    }
                    .font(.callout)
                    .padding(Spacing.md)
                }
            }
        }
        .frame(width: 320)
    }

    private func rowView(_ row: ReminderListViewModel.Row) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: row.repeatsDaily ? "repeat" : "bell")
                .foregroundStyle(AppColor.accent)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.reminder.title)
                    .lineLimit(1)
                Text(row.whenText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: Spacing.sm)
            IconButton(systemImage: "pencil", label: "Edit “\(row.reminder.title)”") {
                editingID = row.id
            }
            IconButton(systemImage: "trash", label: "Remove “\(row.reminder.title)”") {
                Task { await viewModel.cancel(row.id) }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    private func save(_ reminder: Reminder) {
        Task {
            await viewModel.update(reminder)
            editingID = nil
        }
    }
}

#Preview("Popover · Light") {
    RemindersPopover(viewModel: .preview())
}

#Preview("Popover · Empty · Dark") {
    RemindersPopover(viewModel: .preview([]))
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 6: Tulis Up next, baris status, stage, dan header compact**

Buat `DinoPocketMac/Presentation/Stage/StatusLine.swift`:

```swift
//
//  StatusLine.swift
//  Apl
//
//  Titik status + kalimat di bawah nama robot. Ukuran huruf diatur pemanggil.
//

import SwiftUI

struct StatusLine: View {
    let text: String
    var isWarning = false

    var body: some View {
        HStack(spacing: 6) {
            StatusDot(color: isWarning ? AppColor.statusWarning : AppColor.statusOK)
            Text(text)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Light") {
    VStack(alignment: .leading) {
        StatusLine(text: "Here when you need me")
        StatusLine(text: "Apple Intelligence is off", isWarning: true)
    }
    .font(.callout)
    .padding()
}

#Preview("Dark") {
    StatusLine(text: "Thinking…")
        .font(.callout)
        .padding()
        .preferredColorScheme(.dark)
}
```

Buat `DinoPocketMac/Presentation/Stage/UpNextList.swift`:

```swift
//
//  UpNextList.swift
//  Apl
//
//  Tiga reminder terdekat di stage, plus "See all" (spec B §5).
//

import SwiftUI

struct UpNextList: View {
    let viewModel: ReminderListViewModel
    let onOpenNotificationSettings: () -> Void

    @State private var showsAll = false

    var body: some View {
        // Diperbarui tiap menit, supaya reminder yang lewat hilang sendiri.
        TimelineView(.everyMinute) { context in
            let rows = viewModel.upNext(at: context.date)
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("Up next")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("See all") { showsAll = true }
                        .buttonStyle(.link)
                        .font(.subheadline)
                        .popover(isPresented: $showsAll, arrowEdge: .trailing) {
                            RemindersPopover(viewModel: viewModel)
                        }
                }

                if rows.isEmpty {
                    Text("Ask me to remind you about something.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(rows) { row in
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                            Image(systemName: row.repeatsDaily ? "repeat" : "bell")
                                .foregroundStyle(AppColor.accent)
                                .frame(width: 16)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.reminder.title)
                                    .lineLimit(1)
                                Text(row.whenText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }

                // Reminder tetap tercatat, tapi tidak akan muncul (spec B §9).
                if !viewModel.notificationsAllowed {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "bell.slash")
                            .foregroundStyle(AppColor.statusWarning)
                        Text("Notifications are off")
                        Button("Turn On…", action: onOpenNotificationSettings)
                            .buttonStyle(.link)
                    }
                    .font(.caption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview("Up next · Light") {
    UpNextList(viewModel: .preview(), onOpenNotificationSettings: {})
        .padding()
        .frame(width: 288)
}

#Preview("Up next · Empty, notifications off · Dark") {
    UpNextList(viewModel: .preview([], notificationsAllowed: false), onOpenNotificationSettings: {})
        .padding()
        .frame(width: 288)
        .preferredColorScheme(.dark)
}
```

Buat `DinoPocketMac/Presentation/Stage/CharacterStage.swift`:

```swift
//
//  CharacterStage.swift
//  Apl
//
//  Panel kiri jendela utama (spec B §5): robot dengan glow dan bayangan,
//  nama, status, Up next, lalu tombol Buddy Mode dan Settings.
//

import SwiftUI

struct CharacterStage: View {
    nonisolated static let width: CGFloat = 320

    let behavior: CharacterBehavior
    let statusText: String
    let reminders: ReminderListViewModel
    let isBuddyModeOn: Bool
    var isAnimationPaused = false
    let onToggleBuddy: () -> Void
    let onOpenSettings: () -> Void
    let onOpenNotificationSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            character
                // Ruang untuk tombol jendela; judul jendela disembunyikan.
                .padding(.top, 36)
            Text("Apl")
                .font(AppFont.title(24))
                .padding(.top, Spacing.sm)
            StatusLine(text: statusText, isWarning: behavior == .sleepy)
                .font(.callout)
                .padding(.top, Spacing.xs)
                .padding(.horizontal, Spacing.lg)
            UpNextList(viewModel: reminders, onOpenNotificationSettings: onOpenNotificationSettings)
                .padding(.top, Spacing.xl)
                .padding(.horizontal, Spacing.lg)
            Spacer(minLength: Spacing.lg)
            HStack(spacing: Spacing.sm) {
                StageButton(title: isBuddyModeOn ? "Hide Buddy" : "Buddy Mode",
                            systemImage: "figure.stand", isOn: isBuddyModeOn, action: onToggleBuddy)
                IconButton(systemImage: "gearshape", label: "Settings", action: onOpenSettings)
            }
            .padding(Spacing.lg)
        }
        .frame(width: Self.width)
        .frame(maxHeight: .infinity)
        .background(AppColor.raisedSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    /// Area robot ±280×204pt: glow aksen di belakang, bayangan lembut di bawah.
    /// Bila model gagal dimuat, yang tersisa hanya glow — stage tetap utuh.
    private var character: some View {
        ZStack {
            Ellipse()
                .fill(AppColor.stageGlow)
                .frame(width: 240, height: 170)
                .blur(radius: 36)
            Ellipse()
                .fill(Color.black.opacity(0.16))
                .frame(width: 110, height: 12)
                .blur(radius: 6)
                .offset(y: 96)
            USDZCharacterView(size: 204, asset: .robot, behavior: behavior, isPaused: isAnimationPaused)
        }
        .frame(width: 280, height: 204)
    }
}

#Preview("Stage · Dark") {
    CharacterStage(behavior: .idle, statusText: "Here when you need me", reminders: .preview(),
                   isBuddyModeOn: false, onToggleBuddy: {}, onOpenSettings: {},
                   onOpenNotificationSettings: {})
        .padding(8)
        .frame(height: 680)
        .preferredColorScheme(.dark)
}

#Preview("Stage · AI off · Light") {
    CharacterStage(behavior: .sleepy, statusText: "Apple Intelligence is off",
                   reminders: .preview(notificationsAllowed: false),
                   isBuddyModeOn: true, onToggleBuddy: {}, onOpenSettings: {},
                   onOpenNotificationSettings: {})
        .padding(8)
        .frame(height: 680)
}
```

Buat `DinoPocketMac/Presentation/Stage/CompactStageHeader.swift`:

```swift
//
//  CompactStageHeader.swift
//  Apl
//
//  Pengganti stage saat jendela lebih sempit dari 820pt (spec B §5): avatar
//  36pt, nama, dan status. Up next tidak muat, jadi reminder dibuka lewat
//  tombol lonceng (deviasi 13).
//

import SwiftUI

struct CompactStageHeader: View {
    let behavior: CharacterBehavior
    let statusText: String
    let reminders: ReminderListViewModel
    let isBuddyModeOn: Bool
    var isAnimationPaused = false
    let onToggleBuddy: () -> Void
    let onOpenSettings: () -> Void

    @State private var showsReminders = false

    var body: some View {
        HStack(spacing: Spacing.md) {
            USDZCharacterView(size: 36, asset: .robot, behavior: behavior, isPaused: isAnimationPaused)
            VStack(alignment: .leading, spacing: 2) {
                Text("Apl")
                    .font(AppFont.title(15))
                StatusLine(text: statusText, isWarning: behavior == .sleepy)
                    .font(.caption)
            }
            Spacer(minLength: Spacing.sm)
            IconButton(systemImage: "bell", label: "Reminders") {
                showsReminders = true
            }
            .popover(isPresented: $showsReminders, arrowEdge: .bottom) {
                RemindersPopover(viewModel: reminders)
            }
            IconButton(systemImage: "figure.stand", label: isBuddyModeOn ? "Hide Buddy" : "Buddy Mode",
                       isOn: isBuddyModeOn, action: onToggleBuddy)
            IconButton(systemImage: "gearshape", label: "Settings", action: onOpenSettings)
        }
        // Ruang untuk tombol jendela di kiri atas.
        .padding(.leading, 78)
        .padding(.trailing, Spacing.lg)
        .frame(height: 52)
    }
}

#Preview("Compact · Light") {
    CompactStageHeader(behavior: .greet, statusText: "Good morning!", reminders: .preview(),
                       isBuddyModeOn: false, onToggleBuddy: {}, onOpenSettings: {})
        .frame(width: 740)
}

#Preview("Compact · Dark") {
    CompactStageHeader(behavior: .thinking, statusText: "Thinking…", reminders: .preview(),
                       isBuddyModeOn: true, onToggleBuddy: {}, onOpenSettings: {})
        .frame(width: 740)
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 7: Build dan jalankan seluruh test**

Run: `xcodegen generate`, lalu perintah build, lalu perintah test semua.
Expected: `** BUILD SUCCEEDED **` dan `** TEST SUCCEEDED **` (±148 test).

- [ ] **Step 8: Commit**

```bash
git add DinoPocketMac/Presentation/Stage DinoPocketTests/ReminderDraftTests.swift
git commit -m "$(cat <<'EOF'
feat(b10): stage karakter — Up next, popover reminder, header compact

Stage menampilkan robot dengan glow aksen, nama, status, tiga reminder
terdekat, dan tombol Buddy Mode serta Settings. "See all" membuka
popover untuk mengedit judul, waktu, dan sekali/harian, atau untuk
membatalkan dengan Undo. Petunjuk "Notifications are off" muncul bila
izin ditolak. Header compact menggantikan stage di jendela sempit,
dengan tombol lonceng ke popover yang sama.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 11: Jendela utama menggantikan dashboard

**Files:**
- Create: `DinoPocketMac/Presentation/Window/MainWindowLayout.swift`
- Create: `DinoPocketMac/Presentation/Window/MainWindow.swift`
- Create: `DinoPocketMac/Presentation/Window/ConversationCommands.swift`
- Create: `DinoPocketMac/Presentation/Chat/ConversationView.swift`
- Modify: `DinoPocketMac/App/AplApp.swift`
- Modify: `DinoPocketMac/App/AppDependencies.swift`
- Modify: `SharedCore/Data/Errors/AplError.swift` (komentar)
- Modify: `project.yml` (komentar)
- Delete: `DinoPocketMac/Presentation/Views/DashboardTemplate.swift`, `SidebarView.swift`, `ChatPage.swift`, `MessageBubble.swift`, `AIUnavailableCard.swift`
- Test: `DinoPocketTests/MainWindowLayoutTests.swift`

**Interfaces:**
- Consumes:
  - Semua view dari Task 8–10
  - `CharacterMoodResolver`, `CharacterStatusText` (Task 5)
  - `CharacterExpressionCache.shared.preload` (Task 6)
  - `ChatStore.clearConversation`, `.stopStreaming`, `.retry`, `.lastEvent` (Task 3–4)
  - `ReminderListViewModel` (Task 7)
  - `AppLaunching.open(_:)`, `SystemSettingsPane` (A)
- Produces:
  - `enum MainWindowLayout`: `defaultSize`, `minimumSize`, `compactThreshold`, `stageInset`, `static func isCompact(width:) -> Bool`
  - `ConversationView(chat:reminders:availability:showsDateHeader:onOpenIntelligenceSettings:)`, dengan `nonisolated static func dayLabel(for:now:calendar:) -> String`
  - `MainWindow(chat:reminders:launcher:isBuddyModeOn:onToggleBuddy:)`
  - `FocusedValues.clearConversation: (() -> Void)?`
  - `ConversationCommands: Commands`
  - `AppDependencies.makeReminderListViewModel() -> ReminderListViewModel`

- [ ] **Step 1: Tulis test yang gagal**

Buat `DinoPocketTests/MainWindowLayoutTests.swift`:

```swift
import Foundation
import Testing
@testable import Apl

struct MainWindowLayoutTests {

    @Test func stageCollapsesBelowEightHundredTwentyPoints() {
        #expect(MainWindowLayout.isCompact(width: 819.5))
        #expect(!MainWindowLayout.isCompact(width: 820))
        #expect(!MainWindowLayout.isCompact(width: MainWindowLayout.defaultSize.width))
        #expect(MainWindowLayout.isCompact(width: MainWindowLayout.minimumSize.width))
    }

    @MainActor @Test func dateHeaderIsRelativeToToday() {
        let calendar = TestTime.calendar

        #expect(ConversationView.dayLabel(for: TestTime.now, now: TestTime.now, calendar: calendar) == "Today")
        #expect(ConversationView.dayLabel(for: TestTime.date(2026, 9, 15, 20, 0), now: TestTime.now,
                                          calendar: calendar) == "Yesterday")
    }
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS,arch=arm64' -only-testing:DinoPocketTests/MainWindowLayoutTests 2>&1 | grep -E "Test run with|TEST (SUCCEEDED|FAILED)|error:|✘"`
Expected: FAIL, dengan `error: cannot find 'MainWindowLayout' in scope`.

- [ ] **Step 3: Tulis layout dan menu Conversation**

Buat `DinoPocketMac/Presentation/Window/MainWindowLayout.swift`:

```swift
//
//  MainWindowLayout.swift
//  Apl
//
//  Ukuran jendela utama dan ambang mode compact (spec B §5).
//

import CoreGraphics

enum MainWindowLayout {
    static let defaultSize = CGSize(width: 1000, height: 680)
    static let minimumSize = CGSize(width: 720, height: 520)
    /// Di bawah lebar ini stage diganti `CompactStageHeader`.
    static let compactThreshold: CGFloat = 820
    static let stageInset: CGFloat = 8

    static func isCompact(width: CGFloat) -> Bool {
        width < compactThreshold
    }
}
```

Buat `DinoPocketMac/Presentation/Window/ConversationCommands.swift`:

```swift
//
//  ConversationCommands.swift
//  Apl
//
//  Menu bar Conversation › Clear Conversation… (spec B §4). Satu percakapan
//  berkelanjutan butuh jalan untuk mulai dari awal.
//

import SwiftUI

extension FocusedValues {
    /// Diisi jendela utama yang sedang aktif; nil saat percakapan kosong.
    @Entry var clearConversation: (() -> Void)?
}

struct ConversationCommands: Commands {
    @FocusedValue(\.clearConversation) private var clearConversation

    var body: some Commands {
        CommandMenu("Conversation") {
            Button("Clear Conversation…") {
                clearConversation?()
            }
            .keyboardShortcut("k", modifiers: .command)
            .disabled(clearConversation == nil)
        }
    }
}
```

- [ ] **Step 4: Tulis `ConversationView`**

Buat `DinoPocketMac/Presentation/Chat/ConversationView.swift`:

```swift
//
//  ConversationView.swift
//  Apl
//
//  Kolom kanan jendela utama: header tanggal, daftar pesan yang mengikuti
//  pesan terbaru, banner AI, dan composer (spec B §5–§6).
//

import SwiftUI

struct ConversationView: View {
    let chat: ChatStore
    let reminders: ReminderListViewModel
    let availability: BrainAvailability?
    var showsDateHeader = true
    let onOpenIntelligenceSettings: () -> Void

    @State private var draft = ""

    private var composerState: ComposerState {
        .current(availability: availability, isStreaming: chat.isStreaming)
    }

    /// Selama potongan pertama belum datang, placeholder kosong digantikan titik-titik.
    private var showsTypingIndicator: Bool {
        chat.isStreaming && (chat.messages.last?.text.isEmpty ?? true)
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsDateHeader {
                Text(Self.dayLabel(for: chat.messages.last?.date ?? .now, now: .now))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }

            messageList

            VStack(spacing: Spacing.sm) {
                if let availability, availability != .ready {
                    AIUnavailableBanner(availability: availability,
                                        onOpenSettings: onOpenIntelligenceSettings)
                }
                Composer(draft: $draft, state: composerState,
                         onSend: { send() },
                         onStop: { chat.stopStreaming() })
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.lg)
        }
        // Esc menghentikan jawaban walau fokus tidak di composer.
        .onExitCommand { chat.stopStreaming() }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                    ForEach(chat.messages) { message in
                        MessageRow(message: message,
                                   reminders: reminders,
                                   canRetry: !chat.isStreaming && message.id == chat.messages.last?.id,
                                   onRetry: { Task { await chat.retry(message.id) } })
                            .id(message.id)
                    }
                    if showsTypingIndicator {
                        TypingIndicator()
                    }
                    if let notice = chat.noticeMessage {
                        Label(notice, systemImage: "info.circle")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .defaultScrollAnchor(.bottom)
            .defaultScrollAnchor(.bottom, for: .sizeChanges)
            .onChange(of: chat.messages.last?.id) { _, id in
                guard let id else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(id, anchor: .bottom)
                }
            }
            .overlay {
                if chat.messages.isEmpty && !chat.isStreaming {
                    ContentUnavailableView {
                        Label("Say hi to Apl", systemImage: "bubble.left.and.bubble.right")
                    } description: {
                        Text("Ask anything, or try “Remind me to stretch at 3 PM”.")
                    }
                }
            }
        }
    }

    private func send() {
        let text = draft
        draft = ""
        Task { await chat.send(text) }
    }

    /// "Today", "Yesterday", atau tanggal pesan terakhir.
    nonisolated static func dayLabel(for date: Date, now: Date, calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        return date.formatted(.dateTime.month(.wide).day())
    }
}

#Preview("Conversation · Light") {
    ConversationView(chat: .preview(), reminders: .preview(), availability: .ready,
                     onOpenIntelligenceSettings: {})
        .frame(width: 680, height: 620)
}

#Preview("Conversation · AI off · Dark") {
    ConversationView(chat: .preview(), reminders: .preview(),
                     availability: .unavailable("Enable Apple Intelligence in System Settings."),
                     onOpenIntelligenceSettings: {})
        .frame(width: 680, height: 620)
        .preferredColorScheme(.dark)
}

#Preview("Conversation · Empty, thinking · Dark") {
    ConversationView(chat: .preview([ChatMessage(role: .user, text: "Hello!"),
                                     ChatMessage(role: .assistant, text: "")], isStreaming: true),
                     reminders: .preview(), availability: .ready,
                     onOpenIntelligenceSettings: {})
        .frame(width: 680, height: 620)
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 5: Tulis `MainWindow`**

Buat `DinoPocketMac/Presentation/Window/MainWindow.swift`:

```swift
//
//  MainWindow.swift
//  Apl
//
//  Jendela utama, layout A · Companion stage (spec B §5–§6): stage karakter di
//  kiri, percakapan di kanan. Di bawah 820pt stage diringkas menjadi header.
//
//  Ekspresi robot dihitung CharacterMoodResolver setiap render. View ini hanya
//  memastikan ada render ulang tepat saat momen 3 detik berakhir.
//

import SwiftUI

struct MainWindow: View {
    let chat: ChatStore
    let reminders: ReminderListViewModel
    let launcher: AppLaunching
    let isBuddyModeOn: Bool
    let onToggleBuddy: () -> Void

    @Environment(\.openSettings) private var openSettings
    @Environment(\.appearsActive) private var appearsActive

    @State private var availability: BrainAvailability?
    @State private var windowActivatedAt: Date?
    /// Diperbarui saat momen berakhir, supaya body dievaluasi ulang.
    @State private var clock = Date.now
    @State private var isConfirmingClear = false

    var body: some View {
        // `clock` dibaca di sini agar pembaruannya memicu render ulang. Waktu
        // yang dipakai tetap "sekarang": kejadian baru bisa lebih muda dari
        // pembaruan `clock` terakhir.
        let now = max(Date.now, clock)
        let resolution = CharacterMoodResolver.resolve(moodInput, now: now)
        let statusText = CharacterStatusText.text(for: resolution.behavior, now: now,
                                                  intelligenceAvailable: isIntelligenceAvailable,
                                                  celebratedTime: celebratedTime)
        // Mitigasi baterai (spec B §12, deviasi 11).
        let isAnimationPaused = !appearsActive || ProcessInfo.processInfo.isLowPowerModeEnabled

        GeometryReader { proxy in
            let isCompact = MainWindowLayout.isCompact(width: proxy.size.width)
            HStack(spacing: 0) {
                if !isCompact {
                    CharacterStage(behavior: resolution.behavior,
                                   statusText: statusText,
                                   reminders: reminders,
                                   isBuddyModeOn: isBuddyModeOn,
                                   isAnimationPaused: isAnimationPaused,
                                   onToggleBuddy: onToggleBuddy,
                                   onOpenSettings: { openSettings() },
                                   onOpenNotificationSettings: { _ = launcher.open(.notifications) })
                        .padding([.leading, .top, .bottom], MainWindowLayout.stageInset)
                }
                VStack(spacing: 0) {
                    if isCompact {
                        CompactStageHeader(behavior: resolution.behavior,
                                           statusText: statusText,
                                           reminders: reminders,
                                           isBuddyModeOn: isBuddyModeOn,
                                           isAnimationPaused: isAnimationPaused,
                                           onToggleBuddy: onToggleBuddy,
                                           onOpenSettings: { openSettings() })
                        Divider()
                    }
                    ConversationView(chat: chat,
                                     reminders: reminders,
                                     availability: availability,
                                     showsDateHeader: !isCompact,
                                     onOpenIntelligenceSettings: { _ = launcher.open(.appleIntelligence) })
                }
            }
        }
        // Judul jendela disembunyikan; stage dan header mengisi area tombol jendela.
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: MainWindowLayout.minimumSize.width, minHeight: MainWindowLayout.minimumSize.height)
        .background(Color(nsColor: .windowBackgroundColor))
        .task(id: resolution.reevaluateAt) {
            guard let next = resolution.reevaluateAt else { return }
            try? await Task.sleep(for: .seconds(max(0, next.timeIntervalSinceNow)))
            guard !Task.isCancelled else { return }
            clock = .now
        }
        .onChange(of: appearsActive, initial: true) { _, isActive in
            guard isActive else { return }
            windowActivatedAt = .now
            // Pengguna mungkin baru menyalakan Apple Intelligence atau
            // notifikasi di System Settings (spec B §9).
            Task {
                availability = await chat.availability()
                await reminders.refreshPermission()
            }
        }
        .focusedSceneValue(\.clearConversation, clearAction)
        .confirmationDialog("Clear this conversation?", isPresented: $isConfirmingClear,
                            titleVisibility: .visible) {
            Button("Clear Conversation", role: .destructive) {
                Task { await chat.clearConversation() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Apl will forget this conversation. Your reminders stay.")
        }
    }

    /// Belum dicek dianggap tersedia, supaya robot tidak sempat tertidur saat app dibuka.
    private var isIntelligenceAvailable: Bool {
        guard let availability else { return true }
        return availability == .ready
    }

    private var moodInput: CharacterMoodInput {
        CharacterMoodInput(intelligenceAvailable: isIntelligenceAvailable,
                           isStreaming: chat.isStreaming,
                           lastEvent: chat.lastEvent,
                           windowActivatedAt: windowActivatedAt)
    }

    /// Kapan reminder yang baru dibuat akan berbunyi — untuk "Reminder set for 3:00 PM".
    private var celebratedTime: Date? {
        guard let event = chat.lastEvent,
              case .reminderCreated(let id) = event.kind,
              let reminder = reminders.reminder(withID: id) else { return nil }
        return reminder.nextOccurrence(after: event.at)
    }

    private var clearAction: (() -> Void)? {
        guard !chat.messages.isEmpty else { return nil }
        return { isConfirmingClear = true }
    }
}

#Preview("Main window · Dark") {
    MainWindow(chat: .preview(), reminders: .preview(), launcher: AppLauncherService(),
               isBuddyModeOn: false, onToggleBuddy: {})
        .frame(width: 1000, height: 680)
        .preferredColorScheme(.dark)
}

#Preview("Main window · Light") {
    MainWindow(chat: .preview(), reminders: .preview(), launcher: AppLauncherService(),
               isBuddyModeOn: true, onToggleBuddy: {})
        .frame(width: 1000, height: 680)
}

#Preview("Main window · Compact · Dark") {
    MainWindow(chat: .preview(), reminders: .preview(), launcher: AppLauncherService(),
               isBuddyModeOn: false, onToggleBuddy: {})
        .frame(width: 740, height: 520)
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 6: Sambungkan ke app**

Di `DinoPocketMac/App/AppDependencies.swift`, di bawah `makeCreateReminderUseCase()`, tambahkan:

```swift

    /// Membaca ReminderStore yang sama dengan chat, supaya reminder dari chat
    /// langsung muncul di Up next.
    func makeReminderListViewModel() -> ReminderListViewModel {
        ReminderListViewModel(store: reminderStore, notifications: reminderScheduler)
    }
```

Ganti seluruh isi `DinoPocketMac/App/AplApp.swift`:

```swift
//
//  AplApp.swift
//  Apl
//
//  Created by Codex on 13/03/26.
//

import SwiftUI

@main
struct AplApp: App {
    /// Satu-satunya tempat implementasi konkret dipilih.
    private static let deps = AppDependencies.live()

    @State private var chat = deps.makeChatStore()
    @State private var reminders = deps.makeReminderListViewModel()
    @State private var buddySettings = deps.buddySettings
    @State private var profile = deps.profile

    @State var isBuddyMode = false

    init() {
        ReminderNotificationCenter.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            rootView
                .task {
                    chat.createReminder = Self.deps.makeCreateReminderUseCase()
                    // Kelima ekspresi dimuat di awal, supaya pergantian wajah
                    // pertama pun tidak menunggu disk (spec B §6).
                    await CharacterExpressionCache.shared.preload(.robot)
                }
        }
        // Judul jendela disembunyikan: stage dan header percakapan mengisi
        // bagian atas, dan latar jendela bisa diseret untuk memindahkannya.
        .windowStyle(.hiddenTitleBar)
        .windowBackgroundDragBehavior(.enabled)
        .defaultSize(MainWindowLayout.defaultSize)
        .windowResizability(.contentMinSize)
        .commands {
            ConversationCommands()
        }

        // SEMENTARA: halaman Settings lama ditampung jendela ⌘, sampai
        // jendela Settings bertab menggantikannya.
        Settings {
            SettingsPage(chat: chat, buddySettings: buddySettings, profile: profile,
                         extraErasableStores: Self.deps.erasableStores)
                .frame(width: 480, height: 560)
        }
    }

    @ViewBuilder
    private var rootView: some View {
        if profile.hasCompletedOnboarding {
            mainWindow
        } else {
            OnboardingView(profile: profile, chat: chat,
                           onNotificationsGranted: {
                               // Reminder yang dibuat sebelum izin diberikan baru bisa dijadwalkan sekarang.
                               await Self.deps.reminderScheduler.sync(Self.deps.reminderStore.reminders, now: .now)
                           })
        }
    }

    @ViewBuilder
    private var mainWindow: some View {
        MainWindow(chat: chat, reminders: reminders, launcher: Self.deps.appLauncher,
                   isBuddyModeOn: isBuddyMode, onToggleBuddy: toggleBuddyMode)
        // Setiap preferensi buddy diterapkan langsung tanpa memulai ulang mode,
        // supaya kontrol di Settings terasa hidup saat digeser.
        .onChange(of: buddySettings.size) { _, value in
            guard isBuddyMode else { return }
            AplBuddyWindowController.shared.updateCharacterSize(CGFloat(value))
        }
        .onChange(of: buddySettings.opacity) { _, value in
            guard isBuddyMode else { return }
            AplBuddyWindowController.shared.apply(opacity: value)
        }
        .onChange(of: buddySettings.keepOnTop) { _, value in
            guard isBuddyMode else { return }
            AplBuddyWindowController.shared.apply(keepOnTop: value)
        }
        .onChange(of: buddySettings.strolling) { _, value in
            guard isBuddyMode else { return }
            AplBuddyWindowController.shared.apply(strolling: value)
        }
        .onChange(of: isBuddyMode) { _, active in
            if active {
                AplBuddyWindowController.shared.startBuddyMode(
                    settings: buddySettings,
                    onDismiss: { dismissFromBuddy() }
                )
            } else {
                AplBuddyWindowController.shared.stopBuddyMode()
            }
        }
        // Buddy Mode menyala sendiri begitu jendela utama tampil.
        //
        // Dijalankan sekali per kemunculan; menyalakan ulang saat sudah aktif
        // akan membangun ulang jendelanya tanpa alasan.
        .task {
            guard !isBuddyMode else { return }
            isBuddyMode = true
        }
    }
}
```

- [ ] **Step 7: Hapus view lama dan rapikan rujukan**

```bash
git rm DinoPocketMac/Presentation/Views/DashboardTemplate.swift \
  DinoPocketMac/Presentation/Views/SidebarView.swift \
  DinoPocketMac/Presentation/Views/ChatPage.swift \
  DinoPocketMac/Presentation/Views/MessageBubble.swift \
  DinoPocketMac/Presentation/Views/AIUnavailableCard.swift
```

Di `SharedCore/Data/Errors/AplError.swift`, ganti

```swift
    /// Tidak ada otak yang siap. UI menampilkan `AIUnavailableCard`.
```

menjadi

```swift
    /// Tidak ada otak yang siap. UI menampilkan `AIUnavailableBanner`.
```

Di `project.yml`, ganti

```yaml
          # Extension dari ContentView (UI retro), bukan file produk macOS —
          # jalur macOS memakai DashboardTemplate. Ikut dibekukan.
```

menjadi

```yaml
          # Extension dari ContentView (UI retro), bukan file produk macOS —
          # jalur macOS memakai MainWindow. Ikut dibekukan.
```

- [ ] **Step 8: Jalankan test, build, dan seluruh test**

Run: `xcodegen generate`, lalu perintah Step 2.
Expected: `Test run with 2 tests` … `** TEST SUCCEEDED **`

Run: perintah build, lalu perintah test semua.
Expected: `** BUILD SUCCEEDED **` dan `** TEST SUCCEEDED **` (±150 test).

Run: `grep -rn -e DashboardTemplate -e SidebarView -e ChatPage -e MessageBubble -e AIUnavailableCard DinoPocketMac SharedCore project.yml`
Expected: tidak ada keluaran.

- [ ] **Step 9: Asap — jalankan app sekali**

Jalankan app dalam mode Dark (perintah "Jalankan app" di bagian Alat verifikasi manual), tunggu ±3 detik, lalu potret dengan perintah "Potret jendela utama" (`apl-b11-smoke.png`).

Expected:
- Kiri: stage dengan robot, "Apl", status, Up next, dan tombol.
- Kanan: percakapan dengan composer di bawah.

Jendela kosong atau app crash berarti task ini belum selesai.

- [ ] **Step 10: Commit**

```bash
git add DinoPocketMac/Presentation/Window DinoPocketMac/Presentation/Chat/ConversationView.swift \
  DinoPocketMac/App/AplApp.swift DinoPocketMac/App/AppDependencies.swift \
  SharedCore/Data/Errors/AplError.swift project.yml DinoPocketTests/MainWindowLayoutTests.swift
git status --short   # penghapusan lima view lama sudah di-stage oleh git rm
git commit -m "$(cat <<'EOF'
feat(b11): jendela utama chat-first menggantikan dashboard

MainWindow menyusun stage karakter dan percakapan sesuai layout A, dan
beralih ke header compact di bawah 820pt. Ekspresi robot mengikuti
CharacterMoodResolver dan dievaluasi ulang tepat saat momen berakhir.
Availability dan izin notifikasi dicek ulang setiap kali jendela aktif.
Menu Conversation › Clear Conversation… (⌘K) meminta konfirmasi dan
tidak menyentuh reminder.

Judul jendela disembunyikan, ekspresi dimuat di awal, dan Settings
sementara pindah ke jendela ⌘,. DashboardTemplate, SidebarView,
ChatPage, MessageBubble, dan AIUnavailableCard dihapus.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 12: Jendela Settings (⌘,) dan tab Debug

**Files:**
- Create: `DinoPocketMac/Presentation/Settings/SettingsWindow.swift`
- Create: `DinoPocketMac/Presentation/Settings/DebugSettingsTab.swift`
- Create: `DinoPocketMac/Infrastructure/Services/DebugAvailabilityBrain.swift`
- Modify: `DinoPocketMac/Infrastructure/Services/LaunchAtLoginService.swift` (protokol)
- Modify: `DinoPocketMac/App/AppDependencies.swift`
- Modify: `DinoPocketMac/App/AplApp.swift`
- Delete: `DinoPocketMac/Presentation/Views/SettingsPage.swift`
- Test: `DinoPocketTests/DebugAvailabilityBrainTests.swift`

**Interfaces:**
- Consumes:
  - `ProfileStore`, `BuddySettingsStore`, `LaunchAtLoginService`, `EraseAllDataUseCase`, `LocallyErasable`, `AppDependencies.erasableStores` / `.reminderScheduler` (A)
  - `Brain.resetConversation()` (Task 4)
- Produces:
  - `LaunchAtLoginManaging` bertambah `var needsUserApproval: Bool { get }`
  - `SettingsWindow(profile:buddySettings:launchAtLogin:eraseAllData:)`, dengan tab General, Character, Privacy, dan Debug (khusus DEBUG)
  - Khusus DEBUG:
    - `enum ForcedAvailability: String, CaseIterable, Identifiable { case system, ready, notEnabled, notEligible, downloading }`, dengan `defaultsKey = "debug.forcedAvailability"`, `label`, `availability: BrainAvailability?`, `static func current(in:)`
    - `struct DebugAvailabilityBrain: Brain { base, defaults }`
    - `DebugSettingsTab`
  - `AppDependencies.live()` membungkus brain dengan `DebugAvailabilityBrain` di build DEBUG

- [ ] **Step 1: Tulis test yang gagal**

Buat `DinoPocketTests/DebugAvailabilityBrainTests.swift`:

```swift
#if DEBUG
import Foundation
import Testing
@testable import Apl

private struct FixedBrain: Brain {
    let value: BrainAvailability
    func availability() async -> BrainAvailability { value }
    func reply(to history: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}

/// Override khusus DEBUG untuk menguji state AI mati tanpa menyentuh
/// pengaturan sistem (spec B §8, §10).
struct DebugAvailabilityBrainTests {

    private func isolatedDefaults(_ name: String) -> UserDefaults {
        let suite = "test.debugbrain.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func withoutAnOverrideTheSystemAnswers() async {
        let brain = DebugAvailabilityBrain(base: FixedBrain(value: .ready), defaults: isolatedDefaults(#function))

        #expect(await brain.availability() == .ready)
    }

    @Test func overrideWins() async {
        let defaults = isolatedDefaults(#function)
        defaults.set(ForcedAvailability.notEnabled.rawValue, forKey: ForcedAvailability.defaultsKey)
        let brain = DebugAvailabilityBrain(base: FixedBrain(value: .ready), defaults: defaults)

        #expect(await brain.availability() == .unavailable("Enable Apple Intelligence in System Settings."))
    }

    @Test func unknownStoredValueFallsBackToTheSystem() async {
        let defaults = isolatedDefaults(#function)
        defaults.set("banana", forKey: ForcedAvailability.defaultsKey)
        let brain = DebugAvailabilityBrain(base: FixedBrain(value: .needsSetup("x")), defaults: defaults)

        #expect(await brain.availability() == .needsSetup("x"))
    }
}
#endif
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS,arch=arm64' -only-testing:DinoPocketTests/DebugAvailabilityBrainTests 2>&1 | grep -E "Test run with|TEST (SUCCEEDED|FAILED)|error:|✘"`
Expected: FAIL, dengan `error: cannot find 'DebugAvailabilityBrain' in scope`.

- [ ] **Step 3: Tulis `DebugAvailabilityBrain`**

Buat `DinoPocketMac/Infrastructure/Services/DebugAvailabilityBrain.swift`:

```swift
//
//  DebugAvailabilityBrain.swift
//  AplMac
//
//  KHUSUS DEBUG. Membungkus AppleBrain supaya status Apple Intelligence bisa
//  dipaksa dari tab Debug di Settings (spec B §8). Hanya dengan cara ini
//  banner, robot tertidur, dan composer "Getting ready…" bisa diuji tanpa
//  mengubah pengaturan sistem. Tidak dikompilasi di Release.
//

#if DEBUG
import Foundation

enum ForcedAvailability: String, CaseIterable, Identifiable {
    case system
    case ready
    case notEnabled
    case notEligible
    case downloading

    static let defaultsKey = "debug.forcedAvailability"

    var id: Self { self }

    var label: String {
        switch self {
        case .system: "Use system status"
        case .ready: "Ready"
        case .notEnabled: "Not enabled"
        case .notEligible: "Device not eligible"
        case .downloading: "Model downloading"
        }
    }

    /// nil berarti pakai status sistem. Teksnya sama persis dengan yang
    /// dilaporkan AppleBrain, supaya yang diuji adalah tampilan sungguhan.
    var availability: BrainAvailability? {
        switch self {
        case .system: nil
        case .ready: .ready
        case .notEnabled: .unavailable("Enable Apple Intelligence in System Settings.")
        case .notEligible: .unavailable("Apple Intelligence isn't available on this device.")
        case .downloading: .needsSetup("The on-device model is downloading. Try again later.")
        }
    }

    static func current(in defaults: UserDefaults) -> ForcedAvailability {
        defaults.string(forKey: defaultsKey).flatMap(ForcedAvailability.init(rawValue:)) ?? .system
    }
}

struct DebugAvailabilityBrain: Brain {
    let base: Brain
    let defaults: UserDefaults

    func availability() async -> BrainAvailability {
        if let forced = ForcedAvailability.current(in: defaults).availability {
            return forced
        }
        return await base.availability()
    }

    func reply(to history: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        base.reply(to: history)
    }

    func resetConversation() async {
        await base.resetConversation()
    }
}
#endif
```

- [ ] **Step 4: Jalankan test, pastikan lulus**

Run: perintah Step 2.
Expected: `Test run with 3 tests` … `** TEST SUCCEEDED **`

- [ ] **Step 5: Pasang di composition root**

Di `DinoPocketMac/App/AppDependencies.swift`, di dalam `live()`, ganti

```swift
        let brain: Brain
        var erasable: [any LocallyErasable] = []
        var transcripts: (any LocallyErasable)?
        if #available(macOS 26.0, *) {
            let sessionStore = FileChatSessionStore()
            brain = AppleBrain(sessionStore: sessionStore)
            erasable.append(sessionStore)
            transcripts = sessionStore
        } else {
            brain = AppleBrain()
        }
```

dengan

```swift
        let appleBrain: Brain
        var erasable: [any LocallyErasable] = []
        var transcripts: (any LocallyErasable)?
        if #available(macOS 26.0, *) {
            let sessionStore = FileChatSessionStore()
            appleBrain = AppleBrain(sessionStore: sessionStore)
            erasable.append(sessionStore)
            transcripts = sessionStore
        } else {
            appleBrain = AppleBrain()
        }

        #if DEBUG
        // Tab Debug di Settings bisa memaksa status Apple Intelligence untuk
        // menguji state AI mati tanpa menyentuh pengaturan sistem (spec B §8).
        let brain: Brain = DebugAvailabilityBrain(base: appleBrain, defaults: .standard)
        #else
        let brain = appleBrain
        #endif
```

Di `DinoPocketMac/Infrastructure/Services/LaunchAtLoginService.swift`, ganti protokolnya dengan:

```swift
protocol LaunchAtLoginManaging {
    var isEnabled: Bool { get }
    /// Pengguna pernah menolak Apl di Login Items; lihat `LaunchAtLoginService`.
    var needsUserApproval: Bool { get }
    /// Melempar bila sistem menolak; pemanggil harus mengembalikan toggle-nya.
    func setEnabled(_ enabled: Bool) throws
}
```

- [ ] **Step 6: Tulis jendela Settings**

Buat `DinoPocketMac/Presentation/Settings/DebugSettingsTab.swift`:

```swift
//
//  DebugSettingsTab.swift
//  Apl
//
//  KHUSUS DEBUG: memaksa status Apple Intelligence (spec B §8).
//

#if DEBUG
import SwiftUI

struct DebugSettingsTab: View {
    @AppStorage(ForcedAvailability.defaultsKey) private var forced: ForcedAvailability = .system

    var body: some View {
        Form {
            Picker("Apple Intelligence", selection: $forced) {
                ForEach(ForcedAvailability.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            Text("The main window re-checks this each time it becomes active. Debug builds only.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}

#Preview("Debug · Light") {
    DebugSettingsTab()
        .frame(width: 480, height: 200)
}

#Preview("Debug · Dark") {
    DebugSettingsTab()
        .frame(width: 480, height: 200)
        .preferredColorScheme(.dark)
}
#endif
```

Buat `DinoPocketMac/Presentation/Settings/SettingsWindow.swift`:

```swift
//
//  SettingsWindow.swift
//  Apl
//
//  Jendela Settings standar (⌘,), spec B §8: General · Character · Privacy,
//  ditambah Debug di build DEBUG. Layout A tidak punya sidebar, jadi
//  pengaturan pindah ke sini.
//

import SwiftUI

struct SettingsWindow: View {
    let profile: ProfileStore
    let buddySettings: BuddySettingsStore
    let launchAtLogin: any LaunchAtLoginManaging
    /// Menghapus semua data lokal. Pemanggil yang tahu store mana saja.
    let eraseAllData: () async -> Void

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralSettingsTab(profile: profile, launchAtLogin: launchAtLogin)
            }
            Tab("Character", systemImage: "face.smiling") {
                CharacterSettingsTab(buddySettings: buddySettings)
            }
            Tab("Privacy", systemImage: "hand.raised") {
                PrivacySettingsTab(eraseAllData: eraseAllData)
            }
            #if DEBUG
            Tab("Debug", systemImage: "ladybug") {
                DebugSettingsTab()
            }
            #endif
        }
        .frame(width: 480)
        .frame(minHeight: 280)
    }
}

// MARK: - General

private struct GeneralSettingsTab: View {
    let profile: ProfileStore
    let launchAtLogin: any LaunchAtLoginManaging

    @State private var nicknameDraft = ""
    @State private var launchAtLoginOn = false
    @State private var launchAtLoginError: String?

    /// Binding manual, bukan @State biasa: kalau SMAppService menolak, toggle
    /// harus kembali ke posisi semula alih-alih menampilkan keadaan palsu.
    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLoginOn },
            set: { wanted in
                do {
                    try launchAtLogin.setEnabled(wanted)
                    launchAtLoginOn = launchAtLogin.isEnabled
                    launchAtLoginError = nil
                } catch {
                    launchAtLoginOn = launchAtLogin.isEnabled
                    launchAtLoginError = "macOS refused that change: \(error.localizedDescription)"
                }
            }
        )
    }

    var body: some View {
        Form {
            Section {
                // Disimpan setiap kali draft berubah. Normalisasi hanya mengenai
                // nilai yang disimpan, bukan teks di kolom, jadi spasi yang sedang
                // diketik tidak termakan.
                //
                // SENGAJA tidak menyimpan saat tab ditutup: Erase All Data
                // mengganti jendela utama dengan onboarding, dan penyimpanan di
                // `onDisappear` menulis ulang nama tepat setelah dihapus.
                TextField("Nickname", text: $nicknameDraft, prompt: Text("What should Apl call you?"))
                    .onChange(of: nicknameDraft) { _, draft in profile.setNickname(draft) }
            }
            Section {
                Toggle("Launch at login", isOn: launchAtLoginBinding)
                if launchAtLogin.needsUserApproval {
                    // Status .requiresApproval berarti user pernah menolak app ini
                    // di Login Items; registrasi "berhasil" tanpa app pernah
                    // diluncurkan, jadi toggle menyala akan berbohong.
                    Text("Approve Apl in System Settings › General › Login Items.")
                        .font(.footnote)
                        .foregroundStyle(AppColor.statusWarning)
                }
                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .task {
            nicknameDraft = profile.nickname ?? ""
            launchAtLoginOn = launchAtLogin.isEnabled
        }
    }
}

// MARK: - Character

private struct CharacterSettingsTab: View {
    @Bindable var buddySettings: BuddySettingsStore

    var body: some View {
        Form {
            Section {
                LabeledContent("Size") {
                    HStack(spacing: Spacing.md) {
                        Slider(value: $buddySettings.size, in: BuddySettingsStore.sizeRange, step: 10)
                        Text("\(Int(buddySettings.size)) pt")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 56, alignment: .trailing)
                    }
                }
                LabeledContent("Opacity") {
                    HStack(spacing: Spacing.md) {
                        Slider(value: $buddySettings.opacity, in: BuddySettingsStore.opacityRange)
                        Text("\(Int(buddySettings.opacity * 100))%")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 56, alignment: .trailing)
                    }
                }
                Toggle("Keep on top of other windows", isOn: $buddySettings.keepOnTop)
                Toggle("Wander around the desktop", isOn: $buddySettings.strolling)
            } header: {
                Text("Buddy Mode")
            } footer: {
                Text("Changes apply immediately while Buddy Mode is running. Press Esc to leave Buddy Mode.")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Privacy

private struct PrivacySettingsTab: View {
    let eraseAllData: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isConfirming = false
    @State private var isErasing = false

    var body: some View {
        Form {
            Section {
                Text("Apl runs entirely on this Mac. Your conversation, reminders, and preferences never leave the device.")
                    .foregroundStyle(.secondary)
            }
            Section {
                Button("Erase All Data…", role: .destructive) {
                    isConfirming = true
                }
                .disabled(isErasing)
            } footer: {
                Text("Removes your conversation, reminders, and preferences, then starts Apl from the beginning.")
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Erase all data on this Mac?", isPresented: $isConfirming,
                            titleVisibility: .visible) {
            Button("Erase Everything", role: .destructive) {
                isErasing = true
                Task {
                    await eraseAllData()
                    isErasing = false
                    // Jendela utama sudah kembali ke onboarding; Settings ditutup.
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes your conversation, reminders, and preferences from this Mac. It can't be undone.")
        }
    }
}

#Preview("Settings · Light") {
    SettingsWindow(profile: ProfileStore(defaults: UserDefaults(suiteName: "apl.preview.profile")!),
                   buddySettings: BuddySettingsStore(defaults: UserDefaults(suiteName: "apl.preview.buddy")!),
                   launchAtLogin: LaunchAtLoginService(),
                   eraseAllData: {})
}

#Preview("Settings · Dark") {
    SettingsWindow(profile: ProfileStore(defaults: UserDefaults(suiteName: "apl.preview.profile")!),
                   buddySettings: BuddySettingsStore(defaults: UserDefaults(suiteName: "apl.preview.buddy")!),
                   launchAtLogin: LaunchAtLoginService(),
                   eraseAllData: {})
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 7: Ganti Settings sementara di `AplApp` dan hapus `SettingsPage`**

Di `DinoPocketMac/App/AplApp.swift`, ganti

```swift
        // SEMENTARA: halaman Settings lama ditampung jendela ⌘, sampai
        // jendela Settings bertab menggantikannya.
        Settings {
            SettingsPage(chat: chat, buddySettings: buddySettings, profile: profile,
                         extraErasableStores: Self.deps.erasableStores)
                .frame(width: 480, height: 560)
        }
    }
```

dengan

```swift
        Settings {
            SettingsWindow(profile: profile,
                           buddySettings: buddySettings,
                           launchAtLogin: Self.deps.launchAtLogin,
                           eraseAllData: { await eraseAllData() })
        }
    }

    /// Erase All Data (spec B §8). Tiap penyimpanan memusnahkan miliknya
    /// sendiri; UseCase ini tidak tahu satu pun nama kunci atau suite.
    private func eraseAllData() async {
        if isBuddyMode { dismissFromBuddy() }
        let stores: [any LocallyErasable] = [profile, chat, buddySettings] + Self.deps.erasableStores
        await EraseAllDataUseCase(stores: stores,
                                  clearNotifications: { await Self.deps.reminderScheduler.cancelAll() })
            .execute()
    }
```

Lalu:

```bash
git rm DinoPocketMac/Presentation/Views/SettingsPage.swift
```

- [ ] **Step 8: Build dan jalankan seluruh test**

Run: `xcodegen generate`, lalu perintah build, lalu perintah test semua.
Expected: `** BUILD SUCCEEDED **` dan `** TEST SUCCEEDED **` (±153 test).

Run: `bash scripts/verify-release.sh 2>&1 | tail -5`
Expected: `✅ konfigurasi Release siap`. Ini membuktikan kode `#if DEBUG` tidak bocor ke Release.

- [ ] **Step 9: Commit**

```bash
git add DinoPocketMac/Presentation/Settings DinoPocketMac/Infrastructure/Services/DebugAvailabilityBrain.swift \
  DinoPocketMac/Infrastructure/Services/LaunchAtLoginService.swift \
  DinoPocketMac/App/AppDependencies.swift DinoPocketMac/App/AplApp.swift \
  DinoPocketTests/DebugAvailabilityBrainTests.swift
git status --short   # penghapusan SettingsPage sudah di-stage oleh git rm
git commit -m "$(cat <<'EOF'
feat(b12): jendela Settings bertab dan override availability khusus DEBUG

Settings pindah ke jendela ⌘, standar dengan tab General (nama
panggilan, launch at login), Character (preferensi Buddy), dan Privacy
(Erase All Data dengan konfirmasi). Setelah dihapus, jendela Settings
ditutup dan jendela utama kembali ke onboarding.

Build DEBUG menambah tab Debug untuk memaksa status Apple Intelligence
lewat DebugAvailabilityBrain, sehingga state AI mati bisa diuji tanpa
mengubah pengaturan sistem. SettingsPage dihapus.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 13: Onboarding baru

**Files:**
- Move + rewrite: `DinoPocketMac/Presentation/Views/OnboardingView.swift` → `DinoPocketMac/Presentation/Onboarding/OnboardingView.swift`
- Modify: `DinoPocketMac/App/AplApp.swift`
- Test: `DinoPocketTests/OnboardingStepTests.swift`

**Interfaces:**
- Consumes:
  - `USDZCharacterView` (Task 6), token (Task 1)
  - `ChatStore.availability()`
  - `AppLaunching.open(.appleIntelligence)`, `ReminderScheduling.requestAuthorization()` / `.sync` (A)
- Produces:
  - `OnboardingView(profile:chat:launcher:requestNotifications:)`, dengan `requestNotifications: () async -> Bool`
  - `OnboardingView.Step: Int, CaseIterable { case welcome, reminders, intelligence }`, dengan `next: Step?` dan `previous: Step?`

- [ ] **Step 1: Tulis test yang gagal**

Buat `DinoPocketTests/OnboardingStepTests.swift`:

```swift
import Testing
@testable import Apl

@MainActor
struct OnboardingStepTests {

    /// Tiga langkah, tanpa akun (spec B §8). Start di langkah terakhir,
    /// bukan langkah keempat.
    @Test func stepsRunWelcomeRemindersIntelligence() {
        typealias Step = OnboardingView.Step

        #expect(Step.allCases == [.welcome, .reminders, .intelligence])
        #expect(Step.welcome.next == .reminders)
        #expect(Step.intelligence.next == nil)
        #expect(Step.welcome.previous == nil)
        #expect(Step.intelligence.previous == .reminders)
    }
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS,arch=arm64' -only-testing:DinoPocketTests/OnboardingStepTests 2>&1 | grep -E "Test run with|TEST (SUCCEEDED|FAILED)|error:|✘"`
Expected: FAIL, dengan `error: type 'OnboardingView.Step' has no member 'reminders'` (nama lamanya `notifications`) dan `has no member 'next'`.

- [ ] **Step 3: Pindahkan dan tulis ulang `OnboardingView`**

```bash
mkdir -p DinoPocketMac/Presentation/Onboarding
git mv DinoPocketMac/Presentation/Views/OnboardingView.swift DinoPocketMac/Presentation/Onboarding/OnboardingView.swift
```

Ganti seluruh isi `DinoPocketMac/Presentation/Onboarding/OnboardingView.swift`:

```swift
//
//  OnboardingView.swift
//  AplMac
//
//  Perkenalan sekali jalan, tanpa akun (spec B §8): robot menyapa dan
//  menanyakan nama → izin notifikasi → status Apple Intelligence.
//  Selesai = `hasCompletedOnboarding`; tidak ada keychain maupun kredensial.
//

import SwiftUI

struct OnboardingView: View {

    let profile: ProfileStore
    let chat: ChatStore
    let launcher: AppLaunching
    /// Meminta izin notifikasi lewat penjadwal reminder; true bila diizinkan.
    var requestNotifications: () async -> Bool = { false }

    @Environment(\.appearsActive) private var appearsActive
    @State private var step: Step = .welcome
    @State private var nicknameDraft = ""
    @State private var notificationDecision: NotificationDecision = .undecided
    @State private var availability: BrainAvailability?

    enum Step: Int, CaseIterable {
        case welcome, reminders, intelligence

        var next: Step? { Step(rawValue: rawValue + 1) }
        var previous: Step? { Step(rawValue: rawValue - 1) }
    }

    enum NotificationDecision {
        case undecided, granted, declined
    }

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: 420)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)

            Divider()
            footer
                .padding(20)
        }
        .frame(minWidth: 520, minHeight: 480)
        .background(Color(nsColor: .windowBackgroundColor))
        // Dicek ulang tiap kali jendela aktif: pengguna mungkin baru
        // menyalakan Apple Intelligence di System Settings.
        .onChange(of: appearsActive, initial: true) { _, isActive in
            guard isActive else { return }
            Task { availability = await chat.availability() }
        }
    }

    // MARK: - Langkah

    @ViewBuilder
    private var content: some View {
        VStack(spacing: Spacing.lg) {
            switch step {
            case .welcome:
                USDZCharacterView(size: 160, asset: .robot, behavior: .greet)
                Text("Hi, I'm Apl.")
                    .font(AppFont.title(28))
                paragraph("A small robot that lives on your desktop, chats with you, and keeps your "
                          + "reminders. Everything stays on this Mac.")
                TextField("Name", text: $nicknameDraft, prompt: Text("What should I call you? (optional)"))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 260)

            case .reminders:
                symbol("bell.badge")
                Text("Reminders")
                    .font(AppFont.title(24))
                paragraph("Ask me in chat, like “Remind me to stretch at 3 PM”. Reminders arrive as "
                          + "notifications, so I need your permission to show them.")
                switch notificationDecision {
                case .undecided:
                    HStack(spacing: Spacing.md) {
                        Button("Not now") {
                            notificationDecision = .declined
                            goForward()
                        }
                        Button("Allow Notifications") {
                            Task { await allowNotifications() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                case .granted:
                    Label("Notifications are on", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(AppColor.statusOK)
                case .declined:
                    Text("You can turn them on later in System Settings › Notifications.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

            case .intelligence:
                symbol("apple.intelligence")
                Text("Apple Intelligence")
                    .font(AppFont.title(24))
                paragraph("Chat runs on Apple Intelligence, right on this Mac. No account, and nothing "
                          + "is sent anywhere.")
                intelligenceStatus
                Text("Reminders and your character work without it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
    }

    @ViewBuilder
    private var intelligenceStatus: some View {
        switch availability {
        case .ready?:
            Label("Ready", systemImage: "checkmark.circle.fill")
                .foregroundStyle(AppColor.statusOK)
        case .needsSetup(let reason)?:
            Label(reason, systemImage: "arrow.down.circle")
                .foregroundStyle(.secondary)
        case .unavailable(let reason)?:
            VStack(spacing: Spacing.sm) {
                Label(reason, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppColor.statusWarning)
                Button("Open System Settings") {
                    _ = launcher.open(.appleIntelligence)
                }
            }
        case nil:
            ProgressView()
                .controlSize(.small)
        }
    }

    private var footer: some View {
        HStack {
            // Titik langkah, supaya pengguna tahu alurnya pendek.
            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.self) { item in
                    Circle()
                        .fill(item == step ? AppColor.accent : Color.secondary.opacity(0.3))
                        .frame(width: 7, height: 7)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Step \(step.rawValue + 1) of \(Step.allCases.count)")

            Spacer()

            if step.previous != nil {
                Button("Back") { goBack() }
            }
            // Start selalu aktif: reminder dan karakter berguna tanpa AI (spec B §8).
            Button(step.next == nil ? "Start" : "Continue") { goForward() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
    }

    // MARK: - Aksi

    private func goForward() {
        if step == .welcome {
            profile.setNickname(nicknameDraft)
        }
        guard let next = step.next else {
            profile.completeOnboarding()
            return
        }
        withAnimation(.easeInOut(duration: 0.18)) { step = next }
    }

    private func goBack() {
        guard let previous = step.previous else { return }
        withAnimation(.easeInOut(duration: 0.18)) { step = previous }
    }

    private func allowNotifications() async {
        notificationDecision = await requestNotifications() ? .granted : .declined
    }

    // MARK: - Potongan

    private func symbol(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 44, weight: .light))
            .foregroundStyle(AppColor.accent)
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview("Onboarding · Light") {
    OnboardingView(profile: ProfileStore(defaults: UserDefaults(suiteName: "apl.preview.profile")!),
                   chat: .preview([]), launcher: AppLauncherService())
        .frame(width: 640, height: 520)
}

#Preview("Onboarding · Dark") {
    OnboardingView(profile: ProfileStore(defaults: UserDefaults(suiteName: "apl.preview.profile")!),
                   chat: .preview([]), launcher: AppLauncherService())
        .frame(width: 640, height: 520)
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 4: Sambungkan izin notifikasi lewat penjadwal**

Di `DinoPocketMac/App/AplApp.swift`, ganti

```swift
            OnboardingView(profile: profile, chat: chat,
                           onNotificationsGranted: {
                               // Reminder yang dibuat sebelum izin diberikan baru bisa dijadwalkan sekarang.
                               await Self.deps.reminderScheduler.sync(Self.deps.reminderStore.reminders, now: .now)
                           })
```

dengan

```swift
            OnboardingView(profile: profile, chat: chat, launcher: Self.deps.appLauncher,
                           requestNotifications: {
                               let scheduler = Self.deps.reminderScheduler
                               let granted = await scheduler.requestAuthorization()
                               if granted {
                                   // Reminder yang dibuat sebelum izin diberikan baru bisa dijadwalkan sekarang.
                                   await scheduler.sync(Self.deps.reminderStore.reminders, now: .now)
                               }
                               return granted
                           })
```

- [ ] **Step 5: Jalankan test, build, dan seluruh test**

Run: perintah Step 2.
Expected: `Test run with 1 test` … `** TEST SUCCEEDED **`

Run: perintah build, lalu perintah test semua.
Expected: `** BUILD SUCCEEDED **` dan `** TEST SUCCEEDED **` (±154 test).

Run: `ls DinoPocketMac/Presentation/Views`
Expected: hanya `ContentView+iOS.swift`, `ContentView+macOS.swift`, `ContentView.swift`, dan `PetActivityWidgets.swift` (semuanya beku).

- [ ] **Step 6: Commit**

```bash
git add DinoPocketMac/Presentation/Onboarding DinoPocketMac/App/AplApp.swift DinoPocketTests/OnboardingStepTests.swift
git status --short   # pemindahan OnboardingView sudah di-stage oleh git mv
git commit -m "$(cat <<'EOF'
feat(b13): onboarding tiga langkah dengan robot yang menyapa

Langkah pertama menampilkan robot .greet dan menanyakan nama panggilan
(opsional). Langkah kedua meminta izin notifikasi lewat penjadwal
reminder, dengan "Not now" yang jelas. Langkah ketiga menampilkan status
Apple Intelligence, dicek ulang setiap kali jendela aktif, dengan jalan
ke System Settings. Start selalu aktif karena reminder dan karakter
berguna tanpa AI.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 14: Verifikasi akhir (Definition of Done spec B §11)

**Files:**
- Modify (bila ada temuan): berkas yang bersangkutan
- Modify: `docs/superpowers/specs/2026-09-15-apl-main-window-design.md` (centang §11)

**Interfaces:**
- Consumes: seluruh hasil Task 1–13
- Produces: bukti DoD — keluaran perintah dan screenshot di `$TMPDIR/apl-*.png`

- [ ] **Step 1: Pemeriksaan otomatis**

Run: perintah test semua.
Expected: `** TEST SUCCEEDED **` (±154 test dalam ±32 suite).

Run: `bash scripts/verify-boundaries.sh`
Expected: `✅ batas SharedCore aman`

Run: `bash scripts/verify-release.sh 2>&1 | tail -3`
Expected: `✅ konfigurasi Release siap`

- [ ] **Step 2: Grep Definition of Done**

```bash
# View lama tidak lagi ada di build
grep -rn -e DashboardTemplate -e SidebarView -e ChatPage -e MessageBubble -e AIUnavailableCard \
  -e HomePage -e SettingsPage DinoPocketMac/App DinoPocketMac/Presentation DinoPocketMac/Infrastructure \
  SharedCore project.yml | grep -v -e "/Views/ContentView" -e PetActivityWidgets
# Nol teks peringatan di dalam isi pesan
grep -rn -e "⚠️" -e "(cancelled)" -e "Connection lost" DinoPocketMac/App DinoPocketMac/Presentation SharedCore \
  | grep -v -e "/Views/ContentView" -e PetActivityWidgets
# Setiap view baru punya #Preview
for f in $(grep -rl ": View {" DinoPocketMac/Presentation --include="*.swift" | grep -v "/Views/"); do
  grep -q "#Preview" "$f" || echo "tanpa #Preview: $f"
done
```

Expected: ketiga perintah tidak mengeluarkan apa pun.

- [ ] **Step 3: Tampilan dark dan light, 1000×680 dan 740×520**

Jalankan app dengan perintah "Jalankan app" (Dark). Pastikan ukurannya 1000×680 dengan `osascript -e 'tell application "System Events" to tell process "Apl" to set size of front window to {1000, 680}'`, lalu potret (`apl-dark-1000.png`). Periksa terhadap artboard **A · Companion stage**:
- stage 320pt dengan inset 8pt dan radius 12
- robot di atas glow teal
- "Apl" rounded semibold
- baris status "Good morning/afternoon/evening!" dalam 3 detik pertama, lalu "Here when you need me"
- Up next dengan "See all", tombol Buddy Mode, dan tombol Settings
- header "Today", bubble pengguna teal di kanan, teks asisten tanpa bubble, dan composer kapsul dengan tombol kirim teal

Ubah ukuran ke 740×520 (perintah di bagian Alat verifikasi manual), lalu potret (`apl-dark-740.png`). Stage harus diganti header compact: avatar kecil, "Apl", status, tombol lonceng, Buddy, dan Settings. Tombol-tombol ini tidak boleh bertabrakan dengan tombol jendela.

Ulangi keduanya dengan `-AppleInterfaceStyle Light` (`apl-light-1000.png`, `apl-light-740.png`). Periksa kontras aksen `#127A8A`, bubble teal muda, dan stage yang terbedakan dari latar.

Bila hasilnya meleset dari artboard, perbaiki, jalankan ulang Step 1, lalu potret ulang.

- [ ] **Step 4: Reminder dari chat, chip, Up next, dan popover**

Kembalikan ukuran ke 1000×680. Ketik `remind me to stretch in 2 minutes` lalu Return (perintah System Events). **Dalam 3 detik**, potret (`apl-celebrate.png`).

Expected:
- robot memakai wajah senyum lebar
- status "Reminder set for …"
- chip "Stretch · Today, …" dengan Undo
- "Stretch" muncul di Up next

Setelah 3 detik, status kembali ke "Here when you need me".

Tekan **Undo** pada chip (AXPress). Chip berubah menjadi "Reminder removed" dan Up next tidak lagi memuat "Stretch".

Buat reminder lagi (`remind me to drink water every day at 9am`), lalu buka **See all**:
- **edit:** ganti judul menjadi "Drink a glass of water", Save. Up next ikut berubah.
- **hapus:** tekan tombol tong sampah. Baris "“…” removed · Undo" muncul.
- **undo:** tekan Undo. Reminder kembali.

Potret popover (`apl-popover.png`).

Catat pemakaian memori setelah kelima ekspresi dimuat (risiko spec B §12):

```bash
footprint "$(pgrep -x Apl)" | grep -m1 phys_footprint
```

Laporkan angkanya ke pengguna. Spec belum menetapkan batas. Bila jauh di atas ±500 MB, sebutkan opsi mitigasi dari spec (tukar tekstur wajah saja), tetapi jangan dikerjakan di B.

- [ ] **Step 5: Streaming, Esc, dan Clear Conversation**

Bila Apple Intelligence siap di Mac ini:
1. Ketik `write a long story about a robot` lalu Return.
2. Selama menunggu, potret (`apl-thinking.png`). Robot harus berwajah "O", status "Thinking…", dan titik-titik mengetik terlihat.
3. Tekan Esc (`key code 53`) di tengah jawaban. Teks yang sudah tertulis tetap ada dengan label "Stopped", dan tidak ada teks "(cancelled)".

Bila Apple Intelligence tidak siap, catat itu dan lewati langkah ini. Jangan ubah pengaturan sistem.

Tekan ⌘K (`keystroke "k" using command down`). Dialog "Clear this conversation?" muncul. Pilih **Clear Conversation**. Percakapan kosong dengan "Say hi to Apl", dan Up next tidak berubah.

- [ ] **Step 6: State AI mati lewat tab Debug**

Buka ⌘, → tab **Debug** → pilih **Not enabled** → klik jendela utama. Potret (`apl-ai-off.png`).

Expected:
- robot berwajah sedih dengan status "Apple Intelligence is off" dan titik oranye
- banner "Chat needs Apple Intelligence … Reminders still work." dengan tombol Open System Settings (jangan ditekan)
- composer tetap aktif dengan placeholder "Ask Apl for a reminder…"

Lalu:
- Ketik `remind me to stretch in 5 minutes` → reminder tetap dibuat dan chip muncul.
- Ketik `hello` → baris pemberitahuan muncul di bawah percakapan, tidak di dalam teks pesan.
- Pilih **Model downloading** → banner "Getting Apple Intelligence ready" tanpa tombol, dan composer terkunci dengan "Getting ready…". Potret (`apl-ai-downloading.png`).

Kembalikan pilihan ke **Use system status**.

- [ ] **Step 7: Settings dan Erase All Data**

Periksa tab General (Nickname, Launch at login), Character (empat kontrol Buddy), dan Privacy. Potret jendela Settings.

**Sebelum menekan Erase Everything, tanyakan dulu ke pengguna.** Tindakan ini menghapus percakapan, reminder, dan preferensi Apl di Mac ini. Bila disetujui:
1. Privacy → Erase All Data… → Erase Everything.
2. Jendela Settings harus tertutup dan jendela utama kembali ke onboarding.
3. Jalani tiga langkahnya: robot menyapa dengan kolom nama → Reminders dengan "Not now" / "Allow Notifications" → Apple Intelligence dengan status dan Start. Potret tiap langkah (`apl-onboarding-1..3.png`). Jangan klik dialog izin sistem; biarkan pengguna yang memutuskan.
4. Start membuka jendela utama.

- [ ] **Step 8: VoiceOver dan Reduce Motion (oleh pengguna)**

Minta pengguna menyalakan VoiceOver sendiri. Periksa bersama bahwa robot dibacakan "Apl, idle", lalu "Apl, thinking" saat menjawab, dan bahwa tombol kirim, stop, Undo, See all, Buddy Mode, dan Settings semuanya punya label.

Minta pengguna menyalakan Reduce Motion. Periksa bersama bahwa robot tidak lagi bergoyang, pergantian wajah tanpa efek pop, dan titik-titik mengetik diam.

Jangan mengubah kedua pengaturan itu atas nama pengguna.

- [ ] **Step 9: Centang DoD dan commit**

Di `docs/superpowers/specs/2026-09-15-apl-main-window-design.md` §11, ubah `- [ ]` menjadi `- [x]` untuk setiap butir yang terbukti di Step 1–8. Butir yang belum terbukti dibiarkan, lalu sebutkan alasannya kepada pengguna.

```bash
git add docs/superpowers/specs/2026-09-15-apl-main-window-design.md
# tambahkan juga berkas yang diperbaiki di Step 3–7, bila ada
git commit -m "$(cat <<'EOF'
docs(b14): verifikasi akhir sub-project B

Seluruh test, verify-boundaries, dan verify-release hijau. Jendela utama
diperiksa di dark dan light, pada 1000×680 dan 740×520. Reminder, chip,
popover, state AI mati, Clear Conversation, Erase All Data, dan
onboarding dijalankan di app sungguhan.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

Jangan push atau merge. Setelah commit, jalankan skill `superpowers:finishing-a-development-branch`.

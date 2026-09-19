# Apl C1 — Panggil dari Mana Saja — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apl bisa dipanggil dari app mana pun lewat satu tombol, menjawab di bubble kecil
di samping robot, dan percakapannya tetap satu dengan jendela utama.

**Architecture:** Empat unit murni (preset shortcut, router, penempatan, giliran) yang bisa
diuji tanpa satu pun jendela, dibungkus satu `NSPanel` yang bisa menerima ketikan dan satu
pendaftar hotkey Carbon. Sumber data bubble adalah `ChatStore` yang sama dengan jendela
utama — tidak ada penyimpanan kedua dan tidak ada sinkronisasi.

**Tech Stack:** Swift 6, SwiftUI, AppKit (`NSPanel`, `NSHostingView`), Carbon HIToolbox
(`RegisterEventHotKey`), Swift Testing, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-09-19-apl-quick-ask-design.md`

## Global Constraints

- Target **macOS 26+** (Apple Silicon), distribusi **Mac App Store**. Tidak boleh ada API
  yang butuh izin Accessibility atau Screen Recording.
- `SWIFT_VERSION: 6.0` dengan `SWIFT_APPROACHABLE_CONCURRENCY`. Semua tipe UI `@MainActor`.
- **XcodeGen**: setelah menambah atau memindahkan berkas, jalankan `xcodegen generate`
  sebelum build. `DinoPocket.xcodeproj` tidak masuk git.
- **Test host adalah `Apl.app`**: setiap test yang menyentuh `UserDefaults` WAJIB memakai
  suite terisolasi (`UserDefaults(suiteName:)` + `removePersistentDomain`), kalau tidak ia
  menulis ke data app sungguhan.
- **Durabilitas**: setiap penulisan preferensi diikuti `defaults.synchronize()`. Alasannya
  ditemukan di sub-project B — tanpa itu, data yang dihapus muncul lagi setelah Force Quit.
- `SharedCore` tidak boleh mengimpor SwiftUI/AppKit/UIKit (`scripts/verify-boundaries.sh`).
  Semua berkas C1 ada di `DinoPocketMac`, tidak satu pun di `SharedCore`.
- Teks antarmuka berbahasa **Inggris**; komentar dan dokumen berbahasa **Indonesia**,
  mengikuti basis kode yang ada.
- Setiap commit diakhiri trailer `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.
- **Jangan** mengubah pengaturan sistem macOS milik pengguna dan jangan menekan dialog izin
  sistem atas nama mereka.

## File Structure

**Dibuat:**

| Berkas | Tanggung jawab |
|---|---|
| `DinoPocketMac/Presentation/QuickAsk/ShortcutPreset.swift` | Enum pilihan shortcut → kode tombol, modifier, teks |
| `DinoPocketMac/Infrastructure/Persistence/ShortcutSettingsStore.swift` | Menyimpan pilihan, memberi tahu saat berubah |
| `DinoPocketMac/Presentation/QuickAsk/QuickAskRouter.swift` | Tiga cabang tindakan |
| `DinoPocketMac/Presentation/QuickAsk/BubblePlacement.swift` | Geometri bubble |
| `DinoPocketMac/Presentation/QuickAsk/QuickAskTurn.swift` | Giliran terakhir dari daftar pesan |
| `DinoPocketMac/Infrastructure/Services/HotKeyRegistering.swift` | Protokol + pendaftar Carbon |
| `DinoPocketMac/Infrastructure/Services/FocusRestorer.swift` | Mengingat dan memulihkan app depan |
| `DinoPocketMac/Presentation/QuickAsk/QuickAskBubble.swift` | Isi bubble (SwiftUI) |
| `DinoPocketMac/Presentation/QuickAsk/QuickAskPanelController.swift` | Panel, buka/tutup, penempatan |
| `DinoPocketMac/Presentation/Chat/ComposerFocus.swift` | Permintaan fokus composer jendela utama |

**Diubah:** `AplBuddyWindowController.swift` (frame karakter, tahan langkah, hapus sapaan
acak, klik → bubble), `Composer.swift` (menerima permintaan fokus), `ConversationView.swift`
(meneruskannya), `MainWindow.swift` (meneruskannya), `AplApp.swift` + `AplApp+macOS.swift`
(pemasangan), `AppDependencies.swift` (store baru), `SettingsWindow.swift` (baris shortcut),
`OnboardingView.swift` (satu kalimat).

**Test:** `DinoPocketTests/ShortcutPresetTests.swift`, `ShortcutSettingsStoreTests.swift`,
`QuickAskRouterTests.swift`, `BubblePlacementTests.swift`, `QuickAskTurnTests.swift`,
`QuickAskShortcutTests.swift`, `FocusRestorerTests.swift`.

---

### Task 1: Pilihan shortcut dan penyimpanannya

**Files:**
- Create: `DinoPocketMac/Presentation/QuickAsk/ShortcutPreset.swift`
- Create: `DinoPocketMac/Infrastructure/Persistence/ShortcutSettingsStore.swift`
- Test: `DinoPocketTests/ShortcutPresetTests.swift`, `DinoPocketTests/ShortcutSettingsStoreTests.swift`

**Interfaces:**
- Consumes: —
- Produces: `ShortcutPreset` (`.off`, `.optionSpace`, `.optionCommandA`, `.controlOptionSpace`;
  `keyCode: UInt32?`, `modifiers: UInt32`, `displayName: String`, `static let default`),
  `ShortcutSettingsStore` (`var preset: ShortcutPreset`, `var registrationFailed: Bool`,
  `var onChange: ((ShortcutPreset) -> Void)?`, `init(defaults:)`, `static let presetKey`).

- [ ] **Step 1: Tulis test yang gagal**

`DinoPocketTests/ShortcutPresetTests.swift`:

```swift
import Carbon.HIToolbox
import Foundation
import Testing
@testable import Apl

struct ShortcutPresetTests {

    @Test func offRegistersNothing() {
        #expect(ShortcutPreset.off.keyCode == nil)
        #expect(ShortcutPreset.off.modifiers == 0)
    }

    @Test func spacePresetsShareTheSpaceKey() {
        #expect(ShortcutPreset.optionSpace.keyCode == UInt32(kVK_Space))
        #expect(ShortcutPreset.controlOptionSpace.keyCode == UInt32(kVK_Space))
    }

    @Test func modifiersMatchTheirNames() {
        #expect(ShortcutPreset.optionSpace.modifiers == UInt32(optionKey))
        #expect(ShortcutPreset.optionCommandA.modifiers == UInt32(optionKey | cmdKey))
        #expect(ShortcutPreset.controlOptionSpace.modifiers == UInt32(controlKey | optionKey))
        #expect(ShortcutPreset.optionCommandA.keyCode == UInt32(kVK_ANSI_A))
    }

    /// Teksnya muncul di Settings dan di onboarding; kalau berubah, dua tempat
    /// itu ikut berbohong.
    @Test func displayNamesAreTheSymbolsPeopleSee() {
        #expect(ShortcutPreset.off.displayName == "Off")
        #expect(ShortcutPreset.optionSpace.displayName == "⌥Space")
        #expect(ShortcutPreset.optionCommandA.displayName == "⌥⌘A")
        #expect(ShortcutPreset.controlOptionSpace.displayName == "⌃⌥Space")
    }

    /// ⌃Space sengaja tidak ada: macOS memakainya untuk berpindah sumber input.
    @Test func controlSpaceAloneIsNotOffered() {
        #expect(ShortcutPreset.allCases.count == 4)
        #expect(ShortcutPreset.default == .optionSpace)
    }
}
```

`DinoPocketTests/ShortcutSettingsStoreTests.swift`:

```swift
import Foundation
import Testing
@testable import Apl

@MainActor
struct ShortcutSettingsStoreTests {

    private func isolatedDefaults(_ name: String) -> UserDefaults {
        let suite = "test.shortcut.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func freshInstallStartsAtTheDefaultPreset() {
        let store = ShortcutSettingsStore(defaults: isolatedDefaults(#function))
        #expect(store.preset == .optionSpace)
    }

    @Test func choiceSurvivesRelaunch() {
        let defaults = isolatedDefaults(#function)
        ShortcutSettingsStore(defaults: defaults).preset = .optionCommandA
        #expect(ShortcutSettingsStore(defaults: defaults).preset == .optionCommandA)
    }

    @Test func offSurvivesRelaunchInsteadOfFallingBackToDefault() {
        let defaults = isolatedDefaults(#function)
        ShortcutSettingsStore(defaults: defaults).preset = .off
        #expect(ShortcutSettingsStore(defaults: defaults).preset == .off)
    }

    @Test func unknownStoredValueFallsBackToDefault() {
        let defaults = isolatedDefaults(#function)
        defaults.set("commandShiftBanana", forKey: ShortcutSettingsStore.presetKey)
        #expect(ShortcutSettingsStore(defaults: defaults).preset == .optionSpace)
    }

    @Test func changingThePresetNotifiesOnce() {
        let store = ShortcutSettingsStore(defaults: isolatedDefaults(#function))
        var seen: [ShortcutPreset] = []
        store.onChange = { seen.append($0) }
        store.preset = .optionCommandA
        store.preset = .optionCommandA      // nilai sama: tidak diberitahukan lagi
        #expect(seen == [.optionCommandA])
    }

    @Test func eraseReturnsToDefaultAndLeavesNoKeyBehind() {
        let defaults = isolatedDefaults(#function)
        let store = ShortcutSettingsStore(defaults: defaults)
        store.preset = .off
        store.eraseAllStoredData()
        #expect(store.preset == .optionSpace)
        #expect(defaults.string(forKey: ShortcutSettingsStore.presetKey) == nil)
    }
}
```

- [ ] **Step 2: Jalankan test dan pastikan gagal**

Run: `xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/ShortcutPresetTests 2>&1 | tail -30`
Expected: gagal build, `cannot find 'ShortcutPreset' in scope`.

- [ ] **Step 3: Tulis `ShortcutPreset`**

```swift
//
//  ShortcutPreset.swift
//  Apl
//
//  Pilihan shortcut siap pakai (spec C1 §5).
//
//  Bukan perekam tombol: daftar tertutup berarti tidak ada kombinasi sembarang
//  yang harus divalidasi, disimpan, dan diterjemahkan kembali ke Carbon.
//
//  ⌃Space tidak ditawarkan — macOS memakainya untuk berpindah sumber input.
//  ⌥Space sendiri adalah bawaan Raycast dan Alfred, jadi Off dan dua alternatif
//  wajib ada, bukan pelengkap.
//

import Carbon.HIToolbox
import Foundation

enum ShortcutPreset: String, CaseIterable, Sendable {
    case off
    case optionSpace
    case optionCommandA
    case controlOptionSpace

    static let `default` = ShortcutPreset.optionSpace

    /// `nil` berarti tidak ada yang didaftarkan ke sistem.
    var keyCode: UInt32? {
        switch self {
        case .off: nil
        case .optionSpace, .controlOptionSpace: UInt32(kVK_Space)
        case .optionCommandA: UInt32(kVK_ANSI_A)
        }
    }

    /// Bendera modifier Carbon, bukan `NSEvent.ModifierFlags`.
    var modifiers: UInt32 {
        switch self {
        case .off: 0
        case .optionSpace: UInt32(optionKey)
        case .optionCommandA: UInt32(optionKey | cmdKey)
        case .controlOptionSpace: UInt32(controlKey | optionKey)
        }
    }

    var displayName: String {
        switch self {
        case .off: "Off"
        case .optionSpace: "⌥Space"
        case .optionCommandA: "⌥⌘A"
        case .controlOptionSpace: "⌃⌥Space"
        }
    }
}
```

- [ ] **Step 4: Tulis `ShortcutSettingsStore`**

```swift
//
//  ShortcutSettingsStore.swift
//  Apl
//
//  Satu pilihan, satu kunci (spec C1 §5). Perubahan diteruskan lewat `onChange`
//  supaya pendaftar hotkey tidak perlu mengamati UserDefaults.
//

import Foundation
import Observation

@MainActor
@Observable
final class ShortcutSettingsStore {

    nonisolated static let presetKey = "shortcut.quickAsk"

    var preset: ShortcutPreset {
        didSet {
            guard preset != oldValue else { return }
            defaults.set(preset.rawValue, forKey: Self.presetKey)
            // Dipaksa turun ke disk; lihat catatan di `ProfileStore`.
            defaults.synchronize()
            onChange?(preset)
        }
    }

    /// Disetel pendaftar saat macOS menolak kombinasinya. Settings membacanya
    /// untuk satu baris peringatan; tidak pernah disimpan ke disk.
    var registrationFailed = false

    var onChange: ((ShortcutPreset) -> Void)?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.string(forKey: Self.presetKey)
        self.preset = stored.flatMap(ShortcutPreset.init(rawValue:)) ?? .default
    }
}

extension ShortcutSettingsStore: LocallyErasable {
    /// Urutannya disengaja: `preset` disetel lebih dulu supaya `onChange`
    /// mendaftarkan ulang tombol bawaan, baru kuncinya dibuang dari disk.
    func eraseAllStoredData() {
        preset = .default
        defaults.removeObject(forKey: Self.presetKey)
        defaults.synchronize()
    }
}
```

- [ ] **Step 5: Regenerasi project dan jalankan test**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/ShortcutPresetTests -only-testing:DinoPocketTests/ShortcutSettingsStoreTests 2>&1 | tail -20`
Expected: PASS (11 test).

- [ ] **Step 6: Commit**

```bash
git add DinoPocketMac/Presentation/QuickAsk/ShortcutPreset.swift DinoPocketMac/Infrastructure/Persistence/ShortcutSettingsStore.swift DinoPocketTests/ShortcutPresetTests.swift DinoPocketTests/ShortcutSettingsStoreTests.swift
git commit -m "$(cat <<'EOF'
feat(c1): pilihan shortcut siap pakai dan penyimpanannya

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Router tiga cabang

**Files:**
- Create: `DinoPocketMac/Presentation/QuickAsk/QuickAskRouter.swift`
- Test: `DinoPocketTests/QuickAskRouterTests.swift`

**Interfaces:**
- Consumes: —
- Produces: `QuickAskAction` (`.focusComposer`, `.toggleBubble`, `.openMainWindow`),
  `QuickAskRouter.action(mainWindowIsFrontmost:buddyIsRunning:) -> QuickAskAction`.

- [ ] **Step 1: Tulis test yang gagal**

```swift
import Testing
@testable import Apl

struct QuickAskRouterTests {

    /// Buddy bersifat aditif — jendela utama TIDAK disembunyikan saat robot
    /// hidup, jadi kedua kondisi bisa benar bersamaan dan urutannya menentukan.
    @Test func frontmostMainWindowWinsOverBuddy() {
        #expect(QuickAskRouter.action(mainWindowIsFrontmost: true, buddyIsRunning: true)
                == .focusComposer)
    }

    @Test func buddyRunningBehindOtherAppsOpensTheBubble() {
        #expect(QuickAskRouter.action(mainWindowIsFrontmost: false, buddyIsRunning: true)
                == .toggleBubble)
    }

    @Test func withoutBuddyTheShortcutBringsTheWindow() {
        #expect(QuickAskRouter.action(mainWindowIsFrontmost: false, buddyIsRunning: false)
                == .openMainWindow)
    }

    @Test func frontmostWindowWithoutBuddyStillJustFocuses() {
        #expect(QuickAskRouter.action(mainWindowIsFrontmost: true, buddyIsRunning: false)
                == .focusComposer)
    }
}
```

- [ ] **Step 2: Jalankan test dan pastikan gagal**

Run: `xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/QuickAskRouterTests 2>&1 | tail -20`
Expected: gagal build, `cannot find 'QuickAskRouter' in scope`.

- [ ] **Step 3: Tulis implementasinya**

```swift
//
//  QuickAskRouter.swift
//  Apl
//
//  Satu tombol, tiga arti (spec C1 §3).
//

enum QuickAskAction: Equatable {
    /// Jendela utama sudah di depan: cukup pindahkan fokus ke composer.
    case focusComposer
    /// Robot ada di desktop: buka atau tutup bubble di sampingnya.
    case toggleBubble
    /// Tidak ada robot: bawa jendela utama ke depan.
    case openMainWindow
}

enum QuickAskRouter {

    /// Jendela utama menang atas Buddy. Keduanya bisa hidup bersamaan, dan
    /// menaruh bubble di atas jendela yang sedang dipakai hanya menutupi
    /// percakapan yang sudah terbuka di sana.
    static func action(mainWindowIsFrontmost: Bool, buddyIsRunning: Bool) -> QuickAskAction {
        if mainWindowIsFrontmost { return .focusComposer }
        return buddyIsRunning ? .toggleBubble : .openMainWindow
    }
}
```

- [ ] **Step 4: Jalankan test dan pastikan lulus**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/QuickAskRouterTests 2>&1 | tail -20`
Expected: PASS (4 test).

- [ ] **Step 5: Commit**

```bash
git add DinoPocketMac/Presentation/QuickAsk/QuickAskRouter.swift DinoPocketTests/QuickAskRouterTests.swift
git commit -m "$(cat <<'EOF'
feat(c1): router tiga cabang untuk shortcut

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Geometri bubble

**Files:**
- Create: `DinoPocketMac/Presentation/QuickAsk/BubblePlacement.swift`
- Test: `DinoPocketTests/BubblePlacementTests.swift`

**Interfaces:**
- Consumes: —
- Produces: `BubblePlacement.width` (360), `.answerMaxHeight` (200), `.maxHeight` (280),
  `.gap` (12), `BubblePlacement.frame(robot:screen:contentHeight:) -> CGRect`.

- [ ] **Step 1: Tulis test yang gagal**

```swift
import CoreGraphics
import Testing
@testable import Apl

struct BubblePlacementTests {

    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

    private func robot(x: CGFloat) -> CGRect {
        CGRect(x: x, y: 100, width: 120, height: 120)
    }

    @Test func sitsToTheRightWhenThereIsRoom() {
        let frame = BubblePlacement.frame(robot: robot(x: 400), screen: screen, contentHeight: 180)
        #expect(frame.minX == 400 + 120 + BubblePlacement.gap)
        #expect(frame.width == BubblePlacement.width)
    }

    /// Tepi atas bubble sejajar tepi atas karakter — "sejajar kepala".
    @Test func topAlignsWithTheCharacter() {
        let frame = BubblePlacement.frame(robot: robot(x: 400), screen: screen, contentHeight: 180)
        #expect(frame.maxY == robot(x: 400).maxY)
    }

    @Test func flipsToTheLeftWhenTheRightEdgeIsClose() {
        let frame = BubblePlacement.frame(robot: robot(x: 1260), screen: screen, contentHeight: 180)
        #expect(frame.maxX == 1260 - BubblePlacement.gap)
    }

    @Test func staysInsideTheScreenWhenBothSidesAreTight() {
        let narrow = CGRect(x: 0, y: 0, width: 500, height: 400)
        let frame = BubblePlacement.frame(robot: CGRect(x: 190, y: 100, width: 120, height: 120),
                                          screen: narrow, contentHeight: 180)
        #expect(frame.minX >= narrow.minX)
        #expect(frame.maxX <= narrow.maxX)
        #expect(frame.minY >= narrow.minY)
        #expect(frame.maxY <= narrow.maxY)
    }

    @Test func tallContentStopsAtTheCeiling() {
        let frame = BubblePlacement.frame(robot: robot(x: 400), screen: screen, contentHeight: 900)
        #expect(frame.height == BubblePlacement.maxHeight)
    }

    /// Layar sekunder punya origin bukan nol. Hari ini robot terkunci di layar
    /// utama, tapi geometrinya tidak boleh ikut terkunci.
    @Test func followsTheCharacterOntoASecondDisplay() {
        let second = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
        let frame = BubblePlacement.frame(robot: CGRect(x: 2800, y: 300, width: 120, height: 120),
                                          screen: second, contentHeight: 180)
        #expect(frame.minX >= second.minX)
        #expect(frame.maxX <= second.maxX)
    }

    /// Karakter di dasar layar: bubble tidak boleh menggantung di bawah tepi.
    @Test func doesNotHangBelowTheScreen() {
        let frame = BubblePlacement.frame(robot: CGRect(x: 400, y: 0, width: 120, height: 120),
                                          screen: screen, contentHeight: 260)
        #expect(frame.minY >= screen.minY)
    }
}
```

- [ ] **Step 2: Jalankan test dan pastikan gagal**

Run: `xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/BubblePlacementTests 2>&1 | tail -20`
Expected: gagal build, `cannot find 'BubblePlacement' in scope`.

- [ ] **Step 3: Tulis implementasinya**

```swift
//
//  BubblePlacement.swift
//  Apl
//
//  Di mana bubble berdiri terhadap robot (spec C1 §4).
//
//  Fungsi murni, tanpa NSWindow dan tanpa NSScreen: semua yang dibutuhkan
//  masuk lewat parameter, sehingga sisi-mana dan jepitan tepi bisa diuji tanpa
//  menyalakan app.
//

import CoreGraphics

enum BubblePlacement {

    static let width: CGFloat = 360
    /// Batas area jawaban sebelum ia mulai digulir.
    static let answerMaxHeight: CGFloat = 200
    /// Batas seluruh bubble. Jaring pengaman: isi yang lebih tinggi dipotong.
    static let maxHeight: CGFloat = 280
    static let gap: CGFloat = 12

    /// - Parameters:
    ///   - robot: frame karakter dalam koordinat layar.
    ///   - screen: `visibleFrame` layar tempat karakter berada.
    ///   - contentHeight: tinggi yang diminta isi bubble.
    static func frame(robot: CGRect, screen: CGRect, contentHeight: CGFloat) -> CGRect {
        let height = min(max(contentHeight, 0), maxHeight)

        let roomRight = screen.maxX - robot.maxX
        let roomLeft = robot.minX - screen.minX
        // Kanan lebih disukai, tapi hanya kalau muat. Kalau dua-duanya sempit,
        // sisi yang lebih lega yang menang dan jepitan di bawah yang merapikan.
        let prefersRight = roomRight >= width + gap || roomRight >= roomLeft

        let rawX = prefersRight ? robot.maxX + gap : robot.minX - gap - width
        let x = clamp(rawX, lower: screen.minX + gap, upper: screen.maxX - gap - width)

        // Sejajar kepala: tepi atas bubble bertemu tepi atas karakter.
        let rawY = robot.maxY - height
        let y = clamp(rawY, lower: screen.minY + gap, upper: screen.maxY - gap - height)

        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Batas bawah menang saat layar lebih sempit dari bubble — lebih baik
    /// menempel di tepi kiri daripada melayang di luar layar.
    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        max(lower, min(value, max(lower, upper)))
    }
}
```

- [ ] **Step 4: Jalankan test dan pastikan lulus**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/BubblePlacementTests 2>&1 | tail -20`
Expected: PASS (7 test).

- [ ] **Step 5: Commit**

```bash
git add DinoPocketMac/Presentation/QuickAsk/BubblePlacement.swift DinoPocketTests/BubblePlacementTests.swift
git commit -m "$(cat <<'EOF'
feat(c1): geometri bubble yang tidak pernah keluar layar

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Giliran terakhir

**Files:**
- Create: `DinoPocketMac/Presentation/QuickAsk/QuickAskTurn.swift`
- Test: `DinoPocketTests/QuickAskTurnTests.swift`

**Interfaces:**
- Consumes: `ChatMessage` (`role`, `text`, `status`, `id`) dari SharedCore.
- Produces: `QuickAskTurn` (`question: String`, `answer: ChatMessage?`),
  `QuickAskTurn.latest(in: [ChatMessage]) -> QuickAskTurn?`.

- [ ] **Step 1: Tulis test yang gagal**

```swift
import Foundation
import Testing
@testable import Apl

struct QuickAskTurnTests {

    @Test func emptyConversationHasNoTurn() {
        #expect(QuickAskTurn.latest(in: []) == nil)
    }

    @Test func questionWithoutAnswerYet() {
        let turn = QuickAskTurn.latest(in: [ChatMessage(role: .user, text: "Hi")])
        #expect(turn?.question == "Hi")
        #expect(turn?.answer == nil)
    }

    @Test func questionWithItsAnswer() {
        let turn = QuickAskTurn.latest(in: [
            ChatMessage(role: .user, text: "Hi"),
            ChatMessage(role: .assistant, text: "Hello"),
        ])
        #expect(turn?.question == "Hi")
        #expect(turn?.answer?.text == "Hello")
    }

    /// Bubble menampilkan SATU giliran: yang lama tidak boleh ikut terbawa.
    @Test func onlyTheLastTurnSurvives() {
        let turn = QuickAskTurn.latest(in: [
            ChatMessage(role: .user, text: "First"),
            ChatMessage(role: .assistant, text: "One"),
            ChatMessage(role: .user, text: "Second"),
            ChatMessage(role: .assistant, text: "Two"),
        ])
        #expect(turn?.question == "Second")
        #expect(turn?.answer?.text == "Two")
    }

    /// Pertanyaan baru mengosongkan jawaban, bukan menampilkan jawaban lama.
    @Test func newQuestionDropsThePreviousAnswer() {
        let turn = QuickAskTurn.latest(in: [
            ChatMessage(role: .user, text: "First"),
            ChatMessage(role: .assistant, text: "One"),
            ChatMessage(role: .user, text: "Second"),
        ])
        #expect(turn?.question == "Second")
        #expect(turn?.answer == nil)
    }

    @Test func failedAnswerIsStillTheAnswer() {
        let turn = QuickAskTurn.latest(in: [
            ChatMessage(role: .user, text: "Hi"),
            ChatMessage(role: .assistant, text: "", status: .failed),
        ])
        #expect(turn?.answer?.status == .failed)
    }
}
```

- [ ] **Step 2: Jalankan test dan pastikan gagal**

Run: `xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/QuickAskTurnTests 2>&1 | tail -20`
Expected: gagal build, `cannot find 'QuickAskTurn' in scope`.

- [ ] **Step 3: Tulis implementasinya**

```swift
//
//  QuickAskTurn.swift
//  Apl
//
//  Satu giliran: pertanyaan terakhir dan jawabannya (spec C1 §2 #2).
//
//  Bubble tidak menyimpan apa pun sendiri — ia memotong `ChatStore.messages`
//  setiap kali digambar. Karena itu isi bubble tidak pernah bisa berbeda dari
//  isi jendela utama.
//

struct QuickAskTurn: Equatable {
    let question: String
    /// `nil` selama jawaban belum ada (baru dikirim, atau sedang mengalir).
    let answer: ChatMessage?

    static func latest(in messages: [ChatMessage]) -> QuickAskTurn? {
        guard let asked = messages.lastIndex(where: { $0.role == .user }) else { return nil }
        let next = messages.index(after: asked)
        let answer = messages.indices.contains(next) && messages[next].role == .assistant
            ? messages[next]
            : nil
        return QuickAskTurn(question: messages[asked].text, answer: answer)
    }
}
```

- [ ] **Step 4: Jalankan test dan pastikan lulus**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/QuickAskTurnTests 2>&1 | tail -20`
Expected: PASS (6 test).

- [ ] **Step 5: Commit**

```bash
git add DinoPocketMac/Presentation/QuickAsk/QuickAskTurn.swift DinoPocketTests/QuickAskTurnTests.swift
git commit -m "$(cat <<'EOF'
feat(c1): giliran terakhir dipotong dari percakapan yang sama

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Pendaftaran hotkey global

**Files:**
- Create: `DinoPocketMac/Infrastructure/Services/HotKeyRegistering.swift`
- Test: `DinoPocketTests/QuickAskShortcutTests.swift`

**Interfaces:**
- Consumes: `ShortcutPreset` (Task 1).
- Produces: `HotKeyRegistering` (`register(keyCode:modifiers:handler:) -> Bool`,
  `unregister()`), `CarbonHotKeyRegistrar`, `QuickAskShortcut` (`init(registrar:)`,
  `apply(_ preset: ShortcutPreset, handler: @escaping () -> Void) -> Bool`, `stop()`).

- [ ] **Step 1: Tulis test yang gagal**

```swift
import Carbon.HIToolbox
import Testing
@testable import Apl

@MainActor
final class FakeHotKeyRegistrar: HotKeyRegistering {
    var registered: (keyCode: UInt32, modifiers: UInt32)?
    var registerCount = 0
    var unregisterCount = 0
    /// Disetel test untuk meniru macOS yang menolak kombinasinya.
    var refuses = false
    private var handler: (() -> Void)?

    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) -> Bool {
        registerCount += 1
        guard !refuses else { return false }
        registered = (keyCode, modifiers)
        self.handler = handler
        return true
    }

    func unregister() {
        unregisterCount += 1
        registered = nil
        handler = nil
    }

    func simulatePress() { handler?() }
}

@MainActor
struct QuickAskShortcutTests {

    @Test func applyingAPresetRegistersItsKey() {
        let registrar = FakeHotKeyRegistrar()
        let shortcut = QuickAskShortcut(registrar: registrar)
        #expect(shortcut.apply(.optionCommandA, handler: {}))
        #expect(registrar.registered?.keyCode == UInt32(kVK_ANSI_A))
        #expect(registrar.registered?.modifiers == UInt32(optionKey | cmdKey))
    }

    @Test func pressingTheKeyCallsTheHandler() {
        let registrar = FakeHotKeyRegistrar()
        let shortcut = QuickAskShortcut(registrar: registrar)
        var fired = 0
        _ = shortcut.apply(.optionSpace, handler: { fired += 1 })
        registrar.simulatePress()
        #expect(fired == 1)
    }

    /// Mengganti pilihan tidak boleh meninggalkan tombol lama terdaftar.
    @Test func changingPresetReplacesTheRegistration() {
        let registrar = FakeHotKeyRegistrar()
        let shortcut = QuickAskShortcut(registrar: registrar)
        _ = shortcut.apply(.optionSpace, handler: {})
        _ = shortcut.apply(.optionCommandA, handler: {})
        #expect(registrar.unregisterCount == 2)     // sekali sebelum tiap pendaftaran
        #expect(registrar.registered?.keyCode == UInt32(kVK_ANSI_A))
    }

    @Test func offRegistersNothingAndReportsSuccess() {
        let registrar = FakeHotKeyRegistrar()
        let shortcut = QuickAskShortcut(registrar: registrar)
        #expect(shortcut.apply(.off, handler: {}))
        #expect(registrar.registerCount == 0)
        #expect(registrar.registered == nil)
    }

    /// Kombinasi yang ditolak sistem dilaporkan, bukan ditelan diam-diam.
    @Test func refusedRegistrationIsReported() {
        let registrar = FakeHotKeyRegistrar()
        registrar.refuses = true
        let shortcut = QuickAskShortcut(registrar: registrar)
        #expect(shortcut.apply(.optionSpace, handler: {}) == false)
    }

    @Test func stoppingUnregisters() {
        let registrar = FakeHotKeyRegistrar()
        let shortcut = QuickAskShortcut(registrar: registrar)
        _ = shortcut.apply(.optionSpace, handler: {})
        shortcut.stop()
        #expect(registrar.registered == nil)
    }
}
```

- [ ] **Step 2: Jalankan test dan pastikan gagal**

Run: `xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/QuickAskShortcutTests 2>&1 | tail -20`
Expected: gagal build, `cannot find type 'HotKeyRegistering' in scope`.

- [ ] **Step 3: Tulis protokol, pendaftar Carbon, dan pembungkusnya**

```swift
//
//  HotKeyRegistering.swift
//  Apl
//
//  Hotkey global tanpa izin Accessibility (spec C1 §5).
//
//  `RegisterEventHotKey` dipilih, bukan `CGEventTap`: event tap butuh izin
//  Accessibility yang tidak bisa didapat app sandbox di Mac App Store, dan ia
//  membaca SETIAP tombol yang ditekan pengguna. Carbon hanya memberi tahu saat
//  satu kombinasi yang didaftarkan ditekan.
//
//  Pendaftaran disembunyikan di balik protokol karena test berjalan di dalam
//  Apl.app dan tidak boleh mendaftarkan tombol sungguhan ke sistem.
//

import Carbon.HIToolbox
import Foundation

@MainActor
protocol HotKeyRegistering: AnyObject {
    /// `false` bila sistem menolak — biasanya karena kombinasinya sudah dipegang
    /// pihak lain.
    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) -> Bool
    func unregister()
}

@MainActor
final class CarbonHotKeyRegistrar: HotKeyRegistering {

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var handler: (() -> Void)?

    /// 'APL1' — penanda milik app ini di daftar hotkey proses.
    private static let signature = OSType(0x4150_4C31)

    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) -> Bool {
        unregister()
        self.handler = handler

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let installed = InstallEventHandler(GetApplicationEventTarget(),
                                            hotKeyEventHandler,
                                            1,
                                            &spec,
                                            Unmanaged.passUnretained(self).toOpaque(),
                                            &eventHandler)
        guard installed == noErr else {
            self.handler = nil
            return false
        }

        let id = EventHotKeyID(signature: Self.signature, id: 1)
        let registered = RegisterEventHotKey(keyCode, modifiers, id,
                                             GetApplicationEventTarget(), 0, &hotKeyRef)
        guard registered == noErr else {
            unregister()
            return false
        }
        return true
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        handler = nil
    }

    fileprivate func fire() {
        handler?()
    }
}

/// Callback C: berjalan di main run loop, jadi isolasinya ditegaskan, bukan
/// dilompati dengan `Task` yang menunda satu putaran.
private let hotKeyEventHandler: EventHandlerUPP = { _, _, userData in
    guard let userData else { return noErr }
    let registrar = Unmanaged<CarbonHotKeyRegistrar>.fromOpaque(userData).takeUnretainedValue()
    MainActor.assumeIsolated { registrar.fire() }
    return noErr
}

/// Menerjemahkan pilihan pengguna jadi pendaftaran, dan menjaga hanya ada satu
/// yang aktif.
@MainActor
final class QuickAskShortcut {

    private let registrar: any HotKeyRegistering

    init(registrar: any HotKeyRegistering = CarbonHotKeyRegistrar()) {
        self.registrar = registrar
    }

    /// `false` hanya bila sistem menolak kombinasinya. `.off` selalu berhasil:
    /// tidak mendaftarkan apa pun adalah hasil yang diminta.
    @discardableResult
    func apply(_ preset: ShortcutPreset, handler: @escaping () -> Void) -> Bool {
        registrar.unregister()
        guard let keyCode = preset.keyCode else { return true }
        return registrar.register(keyCode: keyCode, modifiers: preset.modifiers, handler: handler)
    }

    func stop() {
        registrar.unregister()
    }
}
```

- [ ] **Step 4: Jalankan test dan pastikan lulus**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/QuickAskShortcutTests 2>&1 | tail -20`
Expected: PASS (6 test).

- [ ] **Step 5: Commit**

```bash
git add DinoPocketMac/Infrastructure/Services/HotKeyRegistering.swift DinoPocketTests/QuickAskShortcutTests.swift
git commit -m "$(cat <<'EOF'
feat(c1): hotkey global lewat Carbon, tanpa izin Accessibility

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Mengembalikan fokus

**Files:**
- Create: `DinoPocketMac/Infrastructure/Services/FocusRestorer.swift`
- Test: `DinoPocketTests/FocusRestorerTests.swift`

**Interfaces:**
- Consumes: —
- Produces: `ActivatableApp` (`isCurrent`, `isTerminated`, `activateNow() -> Bool`),
  `FocusRestorer` (`init(frontmostApp:)`, `remember()`, `restore()`).

- [ ] **Step 1: Tulis test yang gagal**

```swift
import Testing
@testable import Apl

final class FakeApp: ActivatableApp {
    var isCurrent: Bool
    var isTerminated = false
    private(set) var activations = 0

    init(isCurrent: Bool = false) { self.isCurrent = isCurrent }

    @discardableResult
    func activateNow() -> Bool {
        activations += 1
        return true
    }
}

@MainActor
struct FocusRestorerTests {

    @Test func returnsFocusToTheAppThatHadIt() {
        let other = FakeApp()
        let restorer = FocusRestorer(frontmostApp: { other })
        restorer.remember()
        restorer.restore()
        #expect(other.activations == 1)
    }

    /// Kalau Apl sendiri sudah di depan, tidak ada yang perlu dikembalikan —
    /// mengaktifkan diri sendiri akan merebut fokus dari jendela utama.
    @Test func doesNothingWhenAplWasAlreadyFrontmost() {
        let apl = FakeApp(isCurrent: true)
        let restorer = FocusRestorer(frontmostApp: { apl })
        restorer.remember()
        restorer.restore()
        #expect(apl.activations == 0)
    }

    @Test func doesNotResurrectAnAppThatQuit() {
        let other = FakeApp()
        let restorer = FocusRestorer(frontmostApp: { other })
        restorer.remember()
        other.isTerminated = true
        restorer.restore()
        #expect(other.activations == 0)
    }

    /// Bubble bisa ditutup dua kali (Esc lalu app lain aktif); yang kedua diam.
    @Test func restoringTwiceActivatesOnce() {
        let other = FakeApp()
        let restorer = FocusRestorer(frontmostApp: { other })
        restorer.remember()
        restorer.restore()
        restorer.restore()
        #expect(other.activations == 1)
    }

    @Test func restoringWithoutRememberingIsHarmless() {
        let other = FakeApp()
        let restorer = FocusRestorer(frontmostApp: { other })
        restorer.restore()
        #expect(other.activations == 0)
    }
}
```

- [ ] **Step 2: Jalankan test dan pastikan gagal**

Run: `xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/FocusRestorerTests 2>&1 | tail -20`
Expected: gagal build, `cannot find type 'ActivatableApp' in scope`.

- [ ] **Step 3: Tulis implementasinya**

```swift
//
//  FocusRestorer.swift
//  Apl
//
//  Bubble harus mengambil fokus untuk bisa diketik, dan mengembalikannya saat
//  ditutup (spec C1 §4). Tanpa ini, menjawab satu pertanyaan berarti pengguna
//  harus mengklik kembali ke editor yang tadi dipakainya.
//

import AppKit

/// Bagian kecil `NSRunningApplication` yang benar-benar dipakai — supaya
/// pemulihan fokus bisa diuji tanpa app kedua.
protocol ActivatableApp: AnyObject {
    var isCurrent: Bool { get }
    var isTerminated: Bool { get }
    @discardableResult func activateNow() -> Bool
}

extension NSRunningApplication: ActivatableApp {
    var isCurrent: Bool { self == NSRunningApplication.current }

    @discardableResult
    func activateNow() -> Bool {
        activate(from: .current, options: [])
    }
}

@MainActor
final class FocusRestorer {

    private let frontmostApp: () -> (any ActivatableApp)?
    private var remembered: (any ActivatableApp)?

    init(frontmostApp: @escaping () -> (any ActivatableApp)? = { NSWorkspace.shared.frontmostApplication }) {
        self.frontmostApp = frontmostApp
    }

    /// Dipanggil TEPAT SEBELUM Apl mengambil fokus.
    func remember() {
        let app = frontmostApp()
        // Apl sendiri bukan tujuan pemulihan: mengaktifkannya lagi saat bubble
        // tutup akan merebut fokus dari jendela utama yang mungkin dibuka
        // pengguna di antaranya.
        remembered = (app?.isCurrent == true) ? nil : app
    }

    func restore() {
        defer { remembered = nil }
        guard let app = remembered, !app.isTerminated else { return }
        app.activateNow()
    }
}
```

- [ ] **Step 4: Jalankan test dan pastikan lulus**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/FocusRestorerTests 2>&1 | tail -20`
Expected: PASS (5 test).

- [ ] **Step 5: Commit**

```bash
git add DinoPocketMac/Infrastructure/Services/FocusRestorer.swift DinoPocketTests/FocusRestorerTests.swift
git commit -m "$(cat <<'EOF'
feat(c1): kembalikan fokus ke app yang tadi dipakai

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Isi bubble

**Files:**
- Create: `DinoPocketMac/Presentation/QuickAsk/QuickAskBubble.swift`
- Test: tidak ada test unit baru — isinya potongan yang sudah diuji (`QuickAskTurn`,
  `ComposerState`, `MessageRow`). Diverifikasi lewat `#Preview` dan daftar manual Task 11.

**Interfaces:**
- Consumes: `QuickAskTurn` (Task 4), `BubblePlacement.width`/`.answerMaxHeight` (Task 3),
  `ChatStore`, `ReminderListViewModel`, `Composer`, `MessageRow`, `TypingIndicator`.
- Produces: `QuickAskBubble(chat:reminders:onOpenMainWindow:onOpenIntelligenceSettings:onHeightChange:)`.

- [ ] **Step 1: Tulis view-nya**

```swift
//
//  QuickAskBubble.swift
//  Apl
//
//  Isi bubble: satu giliran dan satu kolom tulis (spec C1 §4).
//
//  Tidak ada riwayat di sini dan tidak ada penyimpanan sendiri. Semua yang
//  tampil dipotong dari `ChatStore` yang sama dengan jendela utama, jadi apa
//  pun yang ditanyakan lewat robot langsung ada di percakapan utama.
//

import AppKit
import SwiftUI

struct QuickAskBubble: View {
    let chat: ChatStore
    let reminders: ReminderListViewModel
    let onOpenMainWindow: () -> Void
    let onOpenIntelligenceSettings: () -> Void
    /// Dipanggil setiap kali tinggi isi berubah, supaya panel ikut menyesuaikan.
    let onHeightChange: (CGFloat) -> Void

    @State private var draft = ""
    @State private var availability: BrainAvailability?

    private var turn: QuickAskTurn? { QuickAskTurn.latest(in: chat.messages) }

    private var composerState: ComposerState {
        .current(availability: availability, isStreaming: chat.isStreaming)
    }

    /// Selama potongan pertama belum datang, yang tampil titik-titik.
    private var showsTypingIndicator: Bool {
        chat.isStreaming && (chat.messages.last?.text.isEmpty ?? true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let turn {
                question(turn.question)
                answerArea(turn)
                if !chat.isStreaming, turn.answer != nil {
                    Button("Open in Apl", action: onOpenMainWindow)
                        .buttonStyle(.link)
                        .font(.callout)
                }
            }
            if let availability, availability != .ready {
                unavailableLine
            }
            Composer(draft: $draft, state: composerState,
                     onSend: { send() },
                     onStop: { chat.stopStreaming() })
        }
        .padding(Spacing.md)
        .frame(width: BubblePlacement.width, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
            .strokeBorder(.separator))
        .background(heightReporter)
        .task { availability = await chat.availability() }
        .onChange(of: chat.isStreaming) { was, isStreaming in
            guard was, !isStreaming else { return }
            announceAnswer()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Apl quick ask")
    }

    private func question(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Penanda pembicara, sama seperti di jendela utama: teks tanpa
            // penanda berarti Apl.
            .accessibilityLabel("You said: \(text)")
    }

    @ViewBuilder
    private func answerArea(_ turn: QuickAskTurn) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if let answer = turn.answer, !answer.text.isEmpty || answer.status == .failed {
                    MessageRow(message: answer,
                               reminders: reminders,
                               canRetry: !chat.isStreaming,
                               onRetry: { Task { await chat.retry(answer.id) } })
                } else if showsTypingIndicator {
                    TypingIndicator()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxHeight: BubblePlacement.answerMaxHeight)
    }

    /// Versi satu baris dari `AIUnavailableBanner`: di ruang 360pt, kartu penuh
    /// mendorong composer keluar layar.
    private var unavailableLine: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "apple.intelligence")
                .foregroundStyle(AppColor.statusWarning)
                .accessibilityHidden(true)
            Text("Chat needs Apple Intelligence. Reminders still work.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("Settings", action: onOpenIntelligenceSettings)
                .buttonStyle(.link)
                .font(.caption)
        }
    }

    private var heightReporter: some View {
        GeometryReader { proxy in
            Color.clear
                .onChange(of: proxy.size.height, initial: true) { _, height in
                    onHeightChange(height)
                }
        }
    }

    private func send() {
        let text = draft
        draft = ""
        Task { await chat.send(text) }
    }

    /// Panel `.nonactivatingPanel` tidak mengumumkan apa pun sendiri; tanpa ini
    /// pengguna VoiceOver tidak tahu jawabannya sudah ada (spec C1 §7).
    private func announceAnswer() {
        guard let text = turn?.answer?.text, !text.isEmpty else { return }
        NSAccessibility.post(element: NSApp as Any,
                             notification: .announcementRequested,
                             userInfo: [
                                .announcement: text,
                                .priority: NSAccessibilityPriorityLevel.high.rawValue,
                             ])
    }
}

#Preview("Bubble · Light") {
    QuickAskBubble(chat: .preview(), reminders: .preview(),
                   onOpenMainWindow: {}, onOpenIntelligenceSettings: {},
                   onHeightChange: { _ in })
        .padding(Spacing.xl)
}

#Preview("Bubble · Menjawab · Dark") {
    QuickAskBubble(chat: .preview([ChatMessage(role: .user, text: "What's next today?"),
                                   ChatMessage(role: .assistant, text: "")], isStreaming: true),
                   reminders: .preview(),
                   onOpenMainWindow: {}, onOpenIntelligenceSettings: {},
                   onHeightChange: { _ in })
        .padding(Spacing.xl)
        .preferredColorScheme(.dark)
}

#Preview("Bubble · Kosong · Dark") {
    QuickAskBubble(chat: .preview([]), reminders: .preview(),
                   onOpenMainWindow: {}, onOpenIntelligenceSettings: {},
                   onHeightChange: { _ in })
        .padding(Spacing.xl)
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Build dan buka preview**

Run: `xcodegen generate && xcodebuild build -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' 2>&1 | tail -20`
Expected: BUILD SUCCEEDED.

Buka `QuickAskBubble.swift` di Xcode dan periksa ketiga preview: lebar 360pt, pertanyaan
maksimal dua baris, jawaban panjang bisa digulir tanpa mendorong composer keluar.

- [ ] **Step 3: Commit**

```bash
git add DinoPocketMac/Presentation/QuickAsk/QuickAskBubble.swift
git commit -m "$(cat <<'EOF'
feat(c1): isi bubble — satu giliran dan satu kolom tulis

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Robot menyediakan jangkar, dan berhenti menyapa acak

**Files:**
- Modify: `DinoPocketMac/Infrastructure/Services/AplBuddyWindowController.swift`
- Test: tidak ada test unit (seluruh berkas ini AppKit murni); dipastikan lewat Task 11.

**Interfaces:**
- Consumes: —
- Produces: `AplBuddyWindowController.characterScreenFrame: (rect: CGRect, screen: NSScreen)?`,
  `.pauseStrolling()`, `.resumeStrolling()`, `var onCharacterTap: (() -> Void)?`,
  `BuddyCharacterHost(size:mood:)` (parameter `greeting` hilang).

- [ ] **Step 1: Hapus sapaan acak**

Di `AplBuddyWindowController.swift`, hapus properti `greetingTimer`, `greeting`, konstanta
`private static let greetings`, dan seluruh isi lama `characterTapped()`. Hapus juga
`greetingTimer` dari daftar di `stopBuddyMode()`:

```swift
        [hoverTimer, strollTimer, moodTimer].forEach { $0?.invalidate() }
        hoverTimer = nil; strollTimer = nil; moodTimer = nil
```

Ganti `makeCharacterHost()` dan `characterTapped()`:

```swift
    private func makeCharacterHost() -> BuddyCharacterHost {
        BuddyCharacterHost(size: characterSize, mood: mood)
    }
```

```swift
    /// Klik pada karakter berarti "ajak bicara" (spec C1 §2 #4).
    ///
    /// Kalimat sapaan acak yang dulu muncul di sini dihapus: ia tidak punya
    /// aturan, tidak punya kuota, dan tidak bisa dijawab. Sapaan yang muncul
    /// sendiri adalah urusan C2.
    fileprivate func characterTapped() {
        onCharacterTap?()
    }

    var onCharacterTap: (() -> Void)?
```

Di `startBuddyMode(settings:onDismiss:)`, hapus baris `greeting = nil`.

Di `BuddyCharacterHost`, hapus properti `greeting`, balon `if let greeting { ... }`, dan
`.animation(..., value: greeting)`; sederhanakan `behavior`:

```swift
struct BuddyCharacterHost: View {
    let size: CGFloat
    let mood: SystemMood

    /// Mood mesin dipetakan ke perilaku karakter di sini, bukan di dalam view
    /// aset — pemilihan ekspresi adalah urusan aset, penerjemahan kondisi
    /// sistem adalah urusan buddy.
    ///
    /// `.busy` sengaja dibedakan dari `.normal`: tanpa itu, perbedaan yang
    /// sudah susah payah dihitung `SystemMood.from(thermalState:...)` tidak
    /// pernah sampai ke layar.
    private var behavior: CharacterBehavior {
        switch mood {
        case .hot, .lowBattery: .sleepy
        case .busy:             .thinking
        case .normal:           .idle
        }
    }

    var body: some View {
        USDZCharacterView(size: size, asset: .robot, behavior: behavior)
            .opacity(mood == .hot || mood == .lowBattery ? 0.75 : 1.0)
            .scaleEffect(mood == .hot ? 0.96 : 1.0, anchor: .bottom)
            .animation(.easeInOut(duration: 0.6), value: mood)
            .frame(width: size, height: size)
            .contentShape(Rectangle())
            .onTapGesture {
                AplBuddyWindowController.shared.characterTapped()
            }
    }
}
```

- [ ] **Step 2: Tambahkan jangkar dan penahan langkah**

Setelah `totalScreenFrame()`, tambahkan:

```swift
    /// Frame karakter dalam koordinat layar, beserta layar tempat ia berdiri.
    ///
    /// `nil` selama Buddy Mode mati atau karakter belum dipasang — pemanggil
    /// memakainya untuk memutuskan bahwa tidak ada yang bisa dijangkari.
    var characterScreenFrame: (rect: CGRect, screen: NSScreen)? {
        guard let window, let host = robotHostingView else { return nil }
        let rect = window.convertToScreen(host.frame)
        guard let screen = NSScreen.screens.first(where: { $0.frame.intersects(rect) })
                ?? NSScreen.main else { return nil }
        return (rect, screen)
    }

    /// Robot berhenti melangkah selama bubble terbuka: bubble dijangkari ke
    /// posisinya, dan jangkar yang bergerak 2,4 detik sekali akan menyeret
    /// kolom tulis yang sedang diketik.
    func pauseStrolling() {
        strollTimer?.invalidate()
        strollTimer = nil
    }

    func resumeStrolling() {
        guard isStrolling, strollTimer == nil else { return }
        scheduleNextStroll()
    }
```

- [ ] **Step 3: Build**

Run: `xcodebuild build -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' 2>&1 | tail -20`
Expected: BUILD SUCCEEDED, tanpa peringatan tentang `greeting`.

- [ ] **Step 4: Jalankan seluruh suite**

Run: `xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' 2>&1 | tail -20`
Expected: semua test lulus (tidak ada yang menyentuh `BuddyCharacterHost`).

- [ ] **Step 5: Commit**

```bash
git add DinoPocketMac/Infrastructure/Services/AplBuddyWindowController.swift
git commit -m "$(cat <<'EOF'
feat(c1): robot jadi jangkar bubble, sapaan acak dihapus

Sapaan acak tidak punya aturan dan tidak bisa dijawab. Klik pada robot
sekarang berarti "ajak bicara"; sapaan yang muncul sendiri menunggu C2
beserta kuotanya.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: Panel bubble

**Files:**
- Create: `DinoPocketMac/Presentation/QuickAsk/QuickAskPanelController.swift`
- Test: tidak ada test unit (AppKit murni); dipastikan lewat Task 11.

**Interfaces:**
- Consumes: `QuickAskBubble` (Task 7), `BubblePlacement` (Task 3), `FocusRestorer` (Task 6),
  `AplBuddyWindowController.characterScreenFrame`/`pauseStrolling`/`resumeStrolling` (Task 8).
- Produces: `QuickAskPanelController.shared`, `.configure(_:)`, `.isOpen`,
  `@discardableResult .toggle() -> Bool`, `.open() -> Bool`, `.close()`,
  `QuickAskPanelController.Context(chat:reminders:openMainWindow:openIntelligenceSettings:)`.

- [ ] **Step 1: Tulis controller-nya**

```swift
//
//  QuickAskPanelController.swift
//  Apl
//
//  Panel kecil yang menampung bubble (spec C1 §3–§4).
//
//  `.nonactivatingPanel` + `canBecomeKey` adalah pasangan yang membuat panel
//  bisa diketik tanpa memaksa seluruh app tampil seperti jendela dokumen.
//  `.fullScreenAuxiliary` yang membuatnya muncul di atas app layar penuh —
//  tanpa itu shortcut terasa rusak persis saat orang paling membutuhkannya.
//

import AppKit
import SwiftUI

private final class QuickAskPanel: NSPanel {
    /// Tanpa ini panel borderless tidak pernah jadi key window, dan composer
    /// tidak pernah menerima satu huruf pun.
    override var canBecomeKey: Bool { true }
}

@MainActor
final class QuickAskPanelController: NSObject, NSWindowDelegate {

    static let shared = QuickAskPanelController()

    struct Context {
        let chat: ChatStore
        let reminders: ReminderListViewModel
        let openMainWindow: () -> Void
        let openIntelligenceSettings: () -> Void
    }

    private var context: Context?
    private var panel: QuickAskPanel?
    private var hostingView: NSHostingView<QuickAskBubble>?
    private let focus = FocusRestorer()
    private var escMonitor: Any?
    private var contentHeight: CGFloat = BubblePlacement.maxHeight
    private let buddy: AplBuddyWindowController

    init(buddy: AplBuddyWindowController = .shared) {
        self.buddy = buddy
        super.init()
        NotificationCenter.default.addObserver(
            self, selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    func configure(_ context: Context) {
        self.context = context
    }

    var isOpen: Bool { panel?.isVisible == true }

    /// `false` berarti tidak ada jangkar — robot belum terpasang. Pemanggil
    /// yang memutuskan apa gantinya (jendela utama).
    @discardableResult
    func toggle() -> Bool {
        if isOpen {
            close()
            return true
        }
        return open()
    }

    @discardableResult
    func open() -> Bool {
        guard let context, let anchor = buddy.characterScreenFrame else { return false }

        let panel = self.panel ?? makePanel(context)
        // Fokus dicatat SEBELUM app diaktifkan, kalau tidak yang tercatat Apl.
        focus.remember()
        buddy.pauseStrolling()
        reposition(anchor: anchor)
        startEscMonitoring()

        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        return true
    }

    func close() {
        guard let panel, panel.isVisible else { return }
        stopEscMonitoring()
        panel.orderOut(nil)
        buddy.resumeStrolling()
        focus.restore()
    }

    // MARK: - Panel

    private func makePanel(_ context: Context) -> QuickAskPanel {
        let panel = QuickAskPanel(
            contentRect: CGRect(origin: .zero,
                                size: CGSize(width: BubblePlacement.width,
                                             height: BubblePlacement.maxHeight)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self

        let bubble = QuickAskBubble(
            chat: context.chat,
            reminders: context.reminders,
            onOpenMainWindow: { [weak self] in
                self?.close()
                context.openMainWindow()
            },
            onOpenIntelligenceSettings: context.openIntelligenceSettings,
            onHeightChange: { [weak self] height in
                self?.contentHeight = height
                self?.reposition()
            }
        )
        let host = NSHostingView(rootView: bubble)
        host.sizingOptions = [.intrinsicContentSize]
        panel.contentView = host

        self.panel = panel
        hostingView = host
        return panel
    }

    private func reposition(anchor: (rect: CGRect, screen: NSScreen)? = nil) {
        guard let panel, let anchor = anchor ?? buddy.characterScreenFrame else { return }
        let frame = BubblePlacement.frame(robot: anchor.rect,
                                          screen: anchor.screen.visibleFrame,
                                          contentHeight: contentHeight)
        panel.setFrame(frame, display: true)
    }

    @objc private func screenParametersChanged() {
        guard isOpen else { return }
        reposition()
    }

    // MARK: - Esc

    /// Monitor lokal menerima event sebelum responder chain, jadi Esc di sini
    /// tidak pernah sampai ke `Composer.onKeyPress(.escape)` — hentikan dan
    /// tutup hanya diputuskan di satu tempat.
    ///
    /// Monitor Esc milik Buddy meneruskan event yang ditujukan ke jendela lain,
    /// jadi Esc di bubble tidak mematikan Buddy Mode.
    private func startEscMonitoring() {
        stopEscMonitoring()
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let panel = self.panel,
                  event.keyCode == 53,                  // 53 = Esc
                  event.window === panel else { return event }
            if self.context?.chat.isStreaming == true {
                self.context?.chat.stopStreaming()
            } else {
                self.close()
            }
            return nil
        }
    }

    private func stopEscMonitoring() {
        if let escMonitor { NSEvent.removeMonitor(escMonitor) }
        escMonitor = nil
    }

    // MARK: - NSWindowDelegate

    /// Klik di luar bubble, atau app lain diaktifkan. Jawaban yang sedang
    /// mengalir TIDAK dihentikan — ia tetap ditulis ke ChatStore dan muncul
    /// utuh di jendela utama (spec C1 §6).
    func windowDidResignKey(_ notification: Notification) {
        close()
    }
}
```

- [ ] **Step 2: Build**

Run: `xcodegen generate && xcodebuild build -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' 2>&1 | tail -20`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add DinoPocketMac/Presentation/QuickAsk/QuickAskPanelController.swift
git commit -m "$(cat <<'EOF'
feat(c1): panel bubble yang bisa diketik dan tahu tepi layar

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 10: Memasang semuanya

**Files:**
- Create: `DinoPocketMac/Presentation/Chat/ComposerFocus.swift`
- Modify: `DinoPocketMac/Presentation/Chat/Composer.swift`,
  `DinoPocketMac/Presentation/Chat/ConversationView.swift`,
  `DinoPocketMac/Presentation/Window/MainWindow.swift`,
  `DinoPocketMac/App/AplApp.swift`, `DinoPocketMac/App/AplApp+macOS.swift`,
  `DinoPocketMac/App/AppDependencies.swift`,
  `DinoPocketMac/Presentation/Settings/SettingsWindow.swift`,
  `DinoPocketMac/Presentation/Onboarding/OnboardingView.swift`

**Interfaces:**
- Consumes: semua unit Task 1–9.
- Produces: `ComposerFocus` (`@Observable`, `private(set) var token: Int`, `func request()`),
  `AppDependencies.shortcutSettings`, `AplApp.handleQuickAskShortcut()`.

- [ ] **Step 1: Buat `ComposerFocus` dan sambungkan ke composer**

`DinoPocketMac/Presentation/Chat/ComposerFocus.swift`:

```swift
//
//  ComposerFocus.swift
//  Apl
//
//  Permintaan fokus dari luar view (spec C1 §3, cabang `.focusComposer`).
//
//  Berupa penghitung, bukan Bool: menekan shortcut dua kali saat composer sudah
//  fokus harus tetap terbaca sebagai dua permintaan, dan Bool yang sudah `true`
//  tidak memicu `onChange` yang kedua.
//

import Observation

@MainActor
@Observable
final class ComposerFocus {
    private(set) var token = 0

    func request() {
        token += 1
    }
}
```

Di `Composer.swift`, tambahkan properti dan satu `onChange`:

```swift
struct Composer: View {
    @Binding var draft: String
    let state: ComposerState
    let onSend: () -> Void
    let onStop: () -> Void
    /// `nil` di bubble: di sana composer selalu fokus begitu panel muncul.
    var focus: ComposerFocus?
```

dan, di rangkaian modifier setelah `.task { isFocused = true }`:

```swift
        .onChange(of: focus?.token) { _, _ in
            isFocused = true
        }
```

- [ ] **Step 2: Teruskan lewat ConversationView dan MainWindow**

`ConversationView.swift` — tambahkan properti dan teruskan:

```swift
    let availability: BrainAvailability?
    var showsDateHeader = true
    let composerFocus: ComposerFocus
    let onOpenIntelligenceSettings: () -> Void
```

```swift
                Composer(draft: $draft, state: composerState,
                         onSend: { send() },
                         onStop: { chat.stopStreaming() },
                         focus: composerFocus)
```

Perbarui ketiga `#Preview` di berkas itu dengan `composerFocus: ComposerFocus()`.

`MainWindow.swift` — tambahkan `let composerFocus: ComposerFocus` di bawah `onToggleBuddy`,
teruskan ke `ConversationView(...)`, dan perbarui ketiga `#Preview` dengan
`composerFocus: ComposerFocus()`.

- [ ] **Step 3: Tambahkan store baru ke `AppDependencies`**

Di `AppDependencies`, tambahkan properti `let shortcutSettings = ShortcutSettingsStore()`
(mengikuti pola `buddySettings`), dan masukkan ke daftar `erasableStores` bila daftar itu
disusun di sana. Bila `erasableStores` tidak memuatnya, ia ditambahkan langsung di
`AplApp.eraseAllData()` pada langkah berikutnya.

- [ ] **Step 4: Pasang shortcut, router, dan panel di `AplApp`**

Di `AplApp.swift`, tambahkan state:

```swift
    @State private var shortcutSettings = deps.shortcutSettings
    @State private var composerFocus = ComposerFocus()
    @State private var shortcut = QuickAskShortcut()
```

Teruskan `composerFocus` ke `MainWindow(...)`, dan masukkan `shortcutSettings` ke
`eraseAllData()`:

```swift
        let stores: [any LocallyErasable] = [profile, chat, buddySettings, shortcutSettings]
            + Self.deps.erasableStores
```

Di `mainWindow`, tambahkan pemasangan — satu `.task` baru, di samping `.task` Buddy Mode
yang sudah ada:

```swift
        .task {
            QuickAskPanelController.shared.configure(
                .init(chat: chat,
                      reminders: reminders,
                      openMainWindow: { bringMainWindowForward() },
                      openIntelligenceSettings: { _ = Self.deps.appLauncher.open(.appleIntelligence) })
            )
            AplBuddyWindowController.shared.onCharacterTap = { handleQuickAskShortcut() }
            shortcutSettings.onChange = { preset in
                shortcutSettings.registrationFailed =
                    !shortcut.apply(preset, handler: { handleQuickAskShortcut() })
            }
            shortcutSettings.registrationFailed =
                !shortcut.apply(shortcutSettings.preset, handler: { handleQuickAskShortcut() })
        }
```

- [ ] **Step 5: Tulis tindakan shortcut di `AplApp+macOS.swift`**

```swift
import AppKit

extension AplApp {
    func toggleBuddyMode() {
        isBuddyMode.toggle()
    }

    func dismissFromBuddy() {
        AplBuddyWindowController.shared.stopBuddyMode()
        isBuddyMode = false
    }

    /// Satu tombol, tiga arti (spec C1 §3). Keputusannya milik `QuickAskRouter`;
    /// di sini hanya pelaksanaannya.
    func handleQuickAskShortcut() {
        let action = QuickAskRouter.action(mainWindowIsFrontmost: Self.mainWindowIsFrontmost,
                                           buddyIsRunning: isBuddyMode)
        switch action {
        case .focusComposer:
            focusMainWindowComposer()
        case .toggleBubble:
            // Robot hidup tapi belum punya frame: lebih baik membuka jendela
            // daripada tidak terjadi apa-apa.
            if !QuickAskPanelController.shared.toggle() {
                bringMainWindowForward()
            }
        case .openMainWindow:
            bringMainWindowForward()
        }
    }

    func bringMainWindowForward() {
        NSApp.activate()
        Self.mainWindow?.makeKeyAndOrderFront(nil)
        focusMainWindowComposer()
    }

    private func focusMainWindowComposer() {
        composerFocus.request()
    }

    /// Jendela utama adalah satu-satunya jendela biasa app ini: panel Buddy dan
    /// panel bubble keduanya `NSPanel`, dan Settings punya kelas sendiri.
    static var mainWindow: NSWindow? {
        NSApp.windows.first { $0.isVisible && !($0 is NSPanel) && $0.canBecomeMain }
    }

    static var mainWindowIsFrontmost: Bool {
        NSApp.isActive && NSApp.keyWindow != nil && NSApp.keyWindow === mainWindow
    }
}
```

Catatan untuk pelaksana: `composerFocus` dan `isBuddyMode` adalah `@State` di `AplApp`,
jadi keduanya harus `internal` (tanpa `private`) agar extension ini melihatnya — sama
seperti `isBuddyMode` hari ini.

- [ ] **Step 6: Tambahkan baris shortcut di Settings**

Di `GeneralSettingsTab`, tambahkan properti `@Bindable var shortcutSettings: ShortcutSettingsStore`
dan satu section baru setelah section Launch at login:

```swift
            Section {
                Picker("Quick ask", selection: $shortcutSettings.preset) {
                    ForEach(ShortcutPreset.allCases, id: \.self) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                if shortcutSettings.registrationFailed {
                    // Kombinasi yang sudah dipegang app lain tidak pernah sampai
                    // ke Apl. Diam di sini berarti pengguna menyalahkan Apl.
                    Text("\(shortcutSettings.preset.displayName) is taken by another app — try another one.")
                        .font(.footnote)
                        .foregroundStyle(AppColor.statusWarning)
                }
            } footer: {
                Text("Press it from any app to ask Apl without leaving what you're doing.")
            }
```

Teruskan store-nya dari `SettingsWindow`: tambahkan `let shortcutSettings: ShortcutSettingsStore`
di `SettingsWindow`, berikan ke `GeneralSettingsTab(profile:launchAtLogin:shortcutSettings:)`,
perbarui kedua `#Preview` dengan
`ShortcutSettingsStore(defaults: UserDefaults(suiteName: "apl.preview.shortcut")!)`, dan
perbarui pemanggilan di `AplApp.swift`:

```swift
        Settings {
            SettingsWindow(profile: profile,
                           buddySettings: buddySettings,
                           shortcutSettings: shortcutSettings,
                           launchAtLogin: Self.deps.launchAtLogin,
                           eraseAllData: { await eraseAllData() })
        }
```

- [ ] **Step 7: Sebutkan tombolnya di onboarding**

Di `OnboardingView`, tambahkan `let shortcutPreset: ShortcutPreset` (diisi
`Self.deps.shortcutSettings.preset` dari `AplApp.rootView`) dan satu kalimat di langkah
`.intelligence`, tepat setelah baris "Reminders and your character work without it.":

```swift
                if shortcutPreset != .off {
                    Text("Press \(shortcutPreset.displayName) from any app to ask Apl anything.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
```

- [ ] **Step 8: Build dan jalankan seluruh suite**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' 2>&1 | tail -30`
Expected: seluruh suite lulus (154 test lama + 39 test baru).

- [ ] **Step 9: Jalankan pemeriksa batas dan rilis**

Run: `./scripts/verify-boundaries.sh && ./scripts/verify-release.sh`
Expected: keduanya hijau.

- [ ] **Step 10: Commit**

```bash
git add DinoPocketMac/Presentation/Chat/ComposerFocus.swift DinoPocketMac/Presentation/Chat/Composer.swift DinoPocketMac/Presentation/Chat/ConversationView.swift DinoPocketMac/Presentation/Window/MainWindow.swift DinoPocketMac/App/AplApp.swift DinoPocketMac/App/AplApp+macOS.swift DinoPocketMac/App/AppDependencies.swift DinoPocketMac/Presentation/Settings/SettingsWindow.swift DinoPocketMac/Presentation/Onboarding/OnboardingView.swift
git commit -m "$(cat <<'EOF'
feat(c1): pasang shortcut, router, dan bubble ke dalam app

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 11: Verifikasi manual dan catatan

**Files:**
- Modify: `docs/superpowers/specs/2026-09-19-apl-quick-ask-design.md` (§10 DoD, §13 baru)
- Modify: `docs/superpowers/plans/2026-09-19-apl-quick-ask.md` (Catatan eksekusi)

**Interfaces:**
- Consumes: app yang sudah terpasang seluruh Task 1–10.
- Produces: catatan temuan; perbaikan apa pun dari daftar ini di-commit terpisah.

- [ ] **Step 1: Jalankan app**

Run: `./scripts/apl-launch.sh` (alat dari sub-project B; kalau belum ada, bangun dengan
`xcodebuild build` lalu buka `Apl.app` dari `DerivedData`).

- [ ] **Step 2: Kerjakan daftar periksa spec §9**

Catat hasil tiap baris (lulus / gagal / tidak bisa diuji), TANPA mengubah pengaturan sistem
pengguna dan tanpa menekan dialog izin atas nama mereka:

1. ⌥Space dari Finder → bubble muncul di samping robot, langsung bisa diketik.
2. ⌥Space saat Xcode layar penuh → bubble tetap terlihat. **Catat juga apakah robotnya
   sendiri terlihat**; kalau tidak, itu temuan untuk dicatat, bukan diperbaiki diam-diam.
3. Ketik lalu Return → jawaban tumbuh; Esc menghentikan; Esc lagi menutup; app yang tadi di
   depan kembali aktif.
4. "Open in Apl" → jendela utama ke depan, giliran itu ada di percakapan.
5. Hide Buddy lalu ⌥Space → jendela utama ke depan, composer fokus, tidak ada bubble.
6. Jendela utama sudah di depan lalu ⌥Space → composer fokus, tidak ada bubble.
7. Dua monitor (bila ada): bubble di layar yang sama dengan robot.
8. Preset Off → ⌥Space tidak melakukan apa pun; preset ⌥⌘A → jalan.
9. Klik robot → bubble terbuka siap diketik, tidak ada kalimat sapaan acak.

Regresi B: Esc di jendela utama masih menghentikan jawaban tanpa mematikan Buddy, dan
⇧Return masih menyisipkan baris baru di kedua composer.

- [ ] **Step 3: Perbaiki temuan, satu commit per temuan**

Tiap perbaikan: test dulu bila cacatnya bisa diuji unit, lalu perbaikan, lalu commit
tersendiri dengan penjelasan mengapa test tidak menangkapnya.

- [ ] **Step 4: Tulis hasilnya**

Tambahkan bagian "Catatan eksekusi" di akhir plan ini: tabel temuan → commit. Tandai
kotak-kotak di spec §10 yang sudah terbukti, dan tambahkan §13 "Penyesuaian saat
perencanaan dan pelaksanaan" di spec bila ada yang berubah dari rancangan.

Item VoiceOver di §10 ditinggalkan untuk pemilik produk: menyalakan VoiceOver adalah
pengaturan sistem, dan itu bukan milik saya untuk diubah.

- [ ] **Step 5: Commit catatan**

```bash
git add docs/superpowers/specs/2026-09-19-apl-quick-ask-design.md docs/superpowers/plans/2026-09-19-apl-quick-ask.md
git commit -m "$(cat <<'EOF'
docs(c1): catat hasil verifikasi manual

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Penyesuaian terhadap spec yang ditemukan saat menulis plan

1. **Reminder memakai `ReminderChip` yang sudah ada**, bukan baris konfirmasi tersendiri.
   Spec §4 menulis "bukan chip penuh"; setelah membaca `ReminderChip.swift`, chip itu
   ternyata sudah berupa satu kapsul satu baris dengan Undo — persis yang dimaksud. Menulis
   versi kedua hanya akan membuat dua tempat yang bisa berbeda. Bubble memakai `MessageRow`,
   yang memilih chip itu sendiri dari lampiran pesan.
2. **`BubblePlacement` punya dua batas tinggi**, bukan satu: `answerMaxHeight` (200pt)
   membatasi area jawaban di dalam SwiftUI, `maxHeight` (280pt) menjepit seluruh panel
   sebagai jaring pengaman. Tanpa batas dalam, `NSHostingView` meminta tinggi sebesar
   isinya dan penjepitan di luar akan memotong composer, bukan jawabannya.
3. **Esc ditangani satu tempat**, di monitor lokal milik panel. Monitor lokal menerima event
   sebelum responder chain, jadi `Composer.onKeyPress(.escape)` tidak pernah melihatnya di
   dalam bubble — menambah penanganan kedua di sana hanya akan jadi kode mati.
4. **Monitor Esc milik Buddy tidak perlu diubah.** Ia sudah meneruskan event yang
   `event.window`-nya bukan jendela Buddy, dan panel bubble adalah jendela lain.

## Self-review

**Cakupan spec:** §2 keputusan 1–7 → Task 1 (#3, #5), Task 4 (#1, #2), Task 7 (#1, #2),
Task 8 (#4), Task 9 (#6), Task 10 (#7, penghapusan kunci saat Erase All Data). §3 arsitektur
→ Task 1–9, satu unit per task. §4 perilaku → Task 7 (isi, Markdown, reminder, AI mati) dan
Task 9 (penempatan, Esc, buka/tutup, fokus). §5 shortcut dan Settings → Task 1, 5, 10. §6
keadaan pinggir → Task 9 (layar berubah, resign key, tanpa jangkar) dan Task 10 (Buddy mati,
Erase All Data lewat daftar store). §7 aksesibilitas → Task 7 (label, pengumuman) — Reduce
Motion tidak butuh kode baru karena bubble tidak menganimasikan kemunculannya. §8 privasi →
Task 1 (`eraseAllStoredData`) dan Task 10 (daftar store). §9 pengujian → test di Task 1–6,
daftar manual di Task 11. §10 DoD → Task 11.

**Placeholder:** tidak ada langkah tanpa kode; semua nama berkas absolut; semua perintah
bisa dijalankan apa adanya.

**Konsistensi tipe:** `ShortcutPreset` dipakai Task 1, 5, 10 dengan `keyCode: UInt32?` dan
`modifiers: UInt32` yang sama. `QuickAskTurn.latest(in:)` dipanggil Task 7 persis seperti
didefinisikan Task 4. `BubblePlacement.frame(robot:screen:contentHeight:)` dipanggil Task 9
dengan `anchor.screen.visibleFrame`, sesuai parameter `screen` yang didokumentasikan Task 3.
`HotKeyRegistering.register` mengembalikan `Bool` di Task 5 dan dibaca sebagai `Bool` di
Task 10. `QuickAskPanelController.toggle()` mengembalikan `Bool` di Task 9 dan dicek di
Task 10.

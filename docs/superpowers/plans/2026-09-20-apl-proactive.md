# Apl C2 — Apl yang Memulai Bicara — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apl menyapa lebih dulu lewat balon di robot — hanya untuk reminder yang sebentar
lagi berbunyi dan keadaan mesin, dengan kuota, peredam, dan suara opsional.

**Architecture:** Satu fungsi murni (`NudgeRules`) memegang seluruh keputusan dan diuji
habis-habisan tanpa app. Di sekelilingnya: catatan kuota di `UserDefaults`, pembaca sinyal
peredam, panel pasif yang secara struktural tidak bisa merebut fokus, dan pembaca suara.

**Tech Stack:** Swift 6, SwiftUI, AppKit (`NSPanel`, `CGWindowList`), AVFoundation
(`AVSpeechSynthesizer`), Swift Testing, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-09-20-apl-proactive-design.md`

## Global Constraints

- Target **macOS 26+**, distribusi **Mac App Store**. **`DinoPocket.entitlements` tidak
  boleh berubah sama sekali** — tidak ada izin sistem baru (spec §2 #2, §8).
- `SWIFT_VERSION: 6.0`; semua tipe UI `@MainActor`.
- **XcodeGen**: jalankan `xcodegen generate` setelah menambah berkas.
- Test host `Apl.app`: setiap test yang menyentuh `UserDefaults` WAJIB memakai suite
  terisolasi.
- Setiap penulisan preferensi diikuti `defaults.synchronize()`.
- `SharedCore` tidak boleh mengimpor SwiftUI/AppKit/UIKit. Semua berkas C2 di
  `DinoPocketMac`.
- Teks antarmuka **Inggris**, komentar dan dokumen **Indonesia**.
- Setiap commit diakhiri `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.
- **Jangan** mengubah pengaturan sistem macOS milik pengguna.

## File Structure

**Dibuat** (semuanya di `DinoPocketMac/Presentation/Nudge/` kecuali disebut lain):
`Nudge.swift`, `NudgeText.swift`, `QuietSignals.swift`, `NudgeRules.swift`,
`NudgeBalloon.swift`, `NudgePanelController.swift`, `NudgeScheduler.swift`;
`DinoPocketMac/Infrastructure/Persistence/NudgeHistory.swift`;
`DinoPocketMac/Infrastructure/Services/NudgeSpeaker.swift`,
`DinoPocketMac/Infrastructure/Services/QuietSignalReader.swift`.

**Diubah:** `BubblePlacement.swift` (digeneralisasi menerima ukuran),
`BuddySettingsStore.swift` (toggle suara), `SettingsWindow.swift` (barisnya),
`AplApp.swift` (pemasangan), `AppDependencies.swift` (store baru).

**Test:** `NudgeTests.swift`, `NudgeTextTests.swift`, `NudgeRulesTests.swift`,
`NudgeHistoryTests.swift`, dan tambahan di `BubblePlacementTests.swift`.

---

### Task 1: Apa yang hendak dikatakan

**Files:**
- Create: `DinoPocketMac/Presentation/Nudge/Nudge.swift`,
  `DinoPocketMac/Presentation/Nudge/NudgeText.swift`
- Test: `DinoPocketTests/NudgeTests.swift`, `DinoPocketTests/NudgeTextTests.swift`

**Interfaces:**
- Consumes: `Reminder`, `SystemMood`.
- Produces: `Nudge` (`kind`, `text`, `key`, `isMachine`), `Nudge.Kind`
  (`.reminderSoon(Reminder.ID, at: Date)`, `.machine(SystemMood)`),
  `NudgeText.reminderSoon(title:at:)`, `NudgeText.machine(_:) -> String?`.

- [ ] **Step 1: Tulis test yang gagal**

`DinoPocketTests/NudgeTests.swift`:

```swift
import Foundation
import Testing
@testable import Apl

struct NudgeTests {

    /// Kunci kuota memuat WAKTU kemunculan, bukan hanya id: reminder harian
    /// punya kejadian berbeda tiap hari dan masing-masing boleh disapa sekali.
    @Test func reminderKeyIncludesTheOccurrence() {
        let id = UUID()
        let monday = Date(timeIntervalSince1970: 1_000_000)
        let tuesday = monday.addingTimeInterval(86_400)
        let first = Nudge(kind: .reminderSoon(id, at: monday), text: "x")
        let second = Nudge(kind: .reminderSoon(id, at: tuesday), text: "x")
        #expect(first.key != second.key)
    }

    @Test func sameOccurrenceHasTheSameKey() {
        let id = UUID()
        let at = Date(timeIntervalSince1970: 1_000_000)
        #expect(Nudge(kind: .reminderSoon(id, at: at), text: "a").key
                == Nudge(kind: .reminderSoon(id, at: at), text: "b").key)
    }

    @Test func machineNudgesAreMarkedAsSuch() {
        #expect(Nudge(kind: .machine(.hot), text: "x").isMachine)
        #expect(!Nudge(kind: .reminderSoon(UUID(), at: .now), text: "x").isMachine)
    }
}
```

`DinoPocketTests/NudgeTextTests.swift`:

```swift
import Foundation
import Testing
@testable import Apl

struct NudgeTextTests {

    /// Kalimatnya pasti, bukan acak: sapaan acak dihapus di C1 justru karena
    /// tidak punya aturan.
    @Test func reminderShowsTitleAndTime() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Jakarta")!
        let at = calendar.date(from: DateComponents(year: 2026, month: 9, day: 20,
                                                    hour: 15, minute: 0))!
        let text = NudgeText.reminderSoon(title: "Stretch", at: at,
                                          locale: Locale(identifier: "en_US"),
                                          timeZone: calendar.timeZone)
        #expect(text.hasPrefix("Stretch · "))
        #expect(text.contains("3:00"))
    }

    @Test func machineSpeaksOnlyWhenSomethingIsWrong() {
        #expect(NudgeText.machine(.hot) != nil)
        #expect(NudgeText.machine(.lowBattery) != nil)
        #expect(NudgeText.machine(.normal) == nil)
        #expect(NudgeText.machine(.busy) == nil)
    }

    @Test func machineSentencesDiffer() {
        #expect(NudgeText.machine(.hot) != NudgeText.machine(.lowBattery))
    }
}
```

- [ ] **Step 2: Jalankan dan pastikan gagal**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/NudgeTests 2>&1 | grep -E "error:" | head -3`
Expected: `cannot find 'Nudge' in scope`.

- [ ] **Step 3: Tulis `Nudge`**

```swift
//
//  Nudge.swift
//  Apl
//
//  Apa yang hendak dikatakan Apl tanpa diminta (spec C2 §3).
//

import Foundation

struct Nudge: Equatable {

    enum Kind: Equatable {
        /// Reminder yang sebentar lagi berbunyi, beserta waktu kemunculannya.
        case reminderSoon(Reminder.ID, at: Date)
        case machine(SystemMood)
    }

    let kind: Kind
    let text: String

    /// Kunci kuota: satu kejadian hanya boleh disapa sekali.
    ///
    /// Waktu kemunculan ikut masuk kunci — tanpa itu, reminder harian hanya
    /// akan disapa sekali seumur hidupnya.
    var key: String {
        switch kind {
        case .reminderSoon(let id, let at):
            "reminder.\(id.uuidString).\(Int(at.timeIntervalSince1970))"
        case .machine(let mood):
            "machine.\(mood.rawValue)"
        }
    }

    var isMachine: Bool {
        if case .machine = kind { return true }
        return false
    }

    /// Waktu kemunculan untuk balon reminder; dipakai memangkas catatan lama.
    var occurrence: Date? {
        if case .reminderSoon(_, let at) = kind { return at }
        return nil
    }
}
```

- [ ] **Step 4: Tulis `NudgeText`**

```swift
//
//  NudgeText.swift
//  Apl
//
//  Kalimat balon (spec C2 §5). Pasti, bukan acak.
//

import Foundation

enum NudgeText {

    static func reminderSoon(title: String, at date: Date,
                             locale: Locale = .current,
                             timeZone: TimeZone = .current) -> String {
        var format = Date.FormatStyle(date: .omitted, time: .shortened)
        format.locale = locale
        format.timeZone = timeZone
        return "\(title) · \(date.formatted(format))"
    }

    /// `nil` berarti tidak ada yang perlu dikatakan tentang keadaan mesin.
    static func machine(_ mood: SystemMood) -> String? {
        switch mood {
        case .hot: "This Mac is running hot."
        case .lowBattery: "Battery is getting low."
        case .normal, .busy: nil
        }
    }
}
```

- [ ] **Step 5: Jalankan dan pastikan lulus**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/NudgeTests -only-testing:DinoPocketTests/NudgeTextTests 2>&1 | grep -E "Test run with|TEST"`
Expected: PASS (6 test).

- [ ] **Step 6: Commit**

```bash
git add DinoPocketMac/Presentation/Nudge/Nudge.swift DinoPocketMac/Presentation/Nudge/NudgeText.swift DinoPocketTests/NudgeTests.swift DinoPocketTests/NudgeTextTests.swift
git commit -m "$(cat <<'EOF'
feat(c2): apa yang hendak dikatakan, beserta kunci kuotanya

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Catatan kuota

**Files:**
- Create: `DinoPocketMac/Infrastructure/Persistence/NudgeHistory.swift`
- Test: `DinoPocketTests/NudgeHistoryTests.swift`

**Interfaces:**
- Consumes: `Nudge` (Task 1).
- Produces: `NudgeHistory` (`init(defaults:)`, `static let key`, `var snapshot: Snapshot`,
  `record(_:at:)`, `markIgnored(at:)`, `prune(now:calendar:)`, `eraseAllStoredData()`),
  `NudgeHistory.Snapshot` (`shownReminderKeys: [String: Date]`, `lastMachineAt: Date?`,
  `machineCountToday: Int`, `machineDay: Date?`, `lastIgnoredAt: Date?`).

- [ ] **Step 1: Tulis test yang gagal**

```swift
import Foundation
import Testing
@testable import Apl

@MainActor
struct NudgeHistoryTests {

    private func isolatedDefaults(_ name: String) -> UserDefaults {
        let suite = "test.nudge.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func reminderNudgesAreRememberedByOccurrence() {
        let history = NudgeHistory(defaults: isolatedDefaults(#function))
        let at = now.addingTimeInterval(300)
        history.record(Nudge(kind: .reminderSoon(UUID(), at: at), text: "x"), at: now)
        #expect(history.snapshot.shownReminderKeys.count == 1)
    }

    @Test func machineNudgesCountTowardTheDay() {
        let history = NudgeHistory(defaults: isolatedDefaults(#function))
        history.record(Nudge(kind: .machine(.hot), text: "x"), at: now)
        #expect(history.snapshot.machineCountToday == 1)
        #expect(history.snapshot.lastMachineAt == now)
    }

    @Test func survivesRelaunch() {
        let defaults = isolatedDefaults(#function)
        NudgeHistory(defaults: defaults).record(Nudge(kind: .machine(.hot), text: "x"), at: now)
        #expect(NudgeHistory(defaults: defaults).snapshot.machineCountToday == 1)
    }

    /// Hitungan harian berganti hari; catatan reminder lama dibuang supaya
    /// kunci tidak menumpuk selamanya.
    @Test func pruningResetsTheDayAndDropsOldKeys() {
        let history = NudgeHistory(defaults: isolatedDefaults(#function))
        history.record(Nudge(kind: .machine(.hot), text: "x"), at: now)
        history.record(Nudge(kind: .reminderSoon(UUID(), at: now), text: "x"), at: now)

        history.prune(now: now.addingTimeInterval(86_400))
        #expect(history.snapshot.machineCountToday == 0)
        #expect(history.snapshot.shownReminderKeys.isEmpty)
    }

    /// Kejadian yang BELUM lewat tidak boleh dibuang, walau harinya berganti:
    /// kalau dibuang, reminder yang sama disapa dua kali.
    @Test func pruningKeepsOccurrencesThatHaveNotHappenedYet() {
        let history = NudgeHistory(defaults: isolatedDefaults(#function))
        let soon = now.addingTimeInterval(120)
        history.record(Nudge(kind: .reminderSoon(UUID(), at: soon), text: "x"), at: now)
        history.prune(now: now.addingTimeInterval(60))
        #expect(history.snapshot.shownReminderKeys.count == 1)
    }

    @Test func ignoringIsRemembered() {
        let history = NudgeHistory(defaults: isolatedDefaults(#function))
        history.markIgnored(at: now)
        #expect(history.snapshot.lastIgnoredAt == now)
    }

    @Test func eraseLeavesNoKeyBehind() {
        let defaults = isolatedDefaults(#function)
        let history = NudgeHistory(defaults: defaults)
        history.record(Nudge(kind: .machine(.hot), text: "x"), at: now)
        history.eraseAllStoredData()
        #expect(defaults.data(forKey: NudgeHistory.key) == nil)
        #expect(history.snapshot.machineCountToday == 0)
    }
}
```

- [ ] **Step 2: Jalankan dan pastikan gagal**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/NudgeHistoryTests 2>&1 | grep -E "error:" | head -3`
Expected: `cannot find 'NudgeHistory' in scope`.

- [ ] **Step 3: Tulis implementasinya**

```swift
//
//  NudgeHistory.swift
//  Apl
//
//  Apa yang sudah dikatakan dan kapan (spec C2 §4).
//
//  Dicatat SEBELUM balon tampil: kalau app berhenti di tengah, kuota tetap
//  terpakai. Satu sapaan yang hilang lebih baik daripada sapaan yang sama
//  muncul lagi setiap kali app dibuka.
//

import Foundation
import Observation

@MainActor
@Observable
final class NudgeHistory {

    nonisolated static let key = "nudge.history"

    struct Snapshot: Codable, Equatable {
        /// Kunci kejadian reminder yang sudah disapa → waktu kemunculannya.
        var shownReminderKeys: [String: Date] = [:]
        var lastMachineAt: Date?
        var machineCountToday = 0
        /// Hari yang sedang dihitung `machineCountToday`.
        var machineDay: Date?
        /// Balon terakhir yang lewat tanpa diklik.
        var lastIgnoredAt: Date?
    }

    private(set) var snapshot: Snapshot
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let restored = try? JSONDecoder().decode(Snapshot.self, from: data) {
            snapshot = restored
        } else {
            snapshot = Snapshot()
        }
    }

    func record(_ nudge: Nudge, at now: Date, calendar: Calendar = .current) {
        if let occurrence = nudge.occurrence {
            snapshot.shownReminderKeys[nudge.key] = occurrence
        }
        if nudge.isMachine {
            rollOverIfNeeded(now: now, calendar: calendar)
            snapshot.machineCountToday += 1
            snapshot.lastMachineAt = now
            snapshot.machineDay = calendar.startOfDay(for: now)
        }
        save()
    }

    func markIgnored(at now: Date) {
        snapshot.lastIgnoredAt = now
        save()
    }

    /// Dipanggil tiap detak sebelum aturan ditanya.
    func prune(now: Date, calendar: Calendar = .current) {
        rollOverIfNeeded(now: now, calendar: calendar)
        // Kejadian yang belum lewat TIDAK dibuang: kalau dibuang, reminder yang
        // sama akan disapa lagi beberapa menit kemudian.
        snapshot.shownReminderKeys = snapshot.shownReminderKeys.filter { $0.value > now }
        save()
    }

    private func rollOverIfNeeded(now: Date, calendar: Calendar) {
        let today = calendar.startOfDay(for: now)
        guard snapshot.machineDay != today else { return }
        snapshot.machineCountToday = 0
        snapshot.machineDay = today
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Self.key)
        // Dipaksa turun ke disk; lihat catatan di `ProfileStore`.
        defaults.synchronize()
    }
}

extension NudgeHistory: LocallyErasable {
    func eraseAllStoredData() {
        snapshot = Snapshot()
        defaults.removeObject(forKey: Self.key)
        defaults.synchronize()
    }
}
```

- [ ] **Step 4: Jalankan dan pastikan lulus**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/NudgeHistoryTests 2>&1 | grep -E "Test run with|TEST"`
Expected: PASS (7 test).

- [ ] **Step 5: Commit**

```bash
git add DinoPocketMac/Infrastructure/Persistence/NudgeHistory.swift DinoPocketTests/NudgeHistoryTests.swift
git commit -m "$(cat <<'EOF'
feat(c2): catatan kuota yang bertahan lintas peluncuran

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Seluruh keputusan, dalam satu fungsi murni

**Files:**
- Create: `DinoPocketMac/Presentation/Nudge/QuietSignals.swift`,
  `DinoPocketMac/Presentation/Nudge/NudgeRules.swift`
- Test: `DinoPocketTests/NudgeRulesTests.swift`

**Interfaces:**
- Consumes: `Nudge`, `NudgeText` (Task 1), `NudgeHistory.Snapshot` (Task 2), `Reminder`,
  `SystemMood`.
- Produces: `QuietSignals` (enam bendera + `allowsSpeaking`), `NudgeRules.next(...)`,
  konstanta `reminderLead`, `moodMustPersist`, `machineCooldown`, `machinePerDay`,
  `ignoredBackoff`.

- [ ] **Step 1: Tulis test yang gagal**

```swift
import Foundation
import Testing
@testable import Apl

struct NudgeRulesTests {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func reminder(in seconds: TimeInterval, title: String = "Stretch") -> Reminder {
        Reminder(title: title, rule: .once(now.addingTimeInterval(seconds)))
    }

    private var loud: QuietSignals { QuietSignals() }

    private func next(reminders: [Reminder] = [],
                      mood: SystemMood = .normal,
                      moodSince: Date? = nil,
                      history: NudgeHistory.Snapshot = .init(),
                      signals: QuietSignals? = nil) -> Nudge? {
        NudgeRules.next(now: now, reminders: reminders, mood: mood, moodSince: moodSince,
                        history: history, signals: signals ?? loud)
    }

    // MARK: - Reminder

    @Test func reminderWithinTheLeadWindowIsAnnounced() {
        let nudge = next(reminders: [reminder(in: 4 * 60)])
        #expect(nudge?.isMachine == false)
        #expect(nudge?.text.hasPrefix("Stretch") == true)
    }

    @Test func reminderFurtherOutIsNotAnnouncedYet() {
        #expect(next(reminders: [reminder(in: 20 * 60)]) == nil)
    }

    /// Yang sudah lewat tidak disapa: notifikasinya sudah berbunyi.
    @Test func reminderThatAlreadyPassedIsSilent() {
        #expect(next(reminders: [reminder(in: -60)]) == nil)
    }

    @Test func theSoonestReminderWins() {
        let nudge = next(reminders: [reminder(in: 280, title: "Later"),
                                     reminder(in: 60, title: "Sooner")])
        #expect(nudge?.text.hasPrefix("Sooner") == true)
    }

    @Test func anOccurrenceIsAnnouncedOnlyOnce() {
        let item = reminder(in: 120)
        var history = NudgeHistory.Snapshot()
        let announced = next(reminders: [item])!
        history.shownReminderKeys[announced.key] = now.addingTimeInterval(120)
        #expect(next(reminders: [item], history: history) == nil)
    }

    /// Kuota harian tidak berlaku untuk reminder: pengguna sendiri yang
    /// memintanya dengan membuat reminder itu.
    @Test func remindersIgnoreTheDailyQuota() {
        var history = NudgeHistory.Snapshot()
        history.machineCountToday = 99
        history.lastMachineAt = now.addingTimeInterval(-60)
        #expect(next(reminders: [reminder(in: 120)], history: history) != nil)
    }

    // MARK: - Mesin

    @Test func machineNudgeNeedsThePoorStateToPersist() {
        #expect(next(mood: .hot, moodSince: now.addingTimeInterval(-60)) == nil)
        #expect(next(mood: .hot, moodSince: now.addingTimeInterval(-11 * 60)) != nil)
    }

    @Test func normalMachineStateSaysNothing() {
        #expect(next(mood: .normal, moodSince: now.addingTimeInterval(-3600)) == nil)
        #expect(next(mood: .busy, moodSince: now.addingTimeInterval(-3600)) == nil)
    }

    @Test func machineNudgesWaitFourHours() {
        var history = NudgeHistory.Snapshot()
        history.lastMachineAt = now.addingTimeInterval(-3600)
        history.machineDay = Calendar.current.startOfDay(for: now)
        history.machineCountToday = 1
        #expect(next(mood: .hot, moodSince: now.addingTimeInterval(-3600), history: history) == nil)
    }

    @Test func machineNudgesStopAtTwoPerDay() {
        var history = NudgeHistory.Snapshot()
        history.lastMachineAt = now.addingTimeInterval(-5 * 3600)
        history.machineDay = Calendar.current.startOfDay(for: now)
        history.machineCountToday = 2
        #expect(next(mood: .hot, moodSince: now.addingTimeInterval(-3600), history: history) == nil)
    }

    /// Balon yang diabaikan membuat balon mesin mundur satu jam — tapi tidak
    /// menahan reminder, yang memang diminta.
    @Test func ignoredBalloonBacksOffMachineNudgesOnly() {
        var history = NudgeHistory.Snapshot()
        history.lastIgnoredAt = now.addingTimeInterval(-600)
        #expect(next(mood: .hot, moodSince: now.addingTimeInterval(-3600), history: history) == nil)
        #expect(next(reminders: [reminder(in: 120)], history: history) != nil)
    }

    // MARK: - Peredam

    @Test func everyQuietSignalSilencesOnItsOwn() {
        var cases: [QuietSignals] = []
        for mutate in [{ (s: inout QuietSignals) in s.otherAppIsFullScreen = true },
                       { $0.screenIsAsleepOrLocked = true },
                       { $0.aplIsFrontmost = true },
                       { $0.quickAskIsOpen = true },
                       { $0.buddyIsRunning = false },
                       { $0.aNudgeIsOnScreen = true }] {
            var signals = QuietSignals()
            mutate(&signals)
            cases.append(signals)
        }
        for signals in cases {
            #expect(next(reminders: [reminder(in: 120)], signals: signals) == nil)
            #expect(signals.allowsSpeaking == false)
        }
    }

    @Test func defaultSignalsAllowSpeaking() {
        #expect(QuietSignals().allowsSpeaking)
    }

    /// Reminder didahulukan: ia punya waktu, keadaan mesin tidak.
    @Test func reminderOutranksMachine() {
        let nudge = next(reminders: [reminder(in: 120)], mood: .hot,
                         moodSince: now.addingTimeInterval(-3600))
        #expect(nudge?.isMachine == false)
    }
}
```

- [ ] **Step 2: Jalankan dan pastikan gagal**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/NudgeRulesTests 2>&1 | grep -E "error:" | head -3`
Expected: `cannot find 'QuietSignals' in scope`.

- [ ] **Step 3: Tulis `QuietSignals`**

```swift
//
//  QuietSignals.swift
//  Apl
//
//  Jawaban atas satu pertanyaan: boleh bicara sekarang? (spec C2 §4)
//
//  Nilai polos, tanpa cara membacanya sendiri — supaya seluruh aturan bisa
//  diuji tanpa layar, tanpa jendela, dan tanpa Mac yang sedang panas.
//

struct QuietSignals: Equatable {
    var otherAppIsFullScreen = false
    var screenIsAsleepOrLocked = false
    /// Pengguna sudah bersama Apl; tidak perlu disapa.
    var aplIsFrontmost = false
    var quickAskIsOpen = false
    var buddyIsRunning = true
    var aNudgeIsOnScreen = false

    var allowsSpeaking: Bool {
        buddyIsRunning
            && !otherAppIsFullScreen
            && !screenIsAsleepOrLocked
            && !aplIsFrontmost
            && !quickAskIsOpen
            && !aNudgeIsOnScreen
    }
}
```

- [ ] **Step 4: Tulis `NudgeRules`**

```swift
//
//  NudgeRules.swift
//  Apl
//
//  Seluruh keputusan C2, dalam satu fungsi murni (spec C2 §4).
//
//  Tidak menyentuh jam sistem, penyimpanan, maupun AppKit: semuanya masuk lewat
//  parameter. Itu sebabnya aturan kuota bisa diuji dalam milidetik alih-alih
//  menunggu empat jam.
//

import Foundation

enum NudgeRules {

    static let reminderLead: TimeInterval = 5 * 60
    static let moodMustPersist: TimeInterval = 10 * 60
    static let machineCooldown: TimeInterval = 4 * 3600
    static let machinePerDay = 2
    static let ignoredBackoff: TimeInterval = 3600

    static func next(now: Date,
                     reminders: [Reminder],
                     mood: SystemMood,
                     moodSince: Date?,
                     history: NudgeHistory.Snapshot,
                     signals: QuietSignals,
                     calendar: Calendar = .current) -> Nudge? {
        guard signals.allowsSpeaking else { return nil }
        // Reminder didahulukan: ia punya waktu yang tidak bisa ditunda, dan ia
        // diminta pengguna. Keadaan mesin bisa menunggu detak berikutnya.
        return reminderNudge(now: now, reminders: reminders, history: history, calendar: calendar)
            ?? machineNudge(now: now, mood: mood, moodSince: moodSince,
                            history: history, calendar: calendar)
    }

    private static func reminderNudge(now: Date, reminders: [Reminder],
                                      history: NudgeHistory.Snapshot,
                                      calendar: Calendar) -> Nudge? {
        let upcoming = reminders.compactMap { reminder -> (Reminder, Date)? in
            guard let next = reminder.nextOccurrence(after: now, calendar: calendar) else { return nil }
            let delta = next.timeIntervalSince(now)
            guard delta > 0, delta <= reminderLead else { return nil }
            return (reminder, next)
        }
        .sorted { $0.1 < $1.1 }

        for (reminder, at) in upcoming {
            let nudge = Nudge(kind: .reminderSoon(reminder.id, at: at),
                              text: NudgeText.reminderSoon(title: reminder.title, at: at))
            if history.shownReminderKeys[nudge.key] == nil { return nudge }
        }
        return nil
    }

    private static func machineNudge(now: Date, mood: SystemMood, moodSince: Date?,
                                     history: NudgeHistory.Snapshot,
                                     calendar: Calendar) -> Nudge? {
        guard let text = NudgeText.machine(mood) else { return nil }
        // Lonjakan sesaat bukan kabar; yang bertahan barulah kabar.
        guard let moodSince, now.timeIntervalSince(moodSince) >= moodMustPersist else { return nil }

        if let ignored = history.lastIgnoredAt, now.timeIntervalSince(ignored) < ignoredBackoff {
            return nil
        }
        if let last = history.lastMachineAt, now.timeIntervalSince(last) < machineCooldown {
            return nil
        }
        let today = calendar.startOfDay(for: now)
        let countToday = history.machineDay == today ? history.machineCountToday : 0
        guard countToday < machinePerDay else { return nil }

        return Nudge(kind: .machine(mood), text: text)
    }
}
```

- [ ] **Step 5: Jalankan dan pastikan lulus**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/NudgeRulesTests 2>&1 | grep -E "Test run with|TEST"`
Expected: PASS (14 test).

- [ ] **Step 6: Commit**

```bash
git add DinoPocketMac/Presentation/Nudge/QuietSignals.swift DinoPocketMac/Presentation/Nudge/NudgeRules.swift DinoPocketTests/NudgeRulesTests.swift
git commit -m "$(cat <<'EOF'
feat(c2): seluruh keputusan proaktif dalam satu fungsi murni

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Geometri untuk balon yang lebih kecil

**Files:**
- Modify: `DinoPocketMac/Presentation/QuickAsk/BubblePlacement.swift`
- Test: `DinoPocketTests/BubblePlacementTests.swift` (tambah, jangan ubah yang ada)

**Interfaces:**
- Produces: `BubblePlacement.frame(robot:screen:size:) -> CGRect` (baru);
  `frame(robot:screen:contentHeight:)` tetap ada dan tetap berperilaku sama.

- [ ] **Step 1: Tambahkan test**

```swift
    /// Balon nudge lebih kecil dari bubble; sisi dan jepitannya harus memakai
    /// lebar balon itu, bukan lebar 360 milik bubble.
    @Test func smallBalloonUsesItsOwnWidth() {
        let frame = BubblePlacement.frame(robot: robot(x: 1400), screen: screen,
                                          size: CGSize(width: 220, height: 44))
        #expect(frame.width == 220)
        #expect(frame.maxX <= screen.maxX)
        #expect(frame.maxY == robot(x: 1400).maxY)
    }

    @Test func smallBalloonStillSitsToTheRightWhenThereIsRoom() {
        let frame = BubblePlacement.frame(robot: robot(x: 400), screen: screen,
                                          size: CGSize(width: 220, height: 44))
        #expect(frame.minX == 400 + 120 + BubblePlacement.gap)
    }
```

- [ ] **Step 2: Jalankan dan pastikan gagal**

Run: `xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/BubblePlacementTests 2>&1 | grep -E "error:" | head -3`
Expected: `extra argument 'size' in call`.

- [ ] **Step 3: Generalisasi**

Ganti isi `frame(robot:screen:contentHeight:)` menjadi pembungkus, dan pindahkan
perhitungannya ke versi yang menerima ukuran:

```swift
    /// Versi bubble quick ask: lebar tetap, tinggi dari isi.
    static func frame(robot: CGRect, screen: CGRect, contentHeight: CGFloat) -> CGRect {
        frame(robot: robot, screen: screen,
              size: CGSize(width: width, height: min(max(contentHeight, 0), maxHeight)))
    }

    /// - Parameters:
    ///   - robot: frame karakter dalam koordinat layar.
    ///   - screen: `visibleFrame` layar tempat karakter berada.
    ///   - size: ukuran yang diminta pemanggil.
    static func frame(robot: CGRect, screen: CGRect, size: CGSize) -> CGRect {
        let roomRight = screen.maxX - robot.maxX
        let roomLeft = robot.minX - screen.minX
        let prefersRight = roomRight >= size.width + gap || roomRight >= roomLeft

        let rawX = prefersRight ? robot.maxX + gap : robot.minX - gap - size.width
        let x = clamp(rawX, lower: screen.minX + gap, upper: screen.maxX - gap - size.width)

        let rawY = robot.maxY - size.height
        let y = clamp(rawY, lower: screen.minY + gap, upper: screen.maxY - gap - size.height)

        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }
```

- [ ] **Step 4: Jalankan seluruh suite**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' 2>&1 | grep -E "Test run with|TEST"`
Expected: seluruh suite lulus; sembilan test `BubblePlacementTests` lama tetap hijau tanpa
diubah.

- [ ] **Step 5: Commit**

```bash
git add DinoPocketMac/Presentation/QuickAsk/BubblePlacement.swift DinoPocketTests/BubblePlacementTests.swift
git commit -m "$(cat <<'EOF'
feat(c2): geometri bubble menerima ukuran, bukan hanya tinggi

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Balon dan panelnya

**Files:**
- Create: `DinoPocketMac/Presentation/Nudge/NudgeBalloon.swift`,
  `DinoPocketMac/Presentation/Nudge/NudgePanelController.swift`
- Test: tidak ada test unit (AppKit murni); diverifikasi di Task 8.

**Interfaces:**
- Consumes: `Nudge`, `BubblePlacement.frame(robot:screen:size:)`,
  `AplBuddyWindowController.characterScreenFrame` / `pauseStrolling()` / `resumeStrolling()`.
- Produces: `NudgeBalloon(text:onTap:onHoverChange:)`,
  `NudgePanelController.shared`, `.isShowing`,
  `.show(_ nudge: Nudge, onEngage: @escaping (Nudge) -> Void, onIgnore: @escaping (Nudge) -> Void)`,
  `.dismiss()`.

- [ ] **Step 1: Tulis balonnya**

```swift
//
//  NudgeBalloon.swift
//  Apl
//
//  Kapsul satu baris di samping robot (spec C2 §5).
//

import SwiftUI

struct NudgeBalloon: View {
    let text: String
    let onTap: () -> Void
    let onHoverChange: (Bool) -> Void

    var body: some View {
        Text(text)
            .font(.callout)
            .lineLimit(2)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: NudgePanelController.maxWidth, alignment: .leading)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.separator))
            .contentShape(Capsule())
            .onTapGesture(perform: onTap)
            .onHover(perform: onHoverChange)
            .accessibilityElement()
            .accessibilityLabel(text)
    }
}

#Preview("Balon · Light") {
    VStack(alignment: .leading, spacing: Spacing.md) {
        NudgeBalloon(text: "Stretch · 3:00 PM", onTap: {}, onHoverChange: { _ in })
        NudgeBalloon(text: "This Mac is running hot.", onTap: {}, onHoverChange: { _ in })
    }
    .padding(Spacing.xl)
}

#Preview("Balon · Dark") {
    NudgeBalloon(text: "Battery is getting low.", onTap: {}, onHoverChange: { _ in })
        .padding(Spacing.xl)
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Tulis panelnya**

```swift
//
//  NudgePanelController.swift
//  Apl
//
//  Panel pasif untuk sapaan yang tidak diminta (spec C2 §3, §5).
//
//  `NudgePanel` sengaja TIDAK meng-override `canBecomeKey`. Itulah seluruh
//  jaminannya: balon yang datang tanpa diminta tidak punya jalan untuk mencuri
//  ketikan siapa pun — bukan karena ada bendera yang menahannya, tetapi karena
//  kemampuannya memang tidak ada.
//

import AppKit
import SwiftUI

private final class NudgePanel: NSPanel {}

@MainActor
final class NudgePanelController {

    static let shared = NudgePanelController()
    static let maxWidth: CGFloat = 300
    /// Umur balon bila tidak disentuh.
    static let lifetime: TimeInterval = 8

    private var panel: NudgePanel?
    private var hosting: NSHostingView<NudgeBalloon>?
    private var dismissTimer: Timer?
    private var current: Nudge?
    private var onEngage: ((Nudge) -> Void)?
    private var onIgnore: ((Nudge) -> Void)?
    private var isHovered = false
    private let buddy: AplBuddyWindowController

    init(buddy: AplBuddyWindowController = .shared) {
        self.buddy = buddy
    }

    var isShowing: Bool { panel?.isVisible == true }

    func show(_ nudge: Nudge,
              onEngage: @escaping (Nudge) -> Void,
              onIgnore: @escaping (Nudge) -> Void) {
        guard let anchor = buddy.characterScreenFrame else { return }
        dismiss(engaged: false, notify: false)

        current = nudge
        self.onEngage = onEngage
        self.onIgnore = onIgnore

        let balloon = NudgeBalloon(
            text: nudge.text,
            onTap: { [weak self] in self?.engage() },
            onHoverChange: { [weak self] hovering in self?.hoverChanged(hovering) }
        )
        let host = NSHostingView(rootView: balloon)
        host.sizingOptions = [.intrinsicContentSize]
        hosting = host

        let panel = self.panel ?? makePanel()
        panel.contentView = host
        let size = CGSize(width: min(host.fittingSize.width, Self.maxWidth),
                          height: host.fittingSize.height)
        panel.setFrame(BubblePlacement.frame(robot: anchor.rect,
                                             screen: anchor.screen.visibleFrame,
                                             size: size),
                       display: true)

        buddy.pauseStrolling()
        panel.orderFrontRegardless()
        startLifetime()
        announce(nudge.text)
    }

    func dismiss(engaged: Bool = false, notify: Bool = true) {
        dismissTimer?.invalidate()
        dismissTimer = nil
        guard let panel, panel.isVisible else { return }
        panel.orderOut(nil)
        buddy.resumeStrolling()
        if notify, !engaged, let current { onIgnore?(current) }
        current = nil
        isHovered = false
    }

    // MARK: - Internal

    private func makePanel() -> NudgePanel {
        let panel = NudgePanel(contentRect: CGRect(x: 0, y: 0, width: Self.maxWidth, height: 44),
                               styleMask: [.borderless, .nonactivatingPanel],
                               backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.panel = panel
        return panel
    }

    private func engage() {
        guard let nudge = current else { return }
        dismiss(engaged: true)
        onEngage?(nudge)
    }

    /// Kursor yang berada di atas balon menahannya: orang sedang membacanya.
    private func hoverChanged(_ hovering: Bool) {
        isHovered = hovering
        if hovering {
            dismissTimer?.invalidate()
            dismissTimer = nil
        } else {
            startLifetime()
        }
    }

    private func startLifetime() {
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: Self.lifetime, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.isHovered else { return }
                self.dismiss()
            }
        }
    }

    /// Balon tidak bisa menerima fokus, jadi VoiceOver tidak menemukannya
    /// sendiri. Prioritas RENDAH: dikabarkan, tanpa memotong yang sedang
    /// dibacakan — ini sapaan yang tidak diminta.
    private func announce(_ text: String) {
        NSAccessibility.post(element: NSApp as Any,
                             notification: .announcementRequested,
                             userInfo: [
                                .announcement: text,
                                .priority: NSAccessibilityPriorityLevel.low.rawValue,
                             ])
    }
}
```

- [ ] **Step 3: Build**

Run: `xcodegen generate && xcodebuild build -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' 2>&1 | grep -E "error:|BUILD"`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add DinoPocketMac/Presentation/Nudge/NudgeBalloon.swift DinoPocketMac/Presentation/Nudge/NudgePanelController.swift
git commit -m "$(cat <<'EOF'
feat(c2): balon pasif yang tidak bisa merebut fokus

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Suara

**Files:**
- Create: `DinoPocketMac/Infrastructure/Services/NudgeSpeaker.swift`
- Modify: `DinoPocketMac/Infrastructure/Persistence/BuddySettingsStore.swift`,
  `DinoPocketMac/Presentation/Settings/SettingsWindow.swift`

**Interfaces:**
- Produces: `NudgeSpeaker` (`speak(_:)`, `stop()`, `isSpeaking`),
  `BuddySettingsStore.speaks: Bool` (kunci `nudge.speaks`, bawaan `false`).

- [ ] **Step 1: Tulis pembacanya**

```swift
//
//  NudgeSpeaker.swift
//  Apl
//
//  Membacakan sapaan yang tidak diminta (spec C2 §5). Mati secara bawaan.
//
//  Hanya balon proaktif yang dibacakan: jumlahnya sudah dibatasi kuota.
//  Jawaban atas pertanyaan pengguna tidak pernah bersuara — panjangnya tidak
//  terbatas, dan tidak ada yang meminta dibacakan.
//

import AVFoundation

@MainActor
final class NudgeSpeaker {

    private let synthesizer = AVSpeechSynthesizer()

    var isSpeaking: Bool { synthesizer.isSpeaking }

    /// Selalu menghentikan yang sedang berbunyi: dua kalimat sekaligus tidak
    /// terbaca sebagai apa pun.
    func speak(_ text: String) {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    func stop() {
        guard synthesizer.isSpeaking else { return }
        synthesizer.stopSpeaking(at: .immediate)
    }
}
```

- [ ] **Step 2: Tambahkan preferensinya**

Di `BuddySettingsStore`, tambahkan kunci dan properti mengikuti pola `strolling`:

```swift
        static let speaks = "nudge.speaks"
```

```swift
    /// Membacakan sapaan yang tidak diminta. Mati secara bawaan: suara yang
    /// muncul sendiri tanpa diminta adalah hal terakhir yang boleh mengejutkan
    /// orang (spec C2 §5).
    var speaks: Bool {
        didSet {
            defaults.set(speaks, forKey: Keys.speaks)
            // Dipaksa turun ke disk; lihat catatan di `ProfileStore`.
            defaults.synchronize()
        }
    }
```

Di `init`, muat nilainya: `self.speaks = defaults.bool(forKey: Keys.speaks)` (bawaan
`false`, jadi `bool(forKey:)` sudah benar). Tambahkan `Keys.speaks` ke daftar kunci yang
dihapus `eraseAllStoredData()`.

- [ ] **Step 3: Tambahkan togglenya di Settings**

Di `CharacterSettingsTab`, di bawah "Wander around the desktop":

```swift
                Toggle("Speak when Apl greets you", isOn: $buddySettings.speaks)
```

- [ ] **Step 4: Build dan jalankan seluruh suite**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' 2>&1 | grep -E "error:|Test run with|TEST"`
Expected: seluruh suite lulus.

- [ ] **Step 5: Commit**

```bash
git add DinoPocketMac/Infrastructure/Services/NudgeSpeaker.swift DinoPocketMac/Infrastructure/Persistence/BuddySettingsStore.swift DinoPocketMac/Presentation/Settings/SettingsWindow.swift
git commit -m "$(cat <<'EOF'
feat(c2): suara untuk sapaan, mati secara bawaan

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Detak dan pemasangan

**Files:**
- Create: `DinoPocketMac/Infrastructure/Services/QuietSignalReader.swift`,
  `DinoPocketMac/Presentation/Nudge/NudgeScheduler.swift`
- Modify: `DinoPocketMac/App/AppDependencies.swift`, `DinoPocketMac/App/AplApp.swift`

**Interfaces:**
- Consumes: semua unit Task 1–6.
- Produces: `QuietSignalReader.read() -> QuietSignals`, `NudgeScheduler`
  (`init(reminders:status:history:settings:panel:speaker:signals:chat:now:)`, `start()`,
  `stop()`), `AppDependencies.nudgeHistory`.

- [ ] **Step 1: Tulis pembaca sinyal**

```swift
//
//  QuietSignalReader.swift
//  Apl
//
//  Membaca keadaan yang membungkam Apl (spec C2 §4) — tanpa satu pun izin baru.
//

import AppKit

@MainActor
struct QuietSignalReader {

    var isBuddyRunning: () -> Bool
    var isQuickAskOpen: () -> Bool
    var isNudgeOnScreen: () -> Bool

    func read() -> QuietSignals {
        QuietSignals(
            otherAppIsFullScreen: Self.frontmostAppIsFullScreen(),
            screenIsAsleepOrLocked: Self.screenIsAsleepOrLocked(),
            aplIsFrontmost: NSApp.isActive,
            quickAskIsOpen: isQuickAskOpen(),
            buddyIsRunning: isBuddyRunning(),
            aNudgeIsOnScreen: isNudgeOnScreen()
        )
    }

    /// Jendela layar penuh berukuran PERSIS sebesar layarnya, termasuk area
    /// menu bar; jendela yang di-zoom hanya sebesar `visibleFrame`.
    ///
    /// Ukurannya yang dibandingkan, bukan posisinya: `CGWindowList` memakai
    /// koordinat ber-origin kiri-atas sedangkan `NSScreen` kiri-bawah, dan
    /// menyamakan keduanya hanya menambah cara untuk salah.
    static func frontmostAppIsFullScreen() -> Bool {
        guard let front = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              front != ProcessInfo.processInfo.processIdentifier,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                       kCGNullWindowID) as? [[String: Any]]
        else { return false }

        let screenSizes = NSScreen.screens.map(\.frame.size)
        for window in windows {
            guard window[kCGWindowOwnerPID as String] as? pid_t == front,
                  window[kCGWindowLayer as String] as? Int == 0,
                  let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary)
            else { continue }
            if screenSizes.contains(where: { $0 == rect.size }) { return true }
        }
        return false
    }

    static func screenIsAsleepOrLocked() -> Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        let locked = session["CGSSessionScreenIsLocked"] as? Int == 1
        let onConsole = session["kCGSSessionOnConsoleKey"] as? Int != 0
        return locked || !onConsole
    }
}
```

- [ ] **Step 2: Tulis penjadwalnya**

```swift
//
//  NudgeScheduler.swift
//  Apl
//
//  Detak yang menanyakan satu pertanyaan: ada yang perlu dikatakan? (spec C2 §3)
//
//  Tidak memutuskan apa pun sendiri. Ia mengumpulkan keadaan, bertanya kepada
//  `NudgeRules`, lalu menjalankan jawabannya.
//

import AppKit
import Foundation

@MainActor
final class NudgeScheduler {

    /// Satu menit cukup: jendela reminder 5 menit, dan keadaan mesin berubah
    /// dalam hitungan menit. Di Low Power Mode melambat lima kali lipat —
    /// itulah jawaban atas beban baterai, bukan aturan diam (spec C2 §4).
    static let tick: TimeInterval = 60
    static let lowPowerTick: TimeInterval = 300

    private let reminders: any ReminderStoring
    private let status: any SystemStatusProviding
    private let history: NudgeHistory
    private let settings: BuddySettingsStore
    private let panel: NudgePanelController
    private let speaker: NudgeSpeaker
    private let signals: QuietSignalReader
    private let engage: (Nudge) -> Void
    private let now: () -> Date

    private var timer: Timer?
    private var lastMood: SystemMood?
    private var moodSince: Date?
    private var powerObserver: (any NSObjectProtocol)?

    init(reminders: any ReminderStoring,
         status: any SystemStatusProviding,
         history: NudgeHistory,
         settings: BuddySettingsStore,
         panel: NudgePanelController = .shared,
         speaker: NudgeSpeaker,
         signals: QuietSignalReader,
         engage: @escaping (Nudge) -> Void,
         now: @escaping () -> Date = { .now }) {
        self.reminders = reminders
        self.status = status
        self.history = history
        self.settings = settings
        self.panel = panel
        self.speaker = speaker
        self.signals = signals
        self.engage = engage
        self.now = now
    }

    func start() {
        stop()
        schedule()
        powerObserver = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.schedule() }
            }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let powerObserver { NotificationCenter.default.removeObserver(powerObserver) }
        powerObserver = nil
        speaker.stop()
        panel.dismiss(engaged: false, notify: false)
    }

    private func schedule() {
        timer?.invalidate()
        let interval = ProcessInfo.processInfo.isLowPowerModeEnabled ? Self.lowPowerTick : Self.tick
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        let moment = now()
        let mood = status.currentMood()
        if mood != lastMood {
            lastMood = mood
            moodSince = moment
        }
        history.prune(now: moment)

        guard let nudge = NudgeRules.next(now: moment,
                                          reminders: reminders.reminders,
                                          mood: mood,
                                          moodSince: moodSince,
                                          history: history.snapshot,
                                          signals: signals.read()) else { return }

        // Dicatat SEBELUM ditampilkan: lihat catatan di `NudgeHistory`.
        history.record(nudge, at: moment)
        panel.show(nudge,
                   onEngage: { [weak self] nudge in self?.engaged(nudge) },
                   onIgnore: { [weak self] _ in self?.history.markIgnored(at: self?.now() ?? .now) })
        if settings.speaks {
            speaker.speak(nudge.text)
        }
    }

    private func engaged(_ nudge: Nudge) {
        speaker.stop()
        engage(nudge)
    }
}
```

- [ ] **Step 3: Pasang di `AppDependencies`**

Tambahkan `let nudgeHistory: NudgeHistory` (dibuat `NudgeHistory()` di `live()`) dan
masukkan ke `erasableStores`.

- [ ] **Step 4: Pasang di `AplApp`**

Tambahkan state dan hidupkan bersama Buddy Mode:

```swift
    @State private var nudgeHistory = deps.nudgeHistory
    @State private var speaker = NudgeSpeaker()
    @State private var nudges: NudgeScheduler?
```

Di `.task` C1 (tempat `QuickAskPanelController.shared.configure` dipasang), tambahkan:

```swift
            let scheduler = NudgeScheduler(
                reminders: Self.deps.reminderStore,
                status: Self.deps.systemStatus,
                history: nudgeHistory,
                settings: buddySettings,
                speaker: speaker,
                signals: QuietSignalReader(
                    isBuddyRunning: { isBuddyMode },
                    isQuickAskOpen: { QuickAskPanelController.shared.isOpen },
                    isNudgeOnScreen: { NudgePanelController.shared.isShowing }
                ),
                engage: { nudge in
                    // Sapaan baru masuk percakapan saat diklik (spec C2 §2 #7).
                    chat.appendAssistantNote(nudge.text)
                    _ = QuickAskPanelController.shared.open()
                }
            )
            scheduler.start()
            nudges = scheduler
```

Dan di `.onChange(of: isBuddyMode)`, hentikan penjadwal saat Buddy dimatikan:

```swift
            } else {
                AplBuddyWindowController.shared.stopBuddyMode()
                nudges?.stop()
            }
```
serta `nudges?.start()` di cabang `if active`.

- [ ] **Step 5: Tambahkan `appendAssistantNote` di `ChatStore`**

```swift
    /// Menyisipkan kalimat Apl yang TIDAK berasal dari model — sapaan proaktif
    /// yang diklik pengguna (spec C2 §5). Tidak memanggil otak dan tidak
    /// memulai stream; ia hanya menjadi giliran terakhir supaya bisa dijawab.
    func appendAssistantNote(_ text: String) {
        guard !text.isEmpty else { return }
        finalizeInterruptedAssistant()
        messages.append(ChatMessage(role: .assistant, text: text, date: now()))
        persistRecent()
    }
```

- [ ] **Step 6: Build, seluruh suite, dan pemeriksa**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' 2>&1 | grep -E "error:|Test run with|TEST"`
Expected: seluruh suite lulus.

Run: `./scripts/verify-boundaries.sh && ./scripts/verify-release.sh 2>&1 | tail -3`
Expected: keduanya hijau.

Run: `git diff --stat DinoPocketMac/DinoPocket.entitlements`
Expected: **kosong** — tidak ada izin baru (spec §8).

- [ ] **Step 7: Commit**

```bash
git add DinoPocketMac/Infrastructure/Services/QuietSignalReader.swift DinoPocketMac/Presentation/Nudge/NudgeScheduler.swift DinoPocketMac/App/AppDependencies.swift DinoPocketMac/App/AplApp.swift DinoPocketMac/Presentation/ViewModels/ChatStore.swift
git commit -m "$(cat <<'EOF'
feat(c2): detak proaktif, sinyal peredam, dan pemasangannya

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Verifikasi manual dan catatan

**Files:**
- Modify: spec §8 (DoD), plan ini (Catatan eksekusi)

- [ ] **Step 1: Jalankan app dengan pemicu yang bisa dipaksa**

Buat satu reminder untuk 6 menit dari sekarang lewat chat ("remind me to stretch at
HH:MM"), lalu tunggu balon muncul pada menit kelima. Jangan mengubah pengaturan sistem
mana pun untuk memaksa keadaan mesin; bila `.hot`/`.lowBattery` tidak terjadi secara alami,
catat pemicu 2 sebagai belum terverifikasi.

- [ ] **Step 2: Kerjakan daftar periksa spec §7**

1. Balon muncul di samping robot, hilang sendiri setelah 8 detik.
2. Kursor di atasnya menahannya.
3. Klik membuka bubble berisi sapaan itu sebagai giliran asisten, siap dijawab.
4. Nyalakan "Speak when Apl greets you" → balon berikutnya dibacakan sekali.
5. Safari layar penuh → tidak ada balon (uji `frontmostAppIsFullScreen` — satu-satunya
   sinyal yang belum pernah dijalankan; lihat spec §10).
6. Apl di depan → tidak ada balon.
7. Regresi C1: ⌥Space, klik robot, Esc.

- [ ] **Step 3: Perbaiki temuan, satu commit per temuan**

- [ ] **Step 4: Tulis hasilnya**

Tandai DoD di spec §8, tambahkan "Catatan eksekusi" di plan ini, dan bila ada yang berubah
dari rancangan, tambahkan bagian "Penyesuaian saat pelaksanaan" di spec.

- [ ] **Step 5: Commit catatan**

```bash
git add docs/superpowers/specs/2026-09-20-apl-proactive-design.md docs/superpowers/plans/2026-09-20-apl-proactive.md
git commit -m "$(cat <<'EOF'
docs(c2): catat hasil verifikasi manual

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Self-review

**Cakupan spec:** §2 #1 → Task 5; #2 → Task 7 (tanpa Intents) dan langkah pemeriksa
entitlements; #3 → Task 3; #4 → Task 3 (`reminderLead`, notifikasi tidak disentuh);
#5 → Task 6; #6 → Task 5 (`NudgePanel` tanpa `canBecomeKey`); #7 → Task 7
(`appendAssistantNote` hanya dipanggil dari `engage`). §4 aturan → Task 3 seluruhnya.
§5 balon → Task 5. §6 privasi → Task 2 dan Task 6 (keduanya `LocallyErasable`). §7 uji →
Task 1–4 dan Task 8. §8 DoD → Task 8.

**Placeholder:** tidak ada; setiap langkah membawa kode atau perintah yang bisa dijalankan.

**Konsistensi tipe:** `Nudge.key` dipakai Task 2 dan 3 dengan bentuk yang sama.
`NudgeHistory.Snapshot` dibaca `NudgeRules` sebagai nilai, ditulis `NudgeHistory` sebagai
kelas. `QuietSignals` dibangun `QuietSignalReader` dengan keenam bendera yang sama persis
seperti yang diuji Task 3. `BubblePlacement.frame(robot:screen:size:)` didefinisikan Task 4
dan dipanggil Task 5. `ReminderStoring` adalah protokol yang sudah ada di
`ReminderStore.swift` (properti `reminders`).

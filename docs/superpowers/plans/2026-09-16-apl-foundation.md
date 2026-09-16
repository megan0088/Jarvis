# Apl — Fondasi & Kepatuhan (Sub-project A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** App Apl tanpa akun, tanpa wellness, dengan Apple Intelligence sebagai satu-satunya brain dan reminder dari chat yang jujur (sekali jalan + harian, judul bebas), plus pemeriksaan rilis yang sesuai keadaan hari ini.

**Architecture:** Commit baseline WIP dulu, lalu hapus Sign in with Apple. Domain reminder baru (`Reminder`, `ReminderStore`, `ReminderParser`, `ReminderScheduling`) dibangun secara aditif dengan TDD, disambungkan ke `ChatStore` lewat penjaga niat, lalu wellness dihapus setelah tidak ada lagi yang bergantung padanya. Terakhir, brain disatukan ke Apple Intelligence, data lama dibersihkan, dan `verify-release.sh` diperbarui.

**Tech Stack:** Swift 6, SwiftUI (macOS 26.2), Foundation Models, UserNotifications, Swift Testing, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-09-15-apl-foundation-design.md` (keputusan program: `docs/superpowers/specs/2026-09-15-apl-main-window-design.md` §2–§3)

## Global Constraints

- Repo: `/Users/egaaaa/Documents/DinoPocket`, branch `refactor/taggo-architecture`. Semua perintah dijalankan dari root repo.
- `DinoPocket.xcodeproj` di-gitignore dan dibuat oleh XcodeGen. **Setiap kali file Swift ditambah, dihapus, atau di-rename, jalankan `xcodegen generate` sebelum build/test.**
- Build: `xcodebuild build -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS,arch=arm64' 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"`
- Test semua: `xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS,arch=arm64' 2>&1 | grep -E "Test run with|TEST (SUCCEEDED|FAILED)|error:|✘"`
- Test satu suite: tambahkan `-only-testing:DinoPocketTests/<NamaStruct>` pada perintah test.
- Nama modul app adalah `Apl`; test memakai `@testable import Apl`.
- Deployment target macOS 26.2, `SWIFT_VERSION` 6.0, `SWIFT_APPROACHABLE_CONCURRENCY` YES. Tidak ada `static let` bertipe non-`Sendable` (misalnya `ISO8601DateFormatter`, `NSRegularExpression`): Swift 6 menolaknya.
- `SharedCore/` tidak boleh `import SwiftUI`/`AppKit`/`UIKit` dan tidak boleh `#if os(`. Dijaga oleh `scripts/verify-boundaries.sh`.
- Copy UI dalam bahasa Inggris. Komentar kode dalam bahasa Indonesia, mengikuti gaya repo.
- Jangan sentuh file iOS yang dibekukan dan sudah dikecualikan dari build: `DinoPocketMac/Presentation/Views/ContentView.swift`, `ContentView+iOS.swift`, `ContentView+macOS.swift`, `PetActivityWidgets.swift`, `DinoPocketMac/Infrastructure/Services/Haptics.swift`, `JarvisWidget/`, `DinoPocketMac/Legacy/`.
- Setiap commit diakhiri trailer `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.
- Jumlah test yang disebut di setiap task adalah perkiraan hasil hitungan. Kalau angkanya berbeda, cocokkan dengan daftar perubahan test di task itu sebelum lanjut. Yang wajib adalah `** TEST SUCCEEDED **`.

## Deviasi yang disengaja dari spec A

1. **Urutan §3.** Spec memisahkan A2 (reminder dipindah dengan perilaku lama) dan A4 (model baru). Hasil A2 akan langsung ditulis ulang di A4. Rencana ini membangun domain reminder baru secara aditif (Task 3–5), menyambungkannya (Task 6), baru menghapus wellness (Task 7). Tujuan spec tetap terjaga: reminder tidak pernah rusak di tengah jalan.
2. **Nama protokol.** Spec menyebut `NotificationScheduling`. Nama itu masih dipakai wellness sampai Task 7, jadi protokol baru bernama `ReminderScheduling`.
3. **Jam tanpa am/pm.** Spec menulis "angka tanpa am/pm dan tanpa titik dua bukan waktu", tapi contohnya sendiri memakai "tomorrow at 9" dan "every day at 9". Aturan di rencana ini: angka polos dianggap waktu **hanya tepat setelah `at`**, dibaca sebagai jam 24 (`at 9` = 09.00, `at 15` = 15.00). Konfirmasi selalu menyebut jamnya, jadi salah tafsir langsung terlihat oleh pengguna.
4. **Suite "Ketersediaan otak"** dipindah ke berkas sendiri, `ChatAvailabilityTests.swift`, bukan digabung ke `ChatStoreTests.swift`. Kedua berkas punya `private struct StubBrain` yang berbeda bentuk.

## Peta berkas

| Berkas | Tanggung jawab | Task |
|---|---|---|
| `DinoPocketMac/Infrastructure/Persistence/ProfileStore.swift` | Nama panggilan + status onboarding | 2 |
| `SharedCore/Domain/UseCases/EraseAllDataUseCase.swift` | `LocallyErasable` + penghapusan semua data | 2 |
| `SharedCore/Data/Models/Reminder.swift` | Model reminder + `nextOccurrence` | 3 |
| `SharedCore/Infrastructure/Persistence/ReminderStore.swift` | `ReminderStoring` + penyimpanan JSON | 3 |
| `SharedCore/Infrastructure/Services/ReminderParser.swift` | Tata bahasa reminder, tanpa AI | 4 |
| `SharedCore/Infrastructure/Services/ReminderScheduling.swift` | Protokol penjadwal + rencana trigger murni | 5 |
| `SharedCore/Infrastructure/Services/ReminderNotificationCenter.swift` | Adapter `UNUserNotificationCenter` | 5 |
| `SharedCore/Domain/UseCases/ReminderPhrasing.swift` | Kalimat konfirmasi & pertanyaan waktu | 5 |
| `SharedCore/Domain/UseCases/CancelReminderUseCase.swift`, `UpdateReminderUseCase.swift` | Dipakai B (Up next, Undo, edit) | 5 |
| `SharedCore/Domain/UseCases/CreateReminderFromTextUseCase.swift` | Ditulis ulang: parse → simpan → jadwalkan | 6 |
| `SharedCore/Infrastructure/Services/AplInstructions.swift` | Instructions tetap untuk sesi model | 8 |
| `DinoPocketMac/Infrastructure/Persistence/LegacyDataCleanup.swift` | Pembersihan data lama | 9 |
| `DinoPocketTests/TestTime.swift`, `ReminderFakes.swift` | Kalender/jam tetap + fake untuk test | 3, 5 |

---

### Task 1: Baseline — perbaiki build dan commit WIP (A0)

**Files:**
- Modify: `SharedCore/Infrastructure/Services/WellnessNotificationCenter.swift:109-123`

**Interfaces:**
- Consumes: —
- Produces: commit baseline yang build dan test-nya hijau.

- [ ] **Step 1: Kembalikan baris yang ditolak Swift 6 ke bentuk HEAD**

Hapus dua baris ini (baris kosong di bawahnya ikut dihapus):

```swift
    nonisolated private static let iso8601Formatter = ISO8601DateFormatter()

```

Lalu ganti:

```swift
        let stamp = iso8601Formatter.string(from: notification.date)
```

menjadi:

```swift
        let stamp = ISO8601DateFormatter().string(from: notification.date)
```

- [ ] **Step 2: Generate project dan build**

Run: `xcodegen generate` lalu perintah Build (Global Constraints).
Expected: `** BUILD SUCCEEDED **`, tanpa `error:`.

- [ ] **Step 3: Jalankan seluruh test**

Run: perintah Test semua.
Expected: `Test run with 79 tests in 19 suites passed` dan `** TEST SUCCEEDED **`. Kalau ada yang gagal, **berhenti dan laporkan**. Jangan menambal WIP diam-diam.

- [ ] **Step 4: Periksa batas SharedCore**

Run: `./scripts/verify-boundaries.sh`
Expected: `✅ batas SharedCore aman`

- [ ] **Step 5: Periksa isi yang akan di-commit**

Run: `git status --short | grep '^??'`
Expected: hanya berkas-berkas berikut:
- `DinoPocketMac/Assets.xcassets/AppIcon.appiconset/mac_*.png` (10 berkas)
- `DinoPocketMac/Resources/RobotBigSmile.usdz`, `RobotFlat.usdz`, `RobotO.usdz`, `RobotSad.usdz`, `RobotSmile.usdz`
- `DinoPocketTests/RemindersWiringTests.swift`
- `docs/assets/`

Kalau muncul berkas lain, berhenti dan tanyakan ke pengguna sebelum commit.

- [ ] **Step 6: Commit baseline**

```bash
git add -A
git commit -m "$(cat <<'EOF'
chore(a0): baseline WIP — rename ke Apl, 5 ekspresi robot, ikon macOS

Mengunci pekerjaan yang belum di-commit sebagai titik awal sub-project A:
rename Jarvis → Apl, Robot.usdz diganti lima ekspresi, ikon aplikasi
macOS, RemindersWiringTests, dan penyesuaian project.yml serta
verify-release.sh.

Satu baris dikembalikan ke bentuk HEAD: static let ISO8601DateFormatter
ditolak Swift 6 karena tipenya bukan Sendable.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Hapus Sign in with Apple (A1)

**Files:**
- Create: `DinoPocketMac/Infrastructure/Persistence/ProfileStore.swift`
- Create: `DinoPocketTests/ProfileStoreTests.swift`
- Rename + rewrite: `SharedCore/Domain/UseCases/DeleteAccountUseCase.swift` → `EraseAllDataUseCase.swift`
- Rename + rewrite: `DinoPocketTests/DeleteAccountUseCaseTests.swift` → `EraseAllDataUseCaseTests.swift`
- Modify: `DinoPocketMac/Infrastructure/Persistence/BuddySettingsStore.swift` (tambah `LocallyErasable`)
- Modify: `DinoPocketTests/PhaseAComponentTests.swift` (satu test di `BuddySettingsStoreTests`)
- Rewrite: `DinoPocketMac/Presentation/Views/OnboardingView.swift`
- Modify: `SettingsPage.swift`, `DashboardTemplate.swift`, `HomePage.swift`, `AplApp.swift`, `AppDependencies.swift`, `DinoPocketTests/RemindersWiringTests.swift`, `project.yml`
- Delete: `DinoPocketMac/Infrastructure/Persistence/AccountStore.swift`, `KeychainStore.swift`, `DinoPocketMac/DinoPocketMac.entitlements`

**Interfaces:**
- Consumes: —
- Produces:
  - `@MainActor @Observable final class ProfileStore: LocallyErasable` dengan `init(defaults: UserDefaults = .standard)`, `private(set) var nickname: String?`, `private(set) var hasCompletedOnboarding: Bool`, `nonisolated static func normalizedNickname(_ raw: String?) -> String?`, `func setNickname(_ raw: String?)`, `func completeOnboarding()`, `func eraseAllStoredData()`
  - `@MainActor protocol LocallyErasable { func eraseAllStoredData() }` (tetap di `EraseAllDataUseCase.swift`)
  - `@MainActor struct EraseAllDataUseCase` dengan `init(stores: [any LocallyErasable], clearNotifications: (() async -> Void)? = nil)` dan `@discardableResult func execute() async -> Output`, `struct Output: Equatable { let erasedStoreCount: Int }`
  - `BuddySettingsStore: LocallyErasable`
  - `AppDependencies.profile: ProfileStore` (menggantikan `account`)

- [ ] **Step 1: Tulis test `ProfileStore` yang gagal**

Buat `DinoPocketTests/ProfileStoreTests.swift`:

```swift
import Foundation
import Testing
@testable import Apl

@MainActor
struct ProfileStoreTests {

    private func isolatedDefaults(_ name: String) -> UserDefaults {
        let suite = "test.profile.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func blankNicknameCountsAsNone() {
        #expect(ProfileStore.normalizedNickname(nil) == nil)
        #expect(ProfileStore.normalizedNickname("") == nil)
        #expect(ProfileStore.normalizedNickname("   ") == nil)
    }

    @Test func nicknameIsTrimmed() {
        #expect(ProfileStore.normalizedNickname("  Ega \n") == "Ega")
    }

    @Test func nicknameAndOnboardingSurviveRelaunch() {
        let defaults = isolatedDefaults(#function)
        let first = ProfileStore(defaults: defaults)
        first.setNickname("Ega")
        first.completeOnboarding()

        let second = ProfileStore(defaults: defaults)
        #expect(second.nickname == "Ega")
        #expect(second.hasCompletedOnboarding)
    }

    @Test func clearingNicknameRemovesTheStoredValue() {
        let defaults = isolatedDefaults(#function)
        let store = ProfileStore(defaults: defaults)
        store.setNickname("Ega")

        store.setNickname("  ")

        #expect(store.nickname == nil)
        #expect(defaults.object(forKey: "account.displayName") == nil)
    }

    @Test func eraseResetsNicknameAndOnboarding() {
        let defaults = isolatedDefaults(#function)
        let store = ProfileStore(defaults: defaults)
        store.setNickname("Ega")
        store.completeOnboarding()

        store.eraseAllStoredData()

        #expect(store.nickname == nil)
        #expect(store.hasCompletedOnboarding == false)
        #expect(ProfileStore(defaults: defaults).hasCompletedOnboarding == false)
    }
}
```

- [ ] **Step 2: Jalankan dan pastikan gagal**

Run: `xcodegen generate`, lalu perintah Test dengan `-only-testing:DinoPocketTests/ProfileStoreTests`
Expected: FAIL, kompilasi gagal dengan `cannot find 'ProfileStore' in scope`.

- [ ] **Step 3: Implementasikan `ProfileStore`**

Buat `DinoPocketMac/Infrastructure/Persistence/ProfileStore.swift`:

```swift
//
//  ProfileStore.swift
//  AplMac
//
//  Nama panggilan dan status onboarding.
//
//  Menggantikan AccountStore. App ini on-device tanpa server, jadi tidak ada
//  akun untuk dibuat — login wajib hanya menambah risiko Guideline 5.1.1(v).
//  Kunci UserDefaults sengaja dipertahankan dari AccountStore supaya status
//  onboarding yang sudah ada tidak hilang tanpa alasan.
//

import Foundation
import Observation

@MainActor
@Observable
final class ProfileStore {

    private enum Keys {
        static let nickname = "account.displayName"
        static let onboardingDone = "onboarding.completed"
    }

    private(set) var nickname: String?
    private(set) var hasCompletedOnboarding: Bool

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.nickname = Self.normalizedNickname(defaults.string(forKey: Keys.nickname))
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.onboardingDone)
    }

    /// Nama kosong atau hanya spasi berarti "tanpa nama", supaya sapaan tidak
    /// berbunyi "Hello, " dengan koma menggantung.
    nonisolated static func normalizedNickname(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }

    func setNickname(_ raw: String?) {
        nickname = Self.normalizedNickname(raw)
        if let nickname {
            defaults.set(nickname, forKey: Keys.nickname)
        } else {
            defaults.removeObject(forKey: Keys.nickname)
        }
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        defaults.set(true, forKey: Keys.onboardingDone)
    }

    func eraseAllStoredData() {
        nickname = nil
        hasCompletedOnboarding = false
        defaults.removeObject(forKey: Keys.nickname)
        defaults.removeObject(forKey: Keys.onboardingDone)
    }
}

extension ProfileStore: LocallyErasable {}
```

- [ ] **Step 4: Jalankan test `ProfileStore`**

Run: `xcodegen generate`, lalu perintah Test dengan `-only-testing:DinoPocketTests/ProfileStoreTests`
Expected: 5 test PASS.

- [ ] **Step 5: Tulis test `EraseAllDataUseCase` yang gagal**

```bash
git mv DinoPocketTests/DeleteAccountUseCaseTests.swift DinoPocketTests/EraseAllDataUseCaseTests.swift
```

Ganti seluruh isi `DinoPocketTests/EraseAllDataUseCaseTests.swift` dengan kode berikut. Struct `WellnessStoreErasureTests` di bagian bawah disalin **apa adanya** dari berkas lama; struct itu dihapus nanti di Task 7.

```swift
import Foundation
import Testing
@testable import Apl

@MainActor
private final class EraseLog {
    var entries: [String] = []
}

@MainActor
private final class SpyStore: LocallyErasable {
    let name: String
    let log: EraseLog
    private(set) var eraseCount = 0

    init(_ name: String, log: EraseLog) {
        self.name = name
        self.log = log
    }

    func eraseAllStoredData() {
        eraseCount += 1
        log.entries.append(name)
    }
}

@MainActor
struct EraseAllDataUseCaseTests {

    /// Inti dari UseCase ini: TIDAK ADA penyimpanan yang boleh terlewat, dan
    /// masing-masing dihapus tepat sekali.
    @Test func erasesEveryStoreExactlyOnce() async {
        let log = EraseLog()
        let stores = [SpyStore("a", log: log), SpyStore("b", log: log), SpyStore("c", log: log)]

        let output = await EraseAllDataUseCase(stores: stores).execute()

        #expect(output.erasedStoreCount == 3)
        #expect(stores.allSatisfy { $0.eraseCount == 1 })
    }

    @Test func worksWithNoStores() async {
        let output = await EraseAllDataUseCase(stores: []).execute()
        #expect(output.erasedStoreCount == 0)
    }

    /// Notifikasi dibatalkan SETELAH data dihapus dan DITUNGGU sampai selesai —
    /// reminder lama tidak boleh tetap berbunyi setelah pengguna menghapus semuanya.
    @Test func clearsNotificationsAfterErasingStores() async {
        let log = EraseLog()
        let store = SpyStore("store", log: log)

        await EraseAllDataUseCase(stores: [store],
                                  clearNotifications: { log.entries.append("notifications") }).execute()

        #expect(log.entries == ["store", "notifications"])
    }
}

@MainActor
struct WellnessStoreErasureTests {

    /// Penjaga langsung untuk bug kedua: `WellnessStore` menulis ke suite app
    /// group, sementara penghapusan dulu menyasar `UserDefaults.standard` —
    /// nol data terhapus, nol error.
    ///
    /// Nama suite sengaja ditulis literal di sini. Itu justru invarian yang
    /// dijaga: penghapusan harus mengenai suite tempat data benar-benar ada,
    /// bukan suite mana pun yang kebetulan dipegang pemanggil.
    @Test func eraseTargetsTheAppGroupSuiteNotStandard() throws {
        let suiteName = "group.com.ega.apl"
        let suite = try #require(UserDefaults(suiteName: suiteName))

        let probeKey = "wellness.goalProgress"
        suite.set(Data([0x01]), forKey: probeKey)
        #expect(suite.object(forKey: probeKey) != nil)

        WellnessStore().eraseAllStoredData()

        #expect(suite.object(forKey: probeKey) == nil,
                "eraseAllStoredData tidak menyentuh suite tempat data sesungguhnya berada")
    }

    /// Setiap kunci yang didaftarkan store ikut terhapus — kunci baru yang lupa
    /// dimasukkan ke `Keys.all` akan ketahuan di sini.
    @Test func eraseClearsEveryDeclaredKey() throws {
        let suite = try #require(UserDefaults(suiteName: "group.com.ega.apl"))
        for key in WellnessStore.persistenceKeys {
            suite.set(Data([0x01]), forKey: key)
        }

        WellnessStore().eraseAllStoredData()

        for key in WellnessStore.persistenceKeys {
            #expect(suite.object(forKey: key) == nil, "kunci \(key) tertinggal")
        }
    }
}
```

Tambahkan test ini di dalam `struct BuddySettingsStoreTests` pada `DinoPocketTests/PhaseAComponentTests.swift`, tepat setelah `keepOnTopDefaultsTrueWhenNeverSet()`:

```swift
    /// Erase All Data mengembalikan preferensi karakter ke bawaan dan tidak
    /// meninggalkan kuncinya di disk.
    @MainActor @Test func eraseRestoresDefaultsAndRemovesKeys() {
        let defaults = isolatedDefaults(#function)
        let store = BuddySettingsStore(defaults: defaults)
        store.size = 240
        store.opacity = 0.5
        store.keepOnTop = false
        store.strolling = true

        store.eraseAllStoredData()

        #expect(store.size == BuddySettingsStore.defaultSize)
        #expect(store.opacity == 1.0)
        #expect(store.keepOnTop == true)
        #expect(store.strolling == false)
        for key in ["buddy.size", "buddy.opacity", "buddy.keepOnTop", "buddy.strolling"] {
            #expect(defaults.object(forKey: key) == nil, "kunci \(key) tertinggal")
        }
    }
```

- [ ] **Step 6: Jalankan dan pastikan gagal**

Run: `xcodegen generate`, lalu perintah Test semua.
Expected: FAIL, kompilasi gagal dengan `cannot find 'EraseAllDataUseCase' in scope` dan `value of type 'BuddySettingsStore' has no member 'eraseAllStoredData'`.

- [ ] **Step 7: Implementasikan `EraseAllDataUseCase`**

```bash
git mv SharedCore/Domain/UseCases/DeleteAccountUseCase.swift SharedCore/Domain/UseCases/EraseAllDataUseCase.swift
```

Ganti seluruh isi `SharedCore/Domain/UseCases/EraseAllDataUseCase.swift`:

```swift
//
//  EraseAllDataUseCase.swift
//  SharedCore
//
//  Menghapus seluruh data lokal Apl — menggantikan "hapus akun" sejak Sign in
//  with Apple dihapus (spec A §5).
//
//  Ada sebagai UseCase, bukan metode di satu store, karena penghapusan
//  menyentuh banyak penyimpanan dan masing-masing tahu detailnya sendiri. Dua
//  bug lolos justru saat satu komponen menebak isi komponen lain:
//
//    1. Daftar kunci wellness disalin tangan ke store lain, salah nama
//       ("wellness.customSchedules" vs "pet.customSchedules") dan melewatkan
//       sembilan kunci.
//    2. Penghapusan menyasar `UserDefaults.standard` sementara datanya ada di
//       suite app group — nol data terhapus, nol error.
//
//  UseCase ini tidak tahu satu pun nama kunci. Ia hanya menyuruh tiap
//  penyimpanan memusnahkan miliknya sendiri.
//

import Foundation

/// Apa pun yang menyimpan data pribadi dan harus ikut musnah saat pengguna
/// menghapus semua data.
///
/// Tidak mensyaratkan `AnyObject`: transcript percakapan disimpan oleh sebuah
/// struct berbasis berkas, dan ia HARUS bisa ikut dimusnahkan. Celah ketiga di
/// jalur ini muncul persis karena penyimpanan baru lupa didaftarkan.
@MainActor
protocol LocallyErasable {
    func eraseAllStoredData()
}

@MainActor
struct EraseAllDataUseCase {

    private let stores: [any LocallyErasable]
    private let clearNotifications: (() async -> Void)?

    /// - Parameters:
    ///   - stores: setiap penyimpanan yang memegang data pribadi.
    ///   - clearNotifications: pembatalan notifikasi terjadwal. Ditunggu sampai
    ///     selesai, supaya reminder lama tidak berbunyi setelah data dihapus.
    init(stores: [any LocallyErasable],
         clearNotifications: (() async -> Void)? = nil) {
        self.stores = stores
        self.clearNotifications = clearNotifications
    }

    struct Output: Equatable {
        /// Berapa penyimpanan yang dimusnahkan — dipakai test untuk memastikan
        /// tidak ada yang diam-diam terlewat.
        let erasedStoreCount: Int
    }

    @discardableResult
    func execute() async -> Output {
        for store in stores {
            store.eraseAllStoredData()
        }
        await clearNotifications?()
        return Output(erasedStoreCount: stores.count)
    }
}
```

- [ ] **Step 8: Jadikan `BuddySettingsStore` bisa dihapus**

Tambahkan di akhir `DinoPocketMac/Infrastructure/Persistence/BuddySettingsStore.swift` (satu berkas, jadi `Keys` dan `defaults` yang `private` tetap bisa diakses):

```swift

extension BuddySettingsStore: LocallyErasable {
    /// Preferensi kembali ke bawaan, dan kuncinya ikut dibuang. Mengeset nilai
    /// memicu `didSet` yang menulis ulang kunci, jadi penghapusan kunci harus
    /// terjadi SETELAH nilai dikembalikan.
    @MainActor
    func eraseAllStoredData() {
        size = Self.defaultSize
        opacity = 1.0
        keepOnTop = true
        strolling = false
        for key in [Keys.size, Keys.opacity, Keys.keepOnTop, Keys.strolling] {
            defaults.removeObject(forKey: key)
        }
    }
}
```

- [ ] **Step 9: Tulis ulang `OnboardingView` tanpa langkah Sign in**

Ganti seluruh isi `DinoPocketMac/Presentation/Views/OnboardingView.swift`:

```swift
//
//  OnboardingView.swift
//  AplMac
//
//  Alur perkenalan sekali jalan: sambutan + nama panggilan → izin notifikasi
//  → status Apple Intelligence. Tanpa akun.
//
//  Tampilan ini sementara; sub-project B memolesnya.
//

import SwiftUI
import UserNotifications

struct OnboardingView: View {

    let profile: ProfileStore
    let chat: ChatStore

    /// Dipanggil saat pengguna menekan "Allow notifications" dan macOS mengabulkan.
    var onNotificationsGranted: () async -> Void = {}

    @State private var step: Step = .welcome
    @State private var nicknameDraft = ""
    @State private var notificationDecision: NotificationDecision = .undecided
    @State private var appleAvailability: BrainAvailability?

    enum Step: Int, CaseIterable {
        case welcome, notifications, intelligence

        var title: String {
            switch self {
            case .welcome:       "Meet Apl"
            case .notifications: "Reminders"
            case .intelligence:  "On-device intelligence"
            }
        }
    }

    enum NotificationDecision {
        case undecided, granted, denied
    }

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)

            Divider()
            footer
                .padding(20)
        }
        .frame(width: 520, height: 460)
        .task { appleAvailability = await chat.availability(of: .apple) }
    }

    // MARK: - Steps

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)

            switch step {
            case .welcome:
                icon("sparkles")
                heading(step.title)
                body("A small robot that lives on your desktop, chats with you, and keeps "
                     + "your reminders. Everything runs on this Mac.")

                TextField("What should I call you?", text: $nicknameDraft)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 260)
                    .onSubmit { goForward() }

            case .notifications:
                icon("bell.badge")
                heading(step.title)
                body("Ask Apl to remind you about anything. Reminders arrive as "
                     + "notifications, so Apl needs your permission to show them.")

                switch notificationDecision {
                case .undecided:
                    Button("Allow notifications") { Task { await requestNotifications() } }
                        .buttonStyle(.borderedProminent)
                case .granted:
                    Label("Notifications on", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .denied:
                    Text("You can turn these on later in System Settings › Notifications.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

            case .intelligence:
                icon("brain")
                heading(step.title)
                body("Chat runs on Apple Intelligence, on this Mac. No account, no "
                     + "network, nothing leaves the device.")

                switch appleAvailability {
                case .ready:
                    Label("Apple Intelligence is ready", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .needsSetup(let reason), .unavailable(let reason):
                    VStack(spacing: 6) {
                        Label(reason, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("The character and reminders work regardless.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)
                case nil:
                    ProgressView().controlSize(.small)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var footer: some View {
        HStack {
            // Titik langkah, supaya pengguna tahu alurnya pendek.
            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.rawValue) { s in
                    Circle()
                        .fill(s == step ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 7, height: 7)
                }
            }

            Spacer()

            if step != .welcome {
                Button("Back") { goBack() }
            }

            Button(step == .intelligence ? "Start" : "Continue") { goForward() }
                .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Actions

    private func goForward() {
        switch step {
        case .welcome:
            profile.setNickname(nicknameDraft)
        case .intelligence:
            profile.completeOnboarding()
            return
        case .notifications:
            break
        }
        if let next = Step(rawValue: step.rawValue + 1) {
            withAnimation(.easeInOut(duration: 0.18)) { step = next }
        }
    }

    private func goBack() {
        if let prev = Step(rawValue: step.rawValue - 1) {
            withAnimation(.easeInOut(duration: 0.18)) { step = prev }
        }
    }

    private func requestNotifications() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        notificationDecision = granted ? .granted : .denied
        if granted { await onNotificationsGranted() }
    }

    // MARK: - Bits

    private func icon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 44, weight: .light))
            .foregroundStyle(Color.accentColor)
    }

    private func heading(_ text: String) -> some View {
        Text(text).font(.title2.weight(.semibold))
    }

    private func body(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 380)
    }
}

#Preview {
    OnboardingView(profile: ProfileStore(), chat: ChatStore(brains: [:]))
}
```

- [ ] **Step 10: Ganti bagian Account di `SettingsPage` dengan Profile + Erase All Data**

Di `DinoPocketMac/Presentation/Views/SettingsPage.swift`:

(a) Ganti:

```swift
    @Bindable var buddySettings: BuddySettingsStore
    @Bindable var account: AccountStore
    /// Penyimpanan tambahan dari composition root (mis. transcript percakapan).
    var extraErasableStores: [any LocallyErasable] = []

    @State private var appleAvailability: BrainAvailability?
    @State private var showDeleteConfirm = false
```

dengan:

```swift
    @Bindable var buddySettings: BuddySettingsStore
    let profile: ProfileStore
    /// Penyimpanan tambahan dari composition root (mis. transcript percakapan).
    var extraErasableStores: [any LocallyErasable] = []

    @State private var appleAvailability: BrainAvailability?
    @State private var showEraseConfirm = false
    @State private var nicknameDraft = ""
```

(b) Ganti seluruh blok `Section("Account") { ... }` (dari `Section("Account") {` sampai `}` penutupnya, setelah tombol `Delete Account and Data`) dengan:

```swift
            Section("Profile") {
                // Disimpan setiap kali draft berubah. Normalisasi hanya mengenai
                // nilai yang disimpan, bukan teks di kolom, jadi spasi yang sedang
                // diketik tidak termakan.
                //
                // SENGAJA tidak menyimpan saat halaman ditutup: Erase All Data
                // mengganti dashboard dengan onboarding, dan penyimpanan di
                // `onDisappear` menulis ulang nama tepat setelah dihapus.
                TextField("Nickname", text: $nicknameDraft, prompt: Text("What should Apl call you?"))
                    .onChange(of: nicknameDraft) { _, draft in profile.setNickname(draft) }

                Button("Erase All Data…", role: .destructive) {
                    showEraseConfirm = true
                }
            }
```

(c) Ganti:

```swift
                Text("Apl runs entirely on this Mac. No account data, wellness "
                     + "history, or conversation ever leaves the device.")
```

dengan:

```swift
                Text("Apl runs entirely on this Mac. Nothing you tell it ever leaves the device.")
```

(d) Ganti seluruh blok `.confirmationDialog("Delete account and all local data?", ...) { ... } message: { ... }` dengan:

```swift
        .confirmationDialog("Erase all data on this Mac?",
                            isPresented: $showEraseConfirm, titleVisibility: .visible) {
            Button("Erase Everything", role: .destructive) {
                // Tiap penyimpanan memusnahkan miliknya sendiri; UseCase ini
                // tidak tahu satu pun nama kunci atau suite.
                let stores: [any LocallyErasable] =
                    [profile, wellness.erasableStore, chat, buddySettings] + extraErasableStores
                let useCase = EraseAllDataUseCase(
                    stores: stores,
                    clearNotifications: { await WellnessNotificationCenter.shared.clearScheduledReminders() }
                )
                Task { await useCase.execute() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes your conversation, reminders, and preferences from this Mac. "
                 + "It can't be undone.")
        }
```

> Catatan pelaksanaan: versi awal rencana ini menyimpan nama di `.onDisappear`. Verifikasi
> manual di Task 9 menemukan bahwa itu menulis ulang nama setelah Erase All Data, jadi
> penyimpanan dipindah ke `.onChange(of: nicknameDraft)`.

(e) Di `.task { ... }`, tambahkan baris pertama:

```swift
            nicknameDraft = profile.nickname ?? ""
```

(f) Ganti preview:

```swift
        SettingsPage(chat: ChatStore(brains: [:]), wellness: .preview, buddySettings: BuddySettingsStore(), account: AccountStore())
```

dengan:

```swift
        SettingsPage(chat: ChatStore(brains: [:]), wellness: .preview, buddySettings: BuddySettingsStore(), profile: ProfileStore())
```

- [ ] **Step 11: Sambungkan `ProfileStore` di dashboard dan app**

`DinoPocketMac/Presentation/Views/DashboardTemplate.swift`:
- Ganti `    @Bindable var account: AccountStore` dengan `    let profile: ProfileStore`
- Ganti `HomePage(wellness: wellness, chat: chat, greetingName: account.firstName,` dengan `HomePage(wellness: wellness, chat: chat, greetingName: profile.nickname,`
- Ganti `SettingsPage(chat: chat, wellness: wellness, buddySettings: buddySettings, account: account,` dengan `SettingsPage(chat: chat, wellness: wellness, buddySettings: buddySettings, profile: profile,`
- Ganti `account: AccountStore())` pada `#Preview` dengan `profile: ProfileStore())`

`DinoPocketMac/Presentation/Views/HomePage.swift`, ganti:

```swift
    /// Nama dari Sign in with Apple. `nil` saat user menyembunyikan namanya —
    /// sapaannya lalu jatuh ke bentuk tanpa nama, bukan ke nama orang lain.
```

dengan:

```swift
    /// Nama panggilan dari onboarding. `nil` bila pengguna tidak mengisinya —
    /// sapaannya lalu jatuh ke bentuk tanpa nama.
```

`DinoPocketMac/App/AplApp.swift`:
- Ganti `    @State private var account = deps.account` dengan `    @State private var profile = deps.profile`
- Hapus baris `                    await account.refreshCredentialState()`
- Ganti `        if account.isSignedIn && account.hasCompletedOnboarding {` dengan `        if profile.hasCompletedOnboarding {`
- Ganti `            OnboardingView(account: account, chat: chat,` dengan `            OnboardingView(profile: profile, chat: chat,`
- Ganti `            account: account,` (di dalam `DashboardTemplate(`) dengan `            profile: profile,`

`DinoPocketMac/App/AppDependencies.swift`:
- Ganti `    let account: AccountStore` dengan `    let profile: ProfileStore`
- Ganti `            account: AccountStore(),` dengan `            profile: ProfileStore(),`

`DinoPocketTests/RemindersWiringTests.swift`: hapus seluruh suite `@Suite("Sapaan dashboard") struct GreetingNameTests { ... }`, mulai dari baris `@Suite("Sapaan dashboard")` sampai akhir berkas.

- [ ] **Step 12: Hapus akun, Keychain, dan entitlement SIWA**

```bash
git rm DinoPocketMac/Infrastructure/Persistence/AccountStore.swift \
       DinoPocketMac/Infrastructure/Persistence/KeychainStore.swift \
       DinoPocketMac/DinoPocketMac.entitlements
```

Di `project.yml`:
- Hapus baris `          - "DinoPocketMac.entitlements"` dari `excludes`.
- Hapus seluruh blok `configs:` di target `DinoPocketMac`, dari baris `      configs:` sampai baris `          CODE_SIGN_ENTITLEMENTS: DinoPocketMac/DinoPocketMac.entitlements`. Blok ini berisi komentar "Entitlement Sign in with Apple HANYA di Release." dan `Release:`. Baris kosong sebelum `  DinoPocketTests:` tetap dipertahankan.

- [ ] **Step 13: Generate, build, dan jalankan seluruh test**

Run: `xcodegen generate`, lalu Build, lalu Test semua.
Expected: `** BUILD SUCCEEDED **`; test sekitar `82 tests in 19 suites passed`; `** TEST SUCCEEDED **`.

- [ ] **Step 14: Pastikan tidak ada sisa akun**

Run:

```bash
grep -rnE "AccountStore|KeychainStore|ASAuthorization|AuthenticationServices|DeleteAccountUseCase|signOut|applesignin" \
  DinoPocketMac SharedCore DinoPocketTests project.yml --include='*.swift' --include='*.yml' --include='*.entitlements' \
  | grep -vE "Legacy/|ContentView|PetActivityWidgets|Haptics.swift"
```

Expected: tidak ada output. (`scripts/verify-release.sh` masih memeriksa SIWA dan akan gagal sampai Task 9. Itu memang direncanakan.)

- [ ] **Step 15: Commit**

```bash
git add -A DinoPocketMac SharedCore DinoPocketTests project.yml
git commit -m "$(cat <<'EOF'
feat(a1): hapus Sign in with Apple — ProfileStore dan Erase All Data

App on-device tanpa server tidak butuh akun; login wajib berisiko
Guideline 5.1.1(v). AccountStore diganti ProfileStore (nama panggilan +
status onboarding, kunci UserDefaults tetap), DeleteAccountUseCase
menjadi EraseAllDataUseCase yang menunggu pembatalan notifikasi, dan
BuddySettingsStore ikut terhapus. Entitlement SIWA dan KeychainStore
dibuang.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Model `Reminder` dan `ReminderStore` (aditif)

**Files:**
- Create: `SharedCore/Data/Models/Reminder.swift`
- Create: `SharedCore/Infrastructure/Persistence/ReminderStore.swift`
- Create: `DinoPocketTests/TestTime.swift`
- Create: `DinoPocketTests/ReminderTests.swift`
- Create: `DinoPocketTests/ReminderStoreTests.swift`

**Interfaces:**
- Consumes: `LocallyErasable` (Task 2).
- Produces:
  - `struct Reminder: Codable, Equatable, Identifiable, Sendable` dengan `enum Rule: Codable, Equatable, Sendable { case once(Date); case daily(hour: Int, minute: Int) }`, `let id: UUID`, `var title: String`, `var rule: Rule`, `let createdAt: Date`, `init(id: UUID = UUID(), title: String, rule: Rule, createdAt: Date = .now)`, `func nextOccurrence(after now: Date, calendar: Calendar = .current) -> Date?`
  - `@MainActor protocol ReminderStoring: AnyObject, LocallyErasable` dengan `var reminders: [Reminder] { get }`, `func add(_:)`, `func update(_:)`, `func remove(id: Reminder.ID)`
  - `@MainActor @Observable final class ReminderStore: ReminderStoring` dengan `init(defaults: UserDefaults = .standard, now: Date = .now)`, `static let storageKey = "apl.reminders"`, `static let pruneAge: TimeInterval`
  - Test helper `enum TestTime` dengan `calendar` (Gregorian, `Asia/Jakarta`), `locale` (`en_US`), `now` (Rabu 16 Sep 2026 10.00), `date(_:_:_:_:_:)`

- [ ] **Step 1: Buat helper waktu tetap untuk test**

Buat `DinoPocketTests/TestTime.swift`:

```swift
import Foundation

/// Kalender, locale, dan "sekarang" yang tetap, supaya test waktu tidak
/// bergantung pada zona waktu atau jam mesin yang menjalankannya.
///
/// Asia/Jakarta dipilih karena tidak punya daylight saving: satu hari
/// selalu 24 jam, sehingga "besok jam 9" tidak pernah bergeser.
enum TestTime {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Jakarta")!
        return calendar
    }()

    static let locale = Locale(identifier: "en_US")

    /// Rabu, 16 September 2026, 10.00 WIB.
    static let now = date(2026, 9, 16, 10, 0)

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}
```

- [ ] **Step 2: Tulis test model yang gagal**

Buat `DinoPocketTests/ReminderTests.swift`:

```swift
import Foundation
import Testing
@testable import Apl

struct ReminderTests {

    private let calendar = TestTime.calendar

    @Test func onceInTheFutureIsItsOwnDate() {
        let at = TestTime.date(2026, 9, 16, 15, 0)
        let reminder = Reminder(title: "Call mom", rule: .once(at))
        #expect(reminder.nextOccurrence(after: TestTime.now, calendar: calendar) == at)
    }

    @Test func onceInThePastHasNoNextOccurrence() {
        let reminder = Reminder(title: "Call mom", rule: .once(TestTime.date(2026, 9, 16, 9, 0)))
        #expect(reminder.nextOccurrence(after: TestTime.now, calendar: calendar) == nil)
    }

    @Test func dailyLaterTodayIsToday() {
        let reminder = Reminder(title: "Stretch", rule: .daily(hour: 15, minute: 30))
        #expect(reminder.nextOccurrence(after: TestTime.now, calendar: calendar)
                == TestTime.date(2026, 9, 16, 15, 30))
    }

    @Test func dailyAlreadyPassedIsTomorrow() {
        let reminder = Reminder(title: "Stretch", rule: .daily(hour: 9, minute: 0))
        #expect(reminder.nextOccurrence(after: TestTime.now, calendar: calendar)
                == TestTime.date(2026, 9, 17, 9, 0))
    }

    /// Tepat di menit yang sama berarti kemunculan hari ini sudah terjadi.
    @Test func dailyAtTheCurrentMinuteIsTomorrow() {
        let reminder = Reminder(title: "Stretch", rule: .daily(hour: 10, minute: 0))
        #expect(reminder.nextOccurrence(after: TestTime.now, calendar: calendar)
                == TestTime.date(2026, 9, 17, 10, 0))
    }

    @Test func dailyCrossesMidnight() {
        let lateNight = TestTime.date(2026, 9, 16, 23, 30)
        let reminder = Reminder(title: "Sleep", rule: .daily(hour: 0, minute: 15))
        #expect(reminder.nextOccurrence(after: lateNight, calendar: calendar)
                == TestTime.date(2026, 9, 17, 0, 15))
    }

    @Test func bothRulesRoundTripThroughCodable() throws {
        let reminders = [
            Reminder(title: "Call mom", rule: .once(TestTime.date(2026, 9, 16, 15, 0)), createdAt: TestTime.now),
            Reminder(title: "Stretch", rule: .daily(hour: 9, minute: 0), createdAt: TestTime.now),
        ]
        let data = try JSONEncoder().encode(reminders)
        #expect(try JSONDecoder().decode([Reminder].self, from: data) == reminders)
    }
}
```

- [ ] **Step 3: Jalankan dan pastikan gagal**

Run: `xcodegen generate`, lalu Test dengan `-only-testing:DinoPocketTests/ReminderTests`
Expected: FAIL, `cannot find 'Reminder' in scope`.

- [ ] **Step 4: Implementasikan `Reminder`**

Buat `SharedCore/Data/Models/Reminder.swift`:

```swift
//
//  Reminder.swift
//  SharedCore
//
//  Reminder yang dibuat pengguna lewat chat.
//
//  Menggantikan ReminderSchedule, yang hanya menyimpan jam dan menit sehingga
//  "remind me at 3 PM" diam-diam berulang setiap hari (spec A §1).
//

import Foundation

struct Reminder: Codable, Equatable, Identifiable, Sendable {

    enum Rule: Codable, Equatable, Sendable {
        /// Sekali jalan, pada tanggal dan jam tertentu.
        case once(Date)
        /// Setiap hari pada jam dan menit yang sama.
        case daily(hour: Int, minute: Int)
    }

    let id: UUID
    var title: String
    var rule: Rule
    let createdAt: Date

    init(id: UUID = UUID(), title: String, rule: Rule, createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.rule = rule
        self.createdAt = createdAt
    }

    /// Kemunculan berikutnya SETELAH `now`.
    ///
    /// `.once` yang sudah lewat → nil. `.daily` → hari ini bila jamnya belum
    /// lewat, selain itu besok. Tepat di menit yang sama dianggap sudah lewat.
    func nextOccurrence(after now: Date, calendar: Calendar = .current) -> Date? {
        switch rule {
        case .once(let date):
            return date > now ? date : nil
        case .daily(let hour, let minute):
            guard let today = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) else {
                return nil
            }
            return today > now ? today : calendar.date(byAdding: .day, value: 1, to: today)
        }
    }
}
```

- [ ] **Step 5: Jalankan test model**

Run: `xcodegen generate`, lalu Test dengan `-only-testing:DinoPocketTests/ReminderTests`
Expected: 7 test PASS.

- [ ] **Step 6: Tulis test store yang gagal**

Buat `DinoPocketTests/ReminderStoreTests.swift`:

```swift
import Foundation
import Testing
@testable import Apl

@MainActor
struct ReminderStoreTests {

    private func isolatedDefaults(_ name: String) -> UserDefaults {
        let suite = "test.reminders.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func reminder(_ title: String, _ rule: Reminder.Rule) -> Reminder {
        Reminder(title: title, rule: rule, createdAt: TestTime.now)
    }

    @Test func addedRemindersSurviveRelaunch() {
        let defaults = isolatedDefaults(#function)
        let stretch = reminder("Stretch", .daily(hour: 9, minute: 0))

        ReminderStore(defaults: defaults, now: TestTime.now).add(stretch)

        #expect(ReminderStore(defaults: defaults, now: TestTime.now).reminders == [stretch])
    }

    @Test func updateReplacesTheReminderWithTheSameID() {
        let defaults = isolatedDefaults(#function)
        let store = ReminderStore(defaults: defaults, now: TestTime.now)
        var call = reminder("Call mom", .once(TestTime.date(2026, 9, 16, 15, 0)))
        store.add(call)

        call.title = "Call dad"
        store.update(call)

        #expect(store.reminders == [call])
        #expect(ReminderStore(defaults: defaults, now: TestTime.now).reminders == [call])
    }

    @Test func removeDeletesOnlyThatReminder() {
        let defaults = isolatedDefaults(#function)
        let store = ReminderStore(defaults: defaults, now: TestTime.now)
        let keep = reminder("Stretch", .daily(hour: 9, minute: 0))
        let drop = reminder("Call mom", .once(TestTime.date(2026, 9, 16, 15, 0)))
        store.add(keep)
        store.add(drop)

        store.remove(id: drop.id)

        #expect(store.reminders == [keep])
        #expect(ReminderStore(defaults: defaults, now: TestTime.now).reminders == [keep])
    }

    /// Reminder sekali jalan yang lewat lebih dari sehari hanya mengotori
    /// daftar; yang baru lewat dipertahankan, dan pemangkasan ikut tersimpan.
    @Test func onceRemindersPastForMoreThanADayArePrunedOnLoad() {
        let defaults = isolatedDefaults(#function)
        let stale = reminder("Old", .once(TestTime.now.addingTimeInterval(-25 * 3600)))
        let recent = reminder("Recent", .once(TestTime.now.addingTimeInterval(-3600)))
        let daily = reminder("Daily", .daily(hour: 9, minute: 0))
        let earlier = TestTime.now.addingTimeInterval(-30 * 3600)
        let seeding = ReminderStore(defaults: defaults, now: earlier)
        for item in [stale, recent, daily] {
            seeding.add(item)
        }

        let reloaded = ReminderStore(defaults: defaults, now: TestTime.now)

        #expect(reloaded.reminders == [recent, daily])
        // Dimuat lagi dengan "sekarang" yang lebih awal: stale tetap hilang,
        // artinya hasil pemangkasan benar-benar ditulis ke disk.
        #expect(ReminderStore(defaults: defaults, now: earlier).reminders == [recent, daily])
    }

    @Test func eraseClearsMemoryAndDisk() {
        let defaults = isolatedDefaults(#function)
        let store = ReminderStore(defaults: defaults, now: TestTime.now)
        store.add(reminder("Stretch", .daily(hour: 9, minute: 0)))

        store.eraseAllStoredData()

        #expect(store.reminders.isEmpty)
        #expect(defaults.object(forKey: ReminderStore.storageKey) == nil)
    }
}
```

- [ ] **Step 7: Jalankan dan pastikan gagal**

Run: `xcodegen generate`, lalu Test dengan `-only-testing:DinoPocketTests/ReminderStoreTests`
Expected: FAIL, `cannot find 'ReminderStore' in scope`.

- [ ] **Step 8: Implementasikan `ReminderStore`**

Buat `SharedCore/Infrastructure/Persistence/ReminderStore.swift`:

```swift
//
//  ReminderStore.swift
//  SharedCore
//
//  Penyimpanan reminder, terpisah dari wellness (spec A §4).
//
//  `UserDefaults.standard`, bukan suite app group: tidak ada widget di v1,
//  jadi tidak ada proses lain yang perlu membaca data ini.
//

import Foundation
import Observation

@MainActor
protocol ReminderStoring: AnyObject, LocallyErasable {
    var reminders: [Reminder] { get }
    func add(_ reminder: Reminder)
    func update(_ reminder: Reminder)
    func remove(id: Reminder.ID)
}

@MainActor
@Observable
final class ReminderStore: ReminderStoring {

    nonisolated static let storageKey = "apl.reminders"

    /// Reminder `.once` yang lewat lebih lama dari ini dibuang saat dimuat.
    nonisolated static let pruneAge: TimeInterval = 24 * 60 * 60

    private(set) var reminders: [Reminder]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard, now: Date = .now) {
        self.defaults = defaults
        let stored = defaults.data(forKey: Self.storageKey)
            .flatMap { try? JSONDecoder().decode([Reminder].self, from: $0) } ?? []
        self.reminders = Self.pruned(stored, now: now)
        if reminders.count != stored.count {
            save()
        }
    }

    nonisolated static func pruned(_ reminders: [Reminder], now: Date) -> [Reminder] {
        reminders.filter { reminder in
            guard case .once(let date) = reminder.rule else { return true }
            return now.timeIntervalSince(date) <= pruneAge
        }
    }

    func add(_ reminder: Reminder) {
        reminders.append(reminder)
        save()
    }

    func update(_ reminder: Reminder) {
        guard let index = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        reminders[index] = reminder
        save()
    }

    func remove(id: Reminder.ID) {
        reminders.removeAll { $0.id == id }
        save()
    }

    func eraseAllStoredData() {
        reminders = []
        defaults.removeObject(forKey: Self.storageKey)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(reminders) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
```

- [ ] **Step 9: Jalankan test store dan seluruh test**

Run: `xcodegen generate`, lalu Test dengan `-only-testing:DinoPocketTests/ReminderStoreTests` (5 PASS), lalu Test semua dan `./scripts/verify-boundaries.sh`.
Expected: sekitar `94 tests in 21 suites passed`, `** TEST SUCCEEDED **`, `✅ batas SharedCore aman`.

- [ ] **Step 10: Commit**

```bash
git add SharedCore/Data/Models/Reminder.swift SharedCore/Infrastructure/Persistence/ReminderStore.swift \
        DinoPocketTests/TestTime.swift DinoPocketTests/ReminderTests.swift DinoPocketTests/ReminderStoreTests.swift
git commit -m "$(cat <<'EOF'
feat(a4): model Reminder sekali/harian dan ReminderStore

Aditif: belum dipakai chat. ReminderSchedule hanya menyimpan jam dan
menit, sehingga "at 3 PM" diam-diam berulang tiap hari; Reminder.Rule
membedakan .once dan .daily, dan ReminderStore membuang reminder
sekali jalan yang lewat lebih dari sehari.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: `ReminderParser` (aditif)

**Files:**
- Create: `SharedCore/Infrastructure/Services/ReminderParser.swift`
- Create: `DinoPocketTests/ReminderParserTests.swift`

**Interfaces:**
- Consumes: `Reminder.Rule` (Task 3), `TestTime` (Task 3).
- Produces:
  - `enum ReminderParseResult: Equatable, Sendable { case reminder(title: String, rule: Reminder.Rule); case missingTime(title: String?); case notAReminder }`
  - `enum ReminderParser` dengan `static let defaultTitle = "Reminder"`, `static func parse(_ text: String, now: Date, calendar: Calendar = .current) -> ReminderParseResult`, `static func parseTimeOnly(_ text: String, now: Date, calendar: Calendar = .current) -> Reminder.Rule?`

- [ ] **Step 1: Tulis test parser yang gagal**

Buat `DinoPocketTests/ReminderParserTests.swift`:

```swift
import Foundation
import Testing
@testable import Apl

struct ReminderParseCase: Sendable, CustomTestStringConvertible {
    let input: String
    let expected: ReminderParseResult
    var testDescription: String { input }

    init(_ input: String, _ expected: ReminderParseResult) {
        self.input = input
        self.expected = expected
    }
}

struct TimeOnlyCase: Sendable, CustomTestStringConvertible {
    let input: String
    let expected: Reminder.Rule?
    var testDescription: String { input }

    init(_ input: String, _ expected: Reminder.Rule?) {
        self.input = input
        self.expected = expected
    }
}

/// "Sekarang" = Rabu 16 Sep 2026 10.00 WIB (`TestTime.now`).
struct ReminderParserTests {

    private static func on(_ day: Int, _ hour: Int, _ minute: Int) -> Date {
        TestTime.date(2026, 9, day, hour, minute)
    }

    private static func fromNow(_ seconds: TimeInterval) -> Date {
        TestTime.now.addingTimeInterval(seconds)
    }

    static let reminderCases: [ReminderParseCase] = [
        .init("remind me to call mom at 3pm", .reminder(title: "Call mom", rule: .once(on(16, 15, 0)))),
        .init("Remind me to call Mom at 3:30 PM", .reminder(title: "Call Mom", rule: .once(on(16, 15, 30)))),
        .init("remind me to call mom at 15:00", .reminder(title: "Call mom", rule: .once(on(16, 15, 0)))),
        .init("remind me to stretch at 9am", .reminder(title: "Stretch", rule: .once(on(17, 9, 0)))),
        .init("remind me today at 9am to stretch", .reminder(title: "Stretch", rule: .once(on(17, 9, 0)))),
        .init("remind me tomorrow at 9 to send the report",
              .reminder(title: "Send the report", rule: .once(on(17, 9, 0)))),
        .init("remind me in 20 minutes to check the oven",
              .reminder(title: "Check the oven", rule: .once(fromNow(20 * 60)))),
        .init("remind me in an hour to take a break",
              .reminder(title: "Take a break", rule: .once(fromNow(3600)))),
        .init("remind me in 1 minute to breathe", .reminder(title: "Breathe", rule: .once(fromNow(60)))),
        .init("remind me in a minute to stand up", .reminder(title: "Stand up", rule: .once(fromNow(60)))),
        .init("remind me in 2 hours to call dad", .reminder(title: "Call dad", rule: .once(fromNow(7200)))),
        .init("remind me every day at 9am to stretch", .reminder(title: "Stretch", rule: .daily(hour: 9, minute: 0))),
        .init("remind me daily at 21:30 to journal", .reminder(title: "Journal", rule: .daily(hour: 21, minute: 30))),
        .init("remind me at 8pm every day to read", .reminder(title: "Read", rule: .daily(hour: 20, minute: 0))),
        .init("set a reminder to stretch at 09:30", .reminder(title: "Stretch", rule: .once(on(17, 9, 30)))),
        .init("remind me to drink water at 12am", .reminder(title: "Drink water", rule: .once(on(17, 0, 0)))),
        .init("remind me to eat lunch at 12pm", .reminder(title: "Eat lunch", rule: .once(on(16, 12, 0)))),
        .init("Can you remind me to call mom at 3pm?", .reminder(title: "Call mom", rule: .once(on(16, 15, 0)))),
        .init("I want you to remind me to call mom at 3pm",
              .reminder(title: "Call mom", rule: .once(on(16, 15, 0)))),
        .init("at 5pm remind me to stretch", .reminder(title: "Stretch", rule: .once(on(16, 17, 0)))),
        .init("remind me to go to the gym at 6pm", .reminder(title: "Go to the gym", rule: .once(on(16, 18, 0)))),
        .init("remind me at 3pm", .reminder(title: "Reminder", rule: .once(on(16, 15, 0)))),
        .init("remind me to meet at the cafe at 5pm",
              .reminder(title: "Meet at the cafe", rule: .once(on(16, 17, 0)))),
    ]

    static let missingTimeCases: [ReminderParseCase] = [
        .init("remind me to drink water", .missingTime(title: "Drink water")),
        .init("remind me", .missingTime(title: nil)),
        .init("remind me tomorrow to call mom", .missingTime(title: "Call mom")),
        .init("remind me to call at 25:00", .missingTime(title: "Call at 25:00")),
    ]

    static let ordinaryChatCases: [ReminderParseCase] = [
        .init("what should I eat at 3pm?", .notAReminder),
        .init("I need to remember my keys", .notAReminder),
        .init("reminders are annoying", .notAReminder),
    ]

    static let timeOnlyCases: [TimeOnlyCase] = [
        .init("5pm", .once(on(16, 17, 0))),
        .init("at 5pm", .once(on(16, 17, 0))),
        .init("5pm.", .once(on(16, 17, 0))),
        .init("17:00", .once(on(16, 17, 0))),
        .init("in 10 minutes", .once(fromNow(600))),
        .init("tomorrow at 9", .once(on(17, 9, 0))),
        .init("every day at 9am", .daily(hour: 9, minute: 0)),
    ]

    static let notTimeOnlyCases: [TimeOnlyCase] = [
        .init("5", nil),
        .init("tell me a joke", nil),
        .init("5pm please", nil),
    ]

    @Test(arguments: ReminderParserTests.reminderCases)
    func parsesReminders(_ c: ReminderParseCase) {
        #expect(ReminderParser.parse(c.input, now: TestTime.now, calendar: TestTime.calendar) == c.expected)
    }

    @Test(arguments: ReminderParserTests.missingTimeCases)
    func detectsMissingTime(_ c: ReminderParseCase) {
        #expect(ReminderParser.parse(c.input, now: TestTime.now, calendar: TestTime.calendar) == c.expected)
    }

    @Test(arguments: ReminderParserTests.ordinaryChatCases)
    func ignoresOrdinaryChat(_ c: ReminderParseCase) {
        #expect(ReminderParser.parse(c.input, now: TestTime.now, calendar: TestTime.calendar) == c.expected)
    }

    @Test(arguments: ReminderParserTests.timeOnlyCases)
    func parsesTimeOnlyAnswers(_ c: TimeOnlyCase) {
        #expect(ReminderParser.parseTimeOnly(c.input, now: TestTime.now, calendar: TestTime.calendar) == c.expected)
    }

    @Test(arguments: ReminderParserTests.notTimeOnlyCases)
    func rejectsAnswersThatAreNotJustATime(_ c: TimeOnlyCase) {
        #expect(ReminderParser.parseTimeOnly(c.input, now: TestTime.now, calendar: TestTime.calendar) == nil)
    }
}
```

- [ ] **Step 2: Jalankan dan pastikan gagal**

Run: `xcodegen generate`, lalu Test dengan `-only-testing:DinoPocketTests/ReminderParserTests`
Expected: FAIL, `cannot find 'ReminderParser' in scope`.

- [ ] **Step 3: Implementasikan parser**

Buat `SharedCore/Infrastructure/Services/ReminderParser.swift`:

```swift
//
//  ReminderParser.swift
//  SharedCore
//
//  Mengurai permintaan reminder berbahasa Inggris, tanpa AI.
//
//  SENGAJA bukan tool call ke model. Parser ini punya dua sifat yang tidak
//  dimiliki model: hasilnya sama untuk input yang sama, dan ia tetap bekerja
//  saat Apple Intelligence mati. Reminder adalah janji ke pengguna; ia tidak
//  boleh ikut padam bersama AI.
//
//  Tata bahasa (spec A §4):
//    pemicu : "remind me" · "set a reminder"
//    waktu  : at 3pm · at 3:30 pm · at 15:00 · today at … · tomorrow at …
//             in 20 minutes · in an hour · every day at … · daily at …
//             at … every day
//    judul  : frasa setelah "to"/"about", tanpa bagian waktu
//
//  Angka polos tanpa am/pm dan tanpa titik dua hanya dianggap jam tepat
//  setelah "at", dan dibaca sebagai jam 24 ("at 9" = 09.00). Di luar itu
//  angka polos bukan waktu — "buy 2 apples" tidak boleh jadi reminder jam 2.
//

import Foundation

enum ReminderParseResult: Equatable, Sendable {
    case reminder(title: String, rule: Reminder.Rule)
    /// Ada niat reminder, tetapi waktunya tidak terbaca.
    case missingTime(title: String?)
    case notAReminder
}

enum ReminderParser {

    /// Judul bila pengguna tidak menyebut apa yang diingatkan.
    static let defaultTitle = "Reminder"

    static func parse(_ text: String, now: Date, calendar: Calendar = .current) -> ReminderParseResult {
        let patterns = Patterns()
        guard let trigger = patterns.trigger.firstMatch(in: text, range: fullRange(of: text)) else {
            return .notAReminder
        }

        let time = findTime(in: text, now: now, calendar: calendar, patterns: patterns)
        let title = extractTitle(from: text, trigger: trigger.range, time: time?.range, patterns: patterns)

        guard let time else { return .missingTime(title: title) }
        return .reminder(title: title ?? defaultTitle, rule: time.rule)
    }

    /// Untuk giliran lanjutan setelah Apl menanyakan jam: nil kecuali seluruh
    /// pesan hanyalah ungkapan waktu ("5pm", "at 5pm", "in 10 minutes").
    static func parseTimeOnly(_ text: String, now: Date, calendar: Calendar = .current) -> Reminder.Rule? {
        guard let time = findTime(in: text, now: now, calendar: calendar, patterns: Patterns()) else {
            return nil
        }
        let rest = NSMutableString(string: text)
        rest.replaceCharacters(in: time.range, with: "")
        let leftover = (rest as String).trimmingCharacters(in: edgeTrim).lowercased()
        return leftover.isEmpty || leftover == "at" ? time.rule : nil
    }

    // MARK: - Pola

    /// Dibangun per panggilan, bukan `static let`: `NSRegularExpression` tidak
    /// dijamin `Sendable`, dan properti statis bertipe non-Sendable ditolak
    /// Swift 6 — kesalahan yang persis pernah menggagalkan build proyek ini.
    /// Pesan chat jarang, jadi biayanya tidak terasa.
    private struct Patterns {
        /// Grup 1 jam, 2 menit, 3 am/pm — sama di setiap pola jam.
        static let clock = #"(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b"#

        let trigger = Patterns.make(#"\b(?:remind\s+me|set\s+(?:a\s+)?reminder)\b"#)
        let dailyLeading = Patterns.make(#"\b(?:every\s?day|daily)\s+at\s+"# + Patterns.clock)
        let dailyTrailing = Patterns.make(#"\bat\s+"# + Patterns.clock + #"\s+(?:every\s?day|daily)\b"#)
        let tomorrow = Patterns.make(#"\btomorrow\s+at\s+"# + Patterns.clock)
        let relative = Patterns.make(#"\bin\s+(\d{1,3}|an?|one)\s+(minutes?|mins?|hours?|hrs?)\b"#)
        let todayAt = Patterns.make(#"\btoday\s+at\s+"# + Patterns.clock)
        let at = Patterns.make(#"\bat\s+"# + Patterns.clock)
        let bare = Patterns.make(#"\b"# + Patterns.clock)
        let titleLead = Patterns.make(#"\b(?:to|about)\s+"#)

        private static func make(_ pattern: String) -> NSRegularExpression {
            // Pola literal yang dijaga test; kegagalan di sini adalah bug pengembang.
            try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        }
    }

    // MARK: - Waktu

    private struct TimeMatch {
        let range: NSRange
        let rule: Reminder.Rule
    }

    private struct Clock {
        let hour: Int
        let minute: Int
    }

    /// Urutan pola adalah prioritas: yang lebih spesifik ("every day at 9")
    /// harus menang atas yang lebih umum ("at 9") pada teks yang sama.
    private static func findTime(in text: String, now: Date, calendar: Calendar,
                                 patterns: Patterns) -> TimeMatch? {
        let range = fullRange(of: text)

        for pattern in [patterns.dailyLeading, patterns.dailyTrailing] {
            for match in pattern.matches(in: text, range: range) {
                if let clock = clock(from: match, in: text) {
                    return TimeMatch(range: match.range, rule: .daily(hour: clock.hour, minute: clock.minute))
                }
            }
        }

        for match in patterns.tomorrow.matches(in: text, range: range) {
            if let clock = clock(from: match, in: text),
               let date = tomorrow(at: clock, now: now, calendar: calendar) {
                return TimeMatch(range: match.range, rule: .once(date))
            }
        }

        for match in patterns.relative.matches(in: text, range: range) {
            if let seconds = seconds(from: match, in: text) {
                return TimeMatch(range: match.range, rule: .once(now.addingTimeInterval(seconds)))
            }
        }

        let clockPatterns: [(NSRegularExpression, requireMinuteOrMeridiem: Bool)] = [
            (patterns.todayAt, false),
            (patterns.at, false),
            (patterns.bare, true),
        ]
        for (pattern, strict) in clockPatterns {
            for match in pattern.matches(in: text, range: range) {
                if let clock = clock(from: match, in: text, requireMinuteOrMeridiem: strict),
                   let date = upcoming(clock, now: now, calendar: calendar) {
                    return TimeMatch(range: match.range, rule: .once(date))
                }
            }
        }

        return nil
    }

    private static func clock(from match: NSTextCheckingResult, in text: String,
                              requireMinuteOrMeridiem: Bool = false) -> Clock? {
        let ns = text as NSString
        let hourRange = match.range(at: 1)
        let minuteRange = match.range(at: 2)
        let meridiemRange = match.range(at: 3)
        guard hourRange.location != NSNotFound,
              var hour = Int(ns.substring(with: hourRange)) else { return nil }

        let hasMinute = minuteRange.location != NSNotFound
        let hasMeridiem = meridiemRange.location != NSNotFound
        if requireMinuteOrMeridiem && !hasMinute && !hasMeridiem { return nil }

        let minute = hasMinute ? (Int(ns.substring(with: minuteRange)) ?? -1) : 0
        if hasMeridiem {
            guard (1...12).contains(hour) else { return nil }
            let meridiem = ns.substring(with: meridiemRange).lowercased()
            if meridiem == "pm", hour < 12 { hour += 12 }
            if meridiem == "am", hour == 12 { hour = 0 }
        }
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return Clock(hour: hour, minute: minute)
    }

    private static func seconds(from match: NSTextCheckingResult, in text: String) -> TimeInterval? {
        let ns = text as NSString
        let amountText = ns.substring(with: match.range(at: 1)).lowercased()
        let amount: Int
        switch amountText {
        case "a", "an", "one":
            amount = 1
        default:
            guard let parsed = Int(amountText), parsed > 0 else { return nil }
            amount = parsed
        }
        let unit = ns.substring(with: match.range(at: 2)).lowercased()
        return TimeInterval(amount) * (unit.hasPrefix("h") ? 3600 : 60)
    }

    /// Hari ini bila jamnya belum lewat, selain itu besok — termasuk untuk
    /// "today at …": jam yang sudah lewat tidak mungkin diingatkan hari ini.
    private static func upcoming(_ clock: Clock, now: Date, calendar: Calendar) -> Date? {
        guard let today = calendar.date(bySettingHour: clock.hour, minute: clock.minute,
                                        second: 0, of: now) else { return nil }
        return today > now ? today : calendar.date(byAdding: .day, value: 1, to: today)
    }

    private static func tomorrow(at clock: Clock, now: Date, calendar: Calendar) -> Date? {
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else {
            return nil
        }
        return calendar.date(bySettingHour: clock.hour, minute: clock.minute, second: 0, of: nextDay)
    }

    // MARK: - Judul

    /// Judul dicari SETELAH pemicu: pada "I want you to remind me to call mom",
    /// "to" pertama milik kalimat pembuka, bukan awal judul.
    private static func extractTitle(from text: String, trigger: NSRange, time: NSRange?,
                                     patterns: Patterns) -> String? {
        let remaining = NSMutableString(string: text)
        var searchStart = trigger.location
        let ranges = [trigger] + (time.map { [$0] } ?? [])
        // Dari belakang ke depan, supaya lokasi rentang yang lebih awal tetap valid.
        // Setiap rentang diganti SATU spasi, jadi rentang yang terletak sebelum
        // pemicu menggeser posisi pemicu sebanyak panjangnya dikurangi satu.
        for range in ranges.sorted(by: { $0.location > $1.location }) {
            remaining.replaceCharacters(in: range, with: " ")
            if range.location < trigger.location {
                searchStart -= range.length - 1
            }
        }
        let stripped = remaining as String
        let length = (stripped as NSString).length
        let searchRange = NSRange(location: searchStart, length: length - searchStart)
        guard let lead = patterns.titleLead.firstMatch(in: stripped, range: searchRange) else {
            return nil
        }
        let afterLead = (stripped as NSString).substring(from: NSMaxRange(lead.range))
        let words = afterLead.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let title = words.trimmingCharacters(in: edgeTrim)
        guard let first = title.first else { return nil }
        return first.uppercased() + String(title.dropFirst())
    }

    private static let edgeTrim = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)

    private static func fullRange(of text: String) -> NSRange {
        NSRange(location: 0, length: (text as NSString).length)
    }
}
```

- [ ] **Step 4: Jalankan test parser**

Run: `xcodegen generate`, lalu Test dengan `-only-testing:DinoPocketTests/ReminderParserTests`
Expected: 5 test (40 kasus argumen) PASS. Kalau ada kasus yang gagal, perbaiki **parser**, bukan harapan di tabel. Tabel ini adalah tata bahasa yang disepakati di spec.

- [ ] **Step 5: Jalankan seluruh test dan batas SharedCore**

Run: Test semua, lalu `./scripts/verify-boundaries.sh`.
Expected: sekitar `99 tests in 22 suites passed`, `** TEST SUCCEEDED **`, `✅ batas SharedCore aman`.

- [ ] **Step 6: Commit**

```bash
git add SharedCore/Infrastructure/Services/ReminderParser.swift DinoPocketTests/ReminderParserTests.swift
git commit -m "$(cat <<'EOF'
feat(a4): ReminderParser — judul bebas, sekali jalan, harian, relatif

Aditif: belum dipakai chat. Parser lama hanya mengenal air, stretch,
dan makan, sehingga "remind me to call mom at 3pm" jatuh ke AI yang bisa
mengaku sudah membuat reminder. Parser baru membedakan reminder lengkap,
reminder tanpa jam, dan obrolan biasa, serta mengurai jawaban yang
hanya berisi waktu untuk giliran lanjutan.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Penjadwal notifikasi, kalimat konfirmasi, batal & ubah reminder (aditif)

**Files:**
- Create: `SharedCore/Infrastructure/Services/ReminderScheduling.swift`
- Create: `SharedCore/Infrastructure/Services/ReminderNotificationCenter.swift`
- Create: `SharedCore/Domain/UseCases/ReminderPhrasing.swift`
- Create: `SharedCore/Domain/UseCases/CancelReminderUseCase.swift`
- Create: `SharedCore/Domain/UseCases/UpdateReminderUseCase.swift`
- Create: `DinoPocketTests/ReminderFakes.swift`
- Create: `DinoPocketTests/ReminderTriggersTests.swift`
- Create: `DinoPocketTests/ReminderPhrasingTests.swift`
- Create: `DinoPocketTests/ReminderEditingUseCaseTests.swift`

**Interfaces:**
- Consumes: `Reminder`, `ReminderStoring` (Task 3); `ReminderParser.defaultTitle` (Task 4); `TestTime` (Task 3).
- Produces:
  - `protocol ReminderScheduling: Sendable` dengan `func requestAuthorization() async -> Bool`, `func sync(_ reminders: [Reminder], now: Date) async`, `func cancelAll() async`
  - `struct ReminderTrigger: Equatable, Sendable { let identifier: String; let title: String; let components: DateComponents; let repeats: Bool }`
  - `enum ReminderTriggers` dengan `static let identifierPrefix = "apl.reminder."`, `static let maxScheduled = 60`, `static func plan(for:now:calendar:) -> [ReminderTrigger]`, `static func trigger(for:calendar:) -> ReminderTrigger`
  - `@MainActor final class ReminderNotificationCenter: ReminderScheduling` dengan `static let shared` dan `func configure()`
  - `enum ReminderPhrasing` dengan `static func confirmation(title:rule:now:calendar:locale:) -> String`, `static func timeQuestion(title: String?) -> String`, `static func time(_:calendar:locale:) -> String`
  - `@MainActor struct CancelReminderUseCase` dengan `init(store:notifications:now:)`, `func execute(id: Reminder.ID) async`
  - `@MainActor struct UpdateReminderUseCase` dengan `init(store:notifications:now:)`, `func execute(_ reminder: Reminder) async`
  - Test fakes `InMemoryReminderStore` (`@MainActor`, `ReminderStoring`) dan `SpyReminderScheduler` (`syncCallCount`, `lastSynced`, `cancelAllCallCount`, `authorizationAnswer`)

- [ ] **Step 1: Tulis fake dan test yang gagal**

Buat `DinoPocketTests/ReminderFakes.swift`:

```swift
import Foundation
@testable import Apl

@MainActor
final class InMemoryReminderStore: ReminderStoring {
    private(set) var reminders: [Reminder] = []

    func add(_ reminder: Reminder) {
        reminders.append(reminder)
    }

    func update(_ reminder: Reminder) {
        guard let index = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        reminders[index] = reminder
    }

    func remove(id: Reminder.ID) {
        reminders.removeAll { $0.id == id }
    }

    func eraseAllStoredData() {
        reminders = []
    }
}

final class SpyReminderScheduler: ReminderScheduling, @unchecked Sendable {
    private(set) var syncCallCount = 0
    private(set) var lastSynced: [Reminder] = []
    private(set) var cancelAllCallCount = 0
    var authorizationAnswer = true

    func requestAuthorization() async -> Bool { authorizationAnswer }

    func sync(_ reminders: [Reminder], now: Date) async {
        syncCallCount += 1
        lastSynced = reminders
    }

    func cancelAll() async {
        cancelAllCallCount += 1
    }
}
```

Buat `DinoPocketTests/ReminderTriggersTests.swift`:

```swift
import Foundation
import Testing
@testable import Apl

struct ReminderTriggersTests {

    @Test func onceBecomesAFullDateThatDoesNotRepeat() {
        let reminder = Reminder(title: "Call mom", rule: .once(TestTime.date(2026, 9, 16, 15, 0)),
                                createdAt: TestTime.now)

        let trigger = ReminderTriggers.trigger(for: reminder, calendar: TestTime.calendar)

        #expect(trigger.identifier == "apl.reminder.\(reminder.id.uuidString)")
        #expect(trigger.title == "Call mom")
        let c = trigger.components
        #expect([c.year, c.month, c.day, c.hour, c.minute, c.second] == [2026, 9, 16, 15, 0, 0])
        #expect(trigger.repeats == false)
    }

    @Test func dailyBecomesHourAndMinuteThatRepeats() {
        let reminder = Reminder(title: "Stretch", rule: .daily(hour: 9, minute: 30), createdAt: TestTime.now)

        let trigger = ReminderTriggers.trigger(for: reminder, calendar: TestTime.calendar)

        #expect(trigger.components.hour == 9)
        #expect(trigger.components.minute == 30)
        #expect(trigger.components.day == nil)
        #expect(trigger.repeats)
    }

    @Test func passedOnceRemindersAreNotScheduled() {
        let past = Reminder(title: "Past", rule: .once(TestTime.date(2026, 9, 16, 9, 0)), createdAt: TestTime.now)
        let future = Reminder(title: "Future", rule: .once(TestTime.date(2026, 9, 16, 15, 0)), createdAt: TestTime.now)

        let plan = ReminderTriggers.plan(for: [past, future], now: TestTime.now, calendar: TestTime.calendar)

        #expect(plan.map(\.title) == ["Future"])
    }

    /// macOS membatasi jumlah notifikasi tertunda. Yang dijadwalkan harus yang
    /// TERDEKAT, bukan yang kebetulan pertama di daftar.
    @Test func onlyTheNearestSixtyAreScheduled() {
        let reminders = (1...70).reversed().map { minutes in
            Reminder(title: "R\(minutes)",
                     rule: .once(TestTime.now.addingTimeInterval(TimeInterval(minutes * 60))),
                     createdAt: TestTime.now)
        }

        let plan = ReminderTriggers.plan(for: reminders, now: TestTime.now, calendar: TestTime.calendar)

        #expect(plan.count == ReminderTriggers.maxScheduled)
        #expect(plan.map(\.title) == (1...60).map { "R\($0)" })
    }
}
```

Buat `DinoPocketTests/ReminderPhrasingTests.swift`:

```swift
import Foundation
import Testing
@testable import Apl

/// "Sekarang" = Rabu 16 Sep 2026 10.00 WIB. Jam dibandingkan lewat
/// `ReminderPhrasing.time` karena format sistem memakai spasi sempit
/// (U+202F) sebelum AM/PM, yang tidak terlihat bila ditulis literal.
struct ReminderPhrasingTests {

    private func time(_ day: Int, _ hour: Int, _ minute: Int) -> String {
        ReminderPhrasing.time(TestTime.date(2026, 9, day, hour, minute),
                              calendar: TestTime.calendar, locale: TestTime.locale)
    }

    private func confirm(_ title: String, _ rule: Reminder.Rule) -> String {
        ReminderPhrasing.confirmation(title: title, rule: rule, now: TestTime.now,
                                      calendar: TestTime.calendar, locale: TestTime.locale)
    }

    @Test func timeUsesTheLocaleClock() {
        let text = time(16, 15, 0)
        #expect(text.contains("3:00"))
        #expect(text.contains("PM"))
    }

    @Test func sameDayIsToday() {
        #expect(confirm("Call mom", .once(TestTime.date(2026, 9, 16, 15, 0)))
                == "Done — I'll remind you to call mom today at \(time(16, 15, 0)).")
    }

    @Test func nextDayIsTomorrow() {
        #expect(confirm("Send the report", .once(TestTime.date(2026, 9, 17, 9, 0)))
                == "Done — I'll remind you to send the report tomorrow at \(time(17, 9, 0)).")
    }

    @Test func withinAnHourCountsMinutes() {
        #expect(confirm("Check the oven", .once(TestTime.now.addingTimeInterval(20 * 60)))
                == "Done — I'll remind you to check the oven in 20 minutes (\(time(16, 10, 20))).")
    }

    @Test func oneMinuteIsSingular() {
        #expect(confirm("Breathe", .once(TestTime.now.addingTimeInterval(60)))
                == "Done — I'll remind you to breathe in 1 minute (\(time(16, 10, 1))).")
    }

    @Test func dailySaysEveryDay() {
        #expect(confirm("Stretch", .daily(hour: 9, minute: 0))
                == "Done — I'll remind you to stretch every day at \(time(16, 9, 0)).")
    }

    @Test func defaultTitleOmitsTheSubject() {
        #expect(confirm("Reminder", .once(TestTime.date(2026, 9, 16, 15, 0)))
                == "Done — I'll remind you today at \(time(16, 15, 0)).")
    }

    @Test func innerCapitalsAreKept() {
        #expect(confirm("Call Mom", .once(TestTime.date(2026, 9, 16, 15, 0))).contains("to call Mom today"))
    }

    @Test func timeQuestionMentionsTheTitleWhenThereIsOne() {
        #expect(ReminderPhrasing.timeQuestion(title: "Call mom") == "What time should I remind you to call mom?")
        #expect(ReminderPhrasing.timeQuestion(title: nil) == "What time should I remind you?")
    }
}
```

Buat `DinoPocketTests/ReminderEditingUseCaseTests.swift`:

```swift
import Foundation
import Testing
@testable import Apl

@MainActor
struct EditReminderUseCaseTests {

    @Test func cancelRemovesTheReminderAndReschedulesTheRest() async {
        let store = InMemoryReminderStore()
        let scheduler = SpyReminderScheduler()
        let keep = Reminder(title: "Stretch", rule: .daily(hour: 9, minute: 0), createdAt: TestTime.now)
        let drop = Reminder(title: "Call mom", rule: .once(TestTime.date(2026, 9, 16, 15, 0)), createdAt: TestTime.now)
        store.add(keep)
        store.add(drop)

        await CancelReminderUseCase(store: store, notifications: scheduler, now: { TestTime.now })
            .execute(id: drop.id)

        #expect(store.reminders == [keep])
        #expect(scheduler.syncCallCount == 1)
        #expect(scheduler.lastSynced == [keep])
    }

    @Test func updateReplacesTheReminderAndReschedules() async {
        let store = InMemoryReminderStore()
        let scheduler = SpyReminderScheduler()
        var reminder = Reminder(title: "Call mom", rule: .once(TestTime.date(2026, 9, 16, 15, 0)),
                                createdAt: TestTime.now)
        store.add(reminder)

        reminder.title = "Call dad"
        reminder.rule = .daily(hour: 20, minute: 0)
        await UpdateReminderUseCase(store: store, notifications: scheduler, now: { TestTime.now })
            .execute(reminder)

        #expect(store.reminders == [reminder])
        #expect(scheduler.syncCallCount == 1)
        #expect(scheduler.lastSynced == [reminder])
    }
}
```

- [ ] **Step 2: Jalankan dan pastikan gagal**

Run: `xcodegen generate`, lalu Test semua.
Expected: FAIL, kompilasi gagal dengan `cannot find type 'ReminderScheduling' in scope`, `cannot find 'ReminderTriggers' in scope`, `cannot find 'ReminderPhrasing' in scope`.

- [ ] **Step 3: Implementasikan protokol dan rencana trigger**

Buat `SharedCore/Infrastructure/Services/ReminderScheduling.swift`:

```swift
//
//  ReminderScheduling.swift
//  SharedCore
//
//  Kontrak penjadwal notifikasi reminder, dan rencana trigger yang murni.
//
//  Keputusan "apa yang dijadwalkan" dipisah dari adapter sistem supaya bisa
//  dites tanpa UNUserNotificationCenter. Nama `ReminderScheduling`, bukan
//  `NotificationScheduling`: nama itu sempat dipakai jalur wellness selama
//  keduanya hidup berdampingan.
//

import Foundation

protocol ReminderScheduling: Sendable {
    func requestAuthorization() async -> Bool
    /// Menyamakan notifikasi tertunda dengan daftar reminder: semua milik Apl
    /// dihapus, lalu kemunculan terdekat dijadwalkan ulang.
    func sync(_ reminders: [Reminder], now: Date) async
    func cancelAll() async
}

struct ReminderTrigger: Equatable, Sendable {
    let identifier: String
    let title: String
    let components: DateComponents
    let repeats: Bool
}

enum ReminderTriggers {

    static let identifierPrefix = "apl.reminder."

    /// macOS membatasi jumlah notifikasi tertunda per app; tetap di bawahnya.
    static let maxScheduled = 60

    static func plan(for reminders: [Reminder], now: Date, calendar: Calendar) -> [ReminderTrigger] {
        reminders
            .compactMap { reminder in
                reminder.nextOccurrence(after: now, calendar: calendar).map { (reminder, $0) }
            }
            .sorted { $0.1 < $1.1 }
            .prefix(maxScheduled)
            .map { trigger(for: $0.0, calendar: calendar) }
    }

    static func trigger(for reminder: Reminder, calendar: Calendar) -> ReminderTrigger {
        let identifier = identifierPrefix + reminder.id.uuidString
        switch reminder.rule {
        case .once(let date):
            return ReminderTrigger(
                identifier: identifier,
                title: reminder.title,
                components: calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date),
                repeats: false
            )
        case .daily(let hour, let minute):
            return ReminderTrigger(
                identifier: identifier,
                title: reminder.title,
                components: DateComponents(hour: hour, minute: minute),
                repeats: true
            )
        }
    }
}
```

- [ ] **Step 4: Implementasikan adapter notifikasi**

Buat `SharedCore/Infrastructure/Services/ReminderNotificationCenter.swift`:

```swift
//
//  ReminderNotificationCenter.swift
//  SharedCore
//
//  Adapter tipis ke UNUserNotificationCenter. Keputusan apa yang dijadwalkan,
//  kapan, dan berapa banyak ada di `ReminderTriggers` — murni dan dites.
//  Berkas ini hanya menerjemahkannya ke API sistem, jadi diverifikasi lewat
//  app sungguhan, bukan unit test.
//

import Foundation
import UserNotifications

@MainActor
final class ReminderNotificationCenter: NSObject, UNUserNotificationCenterDelegate {

    static let shared = ReminderNotificationCenter()

    private let center = UNUserNotificationCenter.current()

    /// Dipanggil sekali saat app dibuka. Tanpa delegate, reminder yang jatuh
    /// tempo saat Apl sedang di depan tidak ditampilkan sama sekali.
    func configure() {
        center.delegate = self
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    func sync(_ reminders: [Reminder], now: Date) async {
        await cancelAll()
        for trigger in ReminderTriggers.plan(for: reminders, now: now, calendar: .current) {
            let content = UNMutableNotificationContent()
            content.title = trigger.title
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: trigger.identifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: trigger.components,
                                                       repeats: trigger.repeats)
            )
            do {
                try await center.add(request)
            } catch {
                continue
            }
        }
    }

    func cancelAll() async {
        let identifiers = await pendingReminderIDs()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    /// Hanya identifier yang keluar dari completion handler: `UNNotificationRequest`
    /// bukan `Sendable`, dan menyeberangkannya ditolak Swift 6.
    private func pendingReminderIDs() async -> [String] {
        let prefix = ReminderTriggers.identifierPrefix
        return await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests.map(\.identifier).filter { $0.hasPrefix(prefix) })
            }
        }
    }
}

extension ReminderNotificationCenter: ReminderScheduling {}
```

- [ ] **Step 5: Implementasikan kalimat konfirmasi**

Buat `SharedCore/Domain/UseCases/ReminderPhrasing.swift`:

```swift
//
//  ReminderPhrasing.swift
//  SharedCore
//
//  Kalimat yang Apl ucapkan saat membuat reminder atau menanyakan jamnya.
//
//  Deterministik, bukan buatan model: konfirmasi adalah bukti bahwa reminder
//  benar-benar ada, jadi tidak boleh dikarang. Selalu menyebut KAPAN, supaya
//  jam yang sudah lewat dan dipindah ke besok langsung terlihat.
//

import Foundation

enum ReminderPhrasing {

    static func confirmation(title: String, rule: Reminder.Rule, now: Date,
                             calendar: Calendar, locale: Locale) -> String {
        let subject = title == ReminderParser.defaultTitle ? "" : " to \(lowercasedFirst(title))"
        return "Done — I'll remind you\(subject) \(when(rule, now: now, calendar: calendar, locale: locale))."
    }

    static func timeQuestion(title: String?) -> String {
        guard let title else { return "What time should I remind you?" }
        return "What time should I remind you to \(lowercasedFirst(title))?"
    }

    /// Jam dalam format locale pengguna ("3:00 PM" di en_US).
    static func time(_ date: Date, calendar: Calendar, locale: Locale) -> String {
        let style = Date.FormatStyle(date: .omitted, time: .shortened, locale: locale,
                                     calendar: calendar, timeZone: calendar.timeZone)
        return date.formatted(style)
    }

    private static func when(_ rule: Reminder.Rule, now: Date, calendar: Calendar, locale: Locale) -> String {
        switch rule {
        case .daily(let hour, let minute):
            let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
            return "every day at \(time(date, calendar: calendar, locale: locale))"

        case .once(let date):
            let clock = time(date, calendar: calendar, locale: locale)
            let interval = date.timeIntervalSince(now)
            if interval > 0, interval <= 3600 {
                let minutes = max(1, Int((interval / 60).rounded()))
                return "in \(minutes) \(minutes == 1 ? "minute" : "minutes") (\(clock))"
            }
            if calendar.isDate(date, inSameDayAs: now) {
                return "today at \(clock)"
            }
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
               calendar.isDate(date, inSameDayAs: tomorrow) {
                return "tomorrow at \(clock)"
            }
            // Tidak dihasilkan parser hari ini; ada untuk reminder yang diedit di B.
            let dayStyle = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
                .month(.abbreviated)
                .day()
            return "on \(date.formatted(dayStyle)) at \(clock)"
        }
    }

    private static func lowercasedFirst(_ text: String) -> String {
        text.prefix(1).lowercased() + String(text.dropFirst())
    }
}
```

- [ ] **Step 6: Implementasikan batal dan ubah reminder**

Buat `SharedCore/Domain/UseCases/CancelReminderUseCase.swift`:

```swift
//
//  CancelReminderUseCase.swift
//  SharedCore
//
//  Membatalkan satu reminder. Dipakai sub-project B (Up next, Undo).
//

import Foundation

@MainActor
struct CancelReminderUseCase {

    private let store: any ReminderStoring
    private let notifications: any ReminderScheduling
    private let now: () -> Date

    init(store: any ReminderStoring, notifications: any ReminderScheduling,
         now: @escaping () -> Date = { .now }) {
        self.store = store
        self.notifications = notifications
        self.now = now
    }

    /// Menjadwalkan ulang seluruh daftar, bukan menghapus satu notifikasi,
    /// supaya penjadwal hanya punya satu jalur kebenaran: `sync`.
    func execute(id: Reminder.ID) async {
        store.remove(id: id)
        await notifications.sync(store.reminders, now: now())
    }
}
```

Buat `SharedCore/Domain/UseCases/UpdateReminderUseCase.swift`:

```swift
//
//  UpdateReminderUseCase.swift
//  SharedCore
//
//  Mengubah judul, waktu, atau aturan ulang satu reminder. Dipakai
//  sub-project B (edit di popover reminder).
//

import Foundation

@MainActor
struct UpdateReminderUseCase {

    private let store: any ReminderStoring
    private let notifications: any ReminderScheduling
    private let now: () -> Date

    init(store: any ReminderStoring, notifications: any ReminderScheduling,
         now: @escaping () -> Date = { .now }) {
        self.store = store
        self.notifications = notifications
        self.now = now
    }

    func execute(_ reminder: Reminder) async {
        store.update(reminder)
        await notifications.sync(store.reminders, now: now())
    }
}
```

- [ ] **Step 7: Jalankan test baru, seluruh test, dan batas SharedCore**

Run: `xcodegen generate`, lalu Test dengan `-only-testing:DinoPocketTests/ReminderTriggersTests -only-testing:DinoPocketTests/ReminderPhrasingTests -only-testing:DinoPocketTests/EditReminderUseCaseTests` (15 PASS). Setelah itu Test semua dan `./scripts/verify-boundaries.sh`.
Expected: sekitar `114 tests in 25 suites passed`, `** TEST SUCCEEDED **`, `✅ batas SharedCore aman`.

- [ ] **Step 8: Commit**

```bash
git add SharedCore/Infrastructure/Services/ReminderScheduling.swift \
        SharedCore/Infrastructure/Services/ReminderNotificationCenter.swift \
        SharedCore/Domain/UseCases/ReminderPhrasing.swift \
        SharedCore/Domain/UseCases/CancelReminderUseCase.swift \
        SharedCore/Domain/UseCases/UpdateReminderUseCase.swift \
        DinoPocketTests/ReminderFakes.swift DinoPocketTests/ReminderTriggersTests.swift \
        DinoPocketTests/ReminderPhrasingTests.swift DinoPocketTests/ReminderEditingUseCaseTests.swift
git commit -m "$(cat <<'EOF'
feat(a4): penjadwal notifikasi sekali/harian, konfirmasi, batal & ubah

Aditif: belum dipakai chat. Rencana trigger murni memisahkan .once
(tanggal lengkap, tanpa ulang) dari .daily (jam dan menit, berulang) dan
hanya menjadwalkan 60 kemunculan terdekat. Kalimat konfirmasi selalu
menyebut kapan, sehingga jam yang sudah lewat terlihat sebagai "tomorrow".

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Chat membuat reminder lewat domain baru, dengan penjaga niat

**Files:**
- Rewrite: `SharedCore/Domain/UseCases/CreateReminderFromTextUseCase.swift`
- Create: `DinoPocketTests/CreateReminderFromTextUseCaseTests.swift`
- Modify: `DinoPocketMac/Presentation/ViewModels/ChatStore.swift`
- Modify: `DinoPocketTests/ChatStoreTests.swift`
- Modify: `SharedCore/Data/Enums/Persona.swift`
- Rewrite: `DinoPocketMac/App/AppDependencies.swift`
- Modify: `DinoPocketMac/App/AplApp.swift`
- Modify: `DinoPocketMac/Presentation/ViewModels/WellnessViewModel.swift`
- Modify: `DinoPocketMac/Presentation/Views/SettingsPage.swift`
- Modify: `SharedCore/Data/Errors/AplError.swift`
- Delete: `SharedCore/Infrastructure/Services/ReminderIntent.swift`, `SharedCore/Infrastructure/Services/ReminderParsing.swift`, `DinoPocketTests/ReminderIntentTests.swift`

**Interfaces:**
- Consumes: `ReminderParser` (Task 4); `ReminderScheduling`, `ReminderNotificationCenter`, `ReminderPhrasing`, `InMemoryReminderStore`, `SpyReminderScheduler` (Task 5); `ReminderStore` (Task 3).
- Produces:
  - `@MainActor struct CreateReminderFromTextUseCase` dengan `init(store: any ReminderStoring, notifications: any ReminderScheduling, now: @escaping () -> Date = { .now }, calendar: Calendar = .current, locale: Locale = .current)`, `enum Output: Equatable { case created(Reminder, confirmation: String); case needsTime(title: String?, question: String); case notAReminder }`, `func execute(text: String) async -> Output`, `func complete(title: String?, timeText text: String) async -> Output?`
  - `AppDependencies.reminderStore: ReminderStore`, `AppDependencies.reminderScheduler: any ReminderScheduling`, `func makeCreateReminderUseCase() -> CreateReminderFromTextUseCase`
  - `ChatStore`: tetap `var createReminder: CreateReminderFromTextUseCase?`; draft reminder satu giliran bersifat privat.

- [ ] **Step 1: Tulis test use case yang gagal**

Buat `DinoPocketTests/CreateReminderFromTextUseCaseTests.swift`:

```swift
import Foundation
import Testing
@testable import Apl

@MainActor
struct CreateReminderFromTextUseCaseTests {

    private func makeUseCase(store: InMemoryReminderStore,
                             scheduler: SpyReminderScheduler) -> CreateReminderFromTextUseCase {
        CreateReminderFromTextUseCase(store: store, notifications: scheduler, now: { TestTime.now },
                                      calendar: TestTime.calendar, locale: TestTime.locale)
    }

    @Test func reminderRequestIsSavedAndScheduled() async {
        let store = InMemoryReminderStore()
        let scheduler = SpyReminderScheduler()

        let output = await makeUseCase(store: store, scheduler: scheduler)
            .execute(text: "remind me to call mom at 3pm")

        guard case .created(let reminder, let confirmation) = output else {
            Issue.record("expected .created, got \(output)")
            return
        }
        #expect(reminder.title == "Call mom")
        #expect(reminder.rule == .once(TestTime.date(2026, 9, 16, 15, 0)))
        #expect(store.reminders == [reminder])
        #expect(scheduler.syncCallCount == 1)
        #expect(scheduler.lastSynced == [reminder])
        #expect(confirmation.hasPrefix("Done — I'll remind you to call mom today at"))
    }

    @Test func missingTimeAsksWithoutSaving() async {
        let store = InMemoryReminderStore()
        let scheduler = SpyReminderScheduler()

        let output = await makeUseCase(store: store, scheduler: scheduler)
            .execute(text: "remind me to drink water")

        #expect(output == .needsTime(title: "Drink water", question: "What time should I remind you to drink water?"))
        #expect(store.reminders.isEmpty)
        #expect(scheduler.syncCallCount == 0)
    }

    @Test func ordinaryChatIsNotAReminder() async {
        let store = InMemoryReminderStore()
        let scheduler = SpyReminderScheduler()

        let output = await makeUseCase(store: store, scheduler: scheduler)
            .execute(text: "what should I eat at 3pm?")

        #expect(output == .notAReminder)
        #expect(store.reminders.isEmpty)
    }

    @Test func completingWithATimeCreatesTheReminder() async {
        let store = InMemoryReminderStore()
        let scheduler = SpyReminderScheduler()

        let output = await makeUseCase(store: store, scheduler: scheduler)
            .complete(title: "Drink water", timeText: "5pm")

        guard case .created(let reminder, _)? = output else {
            Issue.record("expected .created, got \(String(describing: output))")
            return
        }
        #expect(reminder.title == "Drink water")
        #expect(reminder.rule == .once(TestTime.date(2026, 9, 16, 17, 0)))
        #expect(store.reminders.count == 1)
        #expect(scheduler.syncCallCount == 1)
    }

    @Test func completingWithoutATitleUsesTheDefault() async {
        let store = InMemoryReminderStore()

        let output = await makeUseCase(store: store, scheduler: SpyReminderScheduler())
            .complete(title: nil, timeText: "in 10 minutes")

        guard case .created(let reminder, _)? = output else {
            Issue.record("expected .created, got \(String(describing: output))")
            return
        }
        #expect(reminder.title == ReminderParser.defaultTitle)
    }

    @Test func completingWithSomethingElseReturnsNil() async {
        let store = InMemoryReminderStore()
        let scheduler = SpyReminderScheduler()

        let output = await makeUseCase(store: store, scheduler: scheduler)
            .complete(title: "Drink water", timeText: "tell me a joke")

        #expect(output == nil)
        #expect(store.reminders.isEmpty)
        #expect(scheduler.syncCallCount == 0)
    }
}
```

Di `DinoPocketTests/ChatStoreTests.swift`:

(a) Ganti `struct ChatStoreTests {` dengan:

```swift
/// Serial: setiap test membaca dan menulis `jarvis.chat.recent` di
/// `UserDefaults.standard`, jadi menjalankannya paralel membuat satu test
/// memuat pesan milik test lain.
@Suite(.serialized)
struct ChatStoreTests {
```

(b) Hapus test lama `sendCreatesReminderWithoutCallingBrain`, mulai dari baris komentar `    /// Natural-language reminder requests must be handled locally: no brain` sampai `    }` penutup test itu. **Jangan** hapus blok `// MARK: - Fakes` di bawahnya; blok itu masih dipakai test wellness sampai Task 7.

(c) Tambahkan di dalam `struct ChatStoreTests`, sebelum `}` penutupnya:

```swift
    @MainActor
    private func chatHandlingReminders(now: Date = TestTime.now)
        -> (ChatStore, InMemoryReminderStore, SpyReminderScheduler) {
        UserDefaults.standard.removeObject(forKey: "jarvis.chat.recent")
        let chat = ChatStore(brains: [:])
        let reminders = InMemoryReminderStore()
        let scheduler = SpyReminderScheduler()
        chat.createReminder = CreateReminderFromTextUseCase(
            store: reminders, notifications: scheduler, now: { now },
            calendar: TestTime.calendar, locale: TestTime.locale)
        return (chat, reminders, scheduler)
    }

    /// Reminder ditangani lokal: tidak ada otak di test ini (`brains: [:]`),
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
```

- [ ] **Step 2: Jalankan dan pastikan gagal**

Run: `xcodegen generate`, lalu Test semua.
Expected: FAIL, kompilasi gagal karena `CreateReminderFromTextUseCase` belum punya `init(store:notifications:now:calendar:locale:)`, `complete(title:timeText:)`, dan `Output`.

- [ ] **Step 3: Tulis ulang use case**

Ganti seluruh isi `SharedCore/Domain/UseCases/CreateReminderFromTextUseCase.swift`:

```swift
//
//  CreateReminderFromTextUseCase.swift
//  SharedCore
//
//  Parse → simpan → jadwalkan, sebagai satu tanggung jawab.
//
//  Dulu penjadwalan terjadi di tempat lain, sehingga apakah reminder
//  benar-benar berbunyi bergantung pada siapa yang memasang closure-nya.
//  Menyatukannya di sini membuat "reminder dibuat" dan "reminder
//  dijadwalkan" tidak mungkin berbeda pendapat.
//

import Foundation

@MainActor
struct CreateReminderFromTextUseCase {

    enum Output: Equatable {
        case created(Reminder, confirmation: String)
        case needsTime(title: String?, question: String)
        case notAReminder
    }

    private let store: any ReminderStoring
    private let notifications: any ReminderScheduling
    private let now: () -> Date
    private let calendar: Calendar
    private let locale: Locale

    init(store: any ReminderStoring,
         notifications: any ReminderScheduling,
         now: @escaping () -> Date = { .now },
         calendar: Calendar = .current,
         locale: Locale = .current) {
        self.store = store
        self.notifications = notifications
        self.now = now
        self.calendar = calendar
        self.locale = locale
    }

    func execute(text: String) async -> Output {
        let current = now()
        switch ReminderParser.parse(text, now: current, calendar: calendar) {
        case .reminder(let title, let rule):
            return await create(title: title, rule: rule, at: current)
        case .missingTime(let title):
            return .needsTime(title: title, question: ReminderPhrasing.timeQuestion(title: title))
        case .notAReminder:
            return .notAReminder
        }
    }

    /// Melengkapi reminder yang tadi ditanyakan jamnya. nil bila `text` bukan
    /// ungkapan waktu saja — pemanggil lalu memperlakukannya sebagai pesan biasa.
    func complete(title: String?, timeText text: String) async -> Output? {
        let current = now()
        guard let rule = ReminderParser.parseTimeOnly(text, now: current, calendar: calendar) else {
            return nil
        }
        return await create(title: title ?? ReminderParser.defaultTitle, rule: rule, at: current)
    }

    private func create(title: String, rule: Reminder.Rule, at current: Date) async -> Output {
        let reminder = Reminder(title: title, rule: rule, createdAt: current)
        store.add(reminder)
        await notifications.sync(store.reminders, now: current)
        let confirmation = ReminderPhrasing.confirmation(title: title, rule: rule, now: current,
                                                         calendar: calendar, locale: locale)
        return .created(reminder, confirmation: confirmation)
    }
}
```

- [ ] **Step 4: Pasang penjaga niat di `ChatStore`**

Di `DinoPocketMac/Presentation/ViewModels/ChatStore.swift`:

(a) Ganti:

```swift
    private var streamTask: Task<Void, Never>?
    private var streamGeneration = 0
```

dengan:

```swift
    private var streamTask: Task<Void, Never>?
    private var streamGeneration = 0

    /// Reminder yang sedang menunggu jawaban "jam berapa?". Hanya bertahan satu
    /// giliran: pesan berikutnya yang bukan ungkapan waktu membuangnya.
    private var reminderAwaitingTime: PendingReminder?

    private struct PendingReminder {
        let title: String?
    }
```

(b) Di `eraseAllStoredData()`, tambahkan setelah `pendingPrompt = nil`:

```swift
        reminderAwaitingTime = nil
```

(c) Ganti:

```swift
        if let createReminder, let result = await createReminder.execute(text: trimmed) {
            noticeMessage = nil
            streamGeneration += 1
            messages.append(ChatMessage(id: UUID(), role: .assistant,
                text: result.confirmation, date: .now))
            persistRecent()
            return
        }
```

dengan:

```swift
        if let reply = await localReminderReply(to: trimmed) {
            noticeMessage = nil
            streamGeneration += 1
            messages.append(ChatMessage(id: UUID(), role: .assistant, text: reply, date: .now))
            persistRecent()
            return
        }
```

(d) Tambahkan method ini tepat sebelum komentar `    /// Kalau stream sebelumnya diputus di tengah jalan, rapikan bubble asisten-nya`:

```swift
    /// Jawaban reminder tanpa AI, atau nil bila pesan harus diteruskan ke otak.
    ///
    /// Selama ada "remind me", pesan TIDAK PERNAH sampai ke model: model bisa
    /// menjawab "Sure!" tanpa membuat apa pun, dan reminder yang dijanjikan
    /// tetapi tidak ada lebih buruk daripada pertanyaan balik.
    private func localReminderReply(to text: String) async -> String? {
        guard let createReminder else { return nil }

        if let pending = reminderAwaitingTime {
            reminderAwaitingTime = nil
            if case .created(_, let confirmation)? = await createReminder.complete(title: pending.title,
                                                                                 timeText: text) {
                return confirmation
            }
        }

        switch await createReminder.execute(text: text) {
        case .created(_, let confirmation):
            return confirmation
        case .needsTime(let title, let question):
            reminderAwaitingTime = PendingReminder(title: title)
            return question
        case .notAReminder:
            return nil
        }
    }

```

- [ ] **Step 5: Larang model mengaku membuat reminder**

Di `SharedCore/Data/Enums/Persona.swift`, ganti seluruh isi `case .apl:` sampai `"""` penutupnya:

```swift
        case .apl:
            return """
            You are Apl, a warm and supportive wellness companion on this Mac. \
            You care about healthy rhythms: drinking water, stretching, eating regularly, and screen time. \
            Speak casually, briefly, and encouragingly without lecturing, in English. \
            If the user asks to set up a reminder, confirm the type and time.
            """
```

dengan:

```swift
        case .apl:
            return """
            You are Apl, a warm and friendly companion that lives on this Mac. \
            Speak casually, briefly, and encouragingly without lecturing, in English. \
            You cannot create, change, or cancel reminders yourself. \
            If the user asks for one, tell them to write it like: "Remind me to … at 3 PM".
            """
```

- [ ] **Step 6: Sambungkan di composition root**

Ganti seluruh isi `DinoPocketMac/App/AppDependencies.swift`:

```swift
//
//  AppDependencies.swift
//  AplMac
//
//  Composition root, mengikuti pola Taggo: satu tempat yang tahu implementasi
//  konkret mana yang dipakai, dan pabrik untuk ViewModel.
//
//  Nilainya bukan kerapian semata — ia yang membuat "Ollama tidak ikut rilis"
//  jadi fakta struktural di satu berkas, bukan disiplin yang harus diingat di
//  setiap tempat `ChatStore` dibuat.
//

import Foundation

@MainActor
struct AppDependencies {

    let systemStatus: SystemStatusProviding
    let appLauncher: AppLaunching
    let launchAtLogin: LaunchAtLoginManaging
    let buddySettings: BuddySettingsStore
    let profile: ProfileStore

    /// Otak yang boleh dipilih. Rilis hanya memuat Apple Intelligence: Ollama
    /// butuh localhost, sementara build ini menyetel
    /// ENABLE_OUTGOING_NETWORK_CONNECTIONS = NO, dan app yang bergantung pada
    /// software eksternal berisiko ditolak App Review.
    let brains: [BrainKind: Brain]

    /// Satu-satunya instance WellnessStore dalam app — disimpan di sini agar
    /// makeWellnessViewModel() tidak membuat store baru setiap dipanggil, yang
    /// akan menghasilkan dua sumber kebenaran untuk data yang sama.
    let wellnessStore: WellnessStore

    /// Satu-satunya instance ReminderStore: chat dan daftar reminder harus
    /// membaca daftar yang sama.
    let reminderStore: ReminderStore
    let reminderScheduler: any ReminderScheduling

    /// Didaftarkan eksplisit supaya Erase All Data tidak melewatkannya.
    let erasableStores: [any LocallyErasable]

    static func live() -> AppDependencies {
        // Transcript dipersist supaya percakapan bertahan lintas peluncuran —
        // inti dari "asisten yang ingat kemarin".
        let apple: Brain
        var erasable: [any LocallyErasable] = []
        if #available(macOS 26.0, *) {
            let sessionStore = FileChatSessionStore()
            apple = AppleBrain(sessionStore: sessionStore)
            erasable.append(sessionStore)
        } else {
            apple = AppleBrain()
        }

        #if DEBUG
        let brains: [BrainKind: Brain] = [.apple: apple, .ollama: OllamaBrain()]
        #else
        let brains: [BrainKind: Brain] = [.apple: apple]
        #endif

        let reminderStore = ReminderStore()
        erasable.append(reminderStore)

        return AppDependencies(
            systemStatus: SystemStatusService(),
            appLauncher: AppLauncherService(),
            launchAtLogin: LaunchAtLoginService(),
            buddySettings: BuddySettingsStore(),
            profile: ProfileStore(),
            brains: brains,
            wellnessStore: WellnessStore(),
            reminderStore: reminderStore,
            reminderScheduler: ReminderNotificationCenter.shared,
            erasableStores: erasable
        )
    }

    // MARK: - Factories

    func makeChatStore() -> ChatStore {
        ChatStore(brains: brains)
    }

    /// View model selalu dibungkus di atas wellnessStore yang sama, sehingga
    /// hanya ada satu sumber kebenaran data wellness dalam satu sesi app.
    func makeWellnessViewModel() -> WellnessViewModel {
        WellnessViewModel(store: wellnessStore,
                          notifications: WellnessNotificationCenter.shared,
                          idle: IdleTimeService())
    }

    func makeCreateReminderUseCase() -> CreateReminderFromTextUseCase {
        CreateReminderFromTextUseCase(store: reminderStore, notifications: reminderScheduler)
    }
}
```

Di `DinoPocketMac/App/AplApp.swift`:
- Ganti `        WellnessNotificationCenter.shared.configure()` dengan `        ReminderNotificationCenter.shared.configure()`
- Ganti `                    chat.createReminder = wellness.makeCreateReminderUseCase()` dengan `                    chat.createReminder = Self.deps.makeCreateReminderUseCase()`
- Ganti `                           onNotificationsGranted: { await wellness.setRemindersEnabled(true) })` dengan:

```swift
                           onNotificationsGranted: {
                               // Reminder yang dibuat sebelum izin diberikan baru bisa dijadwalkan sekarang.
                               await Self.deps.reminderScheduler.sync(Self.deps.reminderStore.reminders, now: .now)
                           })
```

Di `DinoPocketMac/Presentation/ViewModels/WellnessViewModel.swift`, hapus blok ini beserta baris kosong sesudahnya:

```swift
    /// Dipakai `ChatStore` saat pengingat lahir dari percakapan.
    func makeCreateReminderUseCase() -> CreateReminderFromTextUseCase {
        CreateReminderFromTextUseCase(parser: ReminderIntentParser(),
                                      store: store,
                                      notifications: notifications)
    }

```

Di `DinoPocketMac/Presentation/Views/SettingsPage.swift`, ganti:

```swift
                    clearNotifications: { await WellnessNotificationCenter.shared.clearScheduledReminders() }
```

dengan:

```swift
                    clearNotifications: {
                        await WellnessNotificationCenter.shared.clearScheduledReminders()
                        await ReminderNotificationCenter.shared.cancelAll()
                    }
```

- [ ] **Step 7: Buang parser lama**

```bash
git rm SharedCore/Infrastructure/Services/ReminderIntent.swift \
       SharedCore/Infrastructure/Services/ReminderParsing.swift \
       DinoPocketTests/ReminderIntentTests.swift
```

Di `SharedCore/Data/Errors/AplError.swift`, hapus case yang tidak lagi punya pemakai:

```swift

    /// Teks tidak bisa diurai jadi jadwal pengingat.
    case unparseableReminder(input: String)
```

dan cabangnya di `errorDescription`:

```swift
        case .unparseableReminder(let input):
            "I couldn't turn “\(input)” into a reminder."
```

- [ ] **Step 8: Generate, build, dan jalankan seluruh test**

Run: `xcodegen generate`, lalu Build, lalu Test semua, lalu `./scripts/verify-boundaries.sh`.
Expected: `** BUILD SUCCEEDED **`; sekitar `116 tests in 25 suites passed`; `** TEST SUCCEEDED **`; `✅ batas SharedCore aman`.

- [ ] **Step 9: Pastikan parser lama sudah hilang**

Run:

```bash
grep -rnE "ReminderIntent|ReminderParsing|unparseableReminder" \
  DinoPocketMac SharedCore DinoPocketTests --include='*.swift' \
  | grep -vE "Legacy/|ContentView|PetActivityWidgets|Haptics.swift"
grep -n "makeCreateReminderUseCase" DinoPocketMac/Presentation/ViewModels/WellnessViewModel.swift
```

Expected: kedua perintah tidak menghasilkan output.

- [ ] **Step 10: Commit**

```bash
git add -A DinoPocketMac SharedCore DinoPocketTests
git commit -m "$(cat <<'EOF'
feat(a4): chat membuat reminder lewat domain baru, dengan penjaga niat

Selama ada "remind me", pesan tidak pernah sampai ke model. Reminder
tanpa jam memicu pertanyaan balik yang berlaku satu giliran, dan
konfirmasinya ditulis deterministik. Instructions persona kini melarang
model mengaku membuat reminder. Parser lama (air/stretch/makan) dibuang.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Hapus wellness (A3)

**Files:**
- Delete (views): `DinoPocketMac/Presentation/Views/HomePage.swift`, `WellnessCard.swift`, `DeskTimeCard.swift`, `RemindersCard.swift`, `ReminderRow.swift`, `HistoryPage.swift`, `CharacterCard.swift`, `AvatarBadge.swift`, `DashCard.swift`, `MetricRow.swift`, `RingGauge.swift`, `PillButton.swift`, `Triangle.swift`
- Delete: `DinoPocketMac/Presentation/ViewModels/WellnessViewModel.swift`
- Delete: `SharedCore/Domain/UseCases/FetchWellnessSummaryUseCase.swift`, `TrackFocusSessionUseCase.swift`
- Delete: `SharedCore/Infrastructure/Persistence/WellnessStore.swift`, `WellnessStoring.swift`
- Delete: `SharedCore/Infrastructure/Services/WellnessNotificationCenter.swift`, `NotificationScheduling.swift`
- Delete: `SharedCore/Data/Models/ReminderSchedule.swift`, `ReminderEvent.swift`, `BuddyReminder.swift`, `ScreenTimeEntry.swift`, `SnoozedReminder.swift`, `WellnessGoalProgress.swift`
- Delete: `SharedCore/Data/Enums/ReminderKind.swift`, `Mood.swift`
- Delete: `DinoPocketMac/Infrastructure/Services/IdleTimeService.swift`
- Delete (tests): `DinoPocketTests/WellnessStoreTests.swift`, `FetchWellnessSummaryTests.swift`, `RemindersWiringTests.swift`
- Create: `DinoPocketTests/ChatAvailabilityTests.swift` (dipindah dari `RemindersWiringTests.swift`)
- Rewrite: `DinoPocketMac/Presentation/Views/DashboardTemplate.swift`, `DinoPocketMac/App/AplApp.swift`, `DinoPocketMac/App/AppDependencies.swift`
- Modify: `SidebarView.swift`, `SettingsPage.swift`, `AIUnavailableCard.swift`, `AppColors.swift`, `DinoPocketTests/CharacterAssetTests.swift`, `DinoPocketTests/ChatStoreTests.swift`, `DinoPocketTests/EraseAllDataUseCaseTests.swift`

**Interfaces:**
- Consumes: `ProfileStore`, `EraseAllDataUseCase` (Task 2); `ReminderNotificationCenter` (Task 5); `AppDependencies.makeCreateReminderUseCase()`, `reminderStore`, `reminderScheduler` (Task 6).
- Produces:
  - `enum DashboardSection { case chat, settings }` (hanya dua bagian)
  - `DashboardTemplate(chat:buddySettings:profile:extraErasableStores:onBuddyMode:isBuddyModeActive:)`
  - `SettingsPage(chat:buddySettings:profile:extraErasableStores:)`
  - `AppDependencies` tanpa `wellnessStore` dan `makeWellnessViewModel()`

Tidak ada perilaku baru di task ini, jadi tidak ada test baru. Test yang ada harus tetap hijau setelah kode wellness dan test-nya dihapus.

- [ ] **Step 1: Catat hash sebelum penghapusan**

Run: `BASE=$(git rev-parse --short HEAD) && echo $BASE`
Expected: hash commit Task 6. Hash ini dipakai di pesan commit Step 10, supaya spec companion iPhone bisa memulihkan berkas lewat `git show <hash>:<path>`.

- [ ] **Step 2: Pindahkan suite ketersediaan otak ke berkasnya sendiri**

Buat `DinoPocketTests/ChatAvailabilityTests.swift` (isi dipindah apa adanya dari `RemindersWiringTests.swift`; disesuaikan di Task 8):

```swift
import Foundation
import Testing
@testable import Apl

@Suite("Ketersediaan otak untuk layar chat")
struct ChatAvailabilityTests {

    @MainActor
    @Test func chatIsUsableWhenAppleIsDownButAnotherBrainIsReady() async {
        let chat = ChatStore(brains: [
            .apple: StubBrain(kind: .apple, availability: .unavailable("Enable Apple Intelligence in System Settings.")),
            .ollama: StubBrain(kind: .ollama, availability: .ready)
        ])

        #expect(await chat.bestAvailability() == .ready)
    }

    @MainActor
    @Test func chatReportsAppleReasonWhenNoBrainIsReady() async {
        let chat = ChatStore(brains: [
            .apple: StubBrain(kind: .apple, availability: .unavailable("Enable Apple Intelligence in System Settings.")),
            .ollama: StubBrain(kind: .ollama, availability: .needsSetup("Ollama isn't running."))
        ])

        #expect(await chat.bestAvailability() == .unavailable("Enable Apple Intelligence in System Settings."))
    }
}

private struct StubBrain: Brain {
    let kind: BrainKind
    let stubbed: BrainAvailability

    init(kind: BrainKind, availability: BrainAvailability) {
        self.kind = kind
        self.stubbed = availability
    }

    func availability() async -> BrainAvailability { stubbed }

    func reply(to history: [ChatMessage], persona: Persona) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}
```

- [ ] **Step 3: Hapus berkas wellness**

```bash
git rm DinoPocketMac/Presentation/Views/HomePage.swift \
       DinoPocketMac/Presentation/Views/WellnessCard.swift \
       DinoPocketMac/Presentation/Views/DeskTimeCard.swift \
       DinoPocketMac/Presentation/Views/RemindersCard.swift \
       DinoPocketMac/Presentation/Views/ReminderRow.swift \
       DinoPocketMac/Presentation/Views/HistoryPage.swift \
       DinoPocketMac/Presentation/Views/CharacterCard.swift \
       DinoPocketMac/Presentation/Views/AvatarBadge.swift \
       DinoPocketMac/Presentation/Views/DashCard.swift \
       DinoPocketMac/Presentation/Views/MetricRow.swift \
       DinoPocketMac/Presentation/Views/RingGauge.swift \
       DinoPocketMac/Presentation/Views/PillButton.swift \
       DinoPocketMac/Presentation/Views/Triangle.swift \
       DinoPocketMac/Presentation/ViewModels/WellnessViewModel.swift \
       SharedCore/Domain/UseCases/FetchWellnessSummaryUseCase.swift \
       SharedCore/Domain/UseCases/TrackFocusSessionUseCase.swift \
       SharedCore/Infrastructure/Persistence/WellnessStore.swift \
       SharedCore/Infrastructure/Persistence/WellnessStoring.swift \
       SharedCore/Infrastructure/Services/WellnessNotificationCenter.swift \
       SharedCore/Infrastructure/Services/NotificationScheduling.swift \
       SharedCore/Data/Models/ReminderSchedule.swift \
       SharedCore/Data/Models/ReminderEvent.swift \
       SharedCore/Data/Models/BuddyReminder.swift \
       SharedCore/Data/Models/ScreenTimeEntry.swift \
       SharedCore/Data/Models/SnoozedReminder.swift \
       SharedCore/Data/Models/WellnessGoalProgress.swift \
       SharedCore/Data/Enums/ReminderKind.swift \
       SharedCore/Data/Enums/Mood.swift \
       DinoPocketMac/Infrastructure/Services/IdleTimeService.swift \
       DinoPocketTests/WellnessStoreTests.swift \
       DinoPocketTests/FetchWellnessSummaryTests.swift \
       DinoPocketTests/RemindersWiringTests.swift
```

- [ ] **Step 4: Buang sisa test wellness di berkas yang tetap ada**

- `DinoPocketTests/CharacterAssetTests.swift`: hapus seluruh `struct TrackFocusSessionTests { ... }`, dari baris `struct TrackFocusSessionTests {` sampai akhir berkas, termasuk baris kosong sebelumnya.
- `DinoPocketTests/EraseAllDataUseCaseTests.swift`: hapus seluruh `struct WellnessStoreErasureTests { ... }`, dari baris `@MainActor` tepat di atas `struct WellnessStoreErasureTests {` sampai akhir berkas.
- `DinoPocketTests/ChatStoreTests.swift`: hapus dari baris `// MARK: - Fakes` sampai akhir berkas (`FakeWellnessStore` dan `FakeNotificationScheduler`).

- [ ] **Step 5: Tulis ulang dashboard sementara**

Ganti seluruh isi `DinoPocketMac/Presentation/Views/DashboardTemplate.swift`:

```swift
//
//  DashboardTemplate.swift
//  Apl
//
//  Template: NavigationSplitView shell — sidebar section switcher plus the
//  detail pages.
//
//  SEMENTARA: bentuk ini hidup di antara sub-project A dan B. Jendela utama
//  chat-first (spec 2026-09-15-apl-main-window-design.md) menggantikannya.
//

import SwiftUI

struct DashboardTemplate: View {
    @Bindable var chat: ChatStore
    @Bindable var buddySettings: BuddySettingsStore
    let profile: ProfileStore
    var extraErasableStores: [any LocallyErasable] = []
    var onBuddyMode: (() -> Void)? = nil
    var isBuddyModeActive: Bool = false

    @State private var selection: DashboardSection = .chat

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection, chat: chat)
                .frame(minWidth: 190)
        } detail: {
            switch selection {
            case .chat:
                ChatPage(chat: chat)
            case .settings:
                SettingsPage(chat: chat, buddySettings: buddySettings, profile: profile,
                             extraErasableStores: extraErasableStores)
            }
        }
        .frame(minWidth: 720, minHeight: 520)
        .toolbar {
            // Satu-satunya jalan menyalakan ulang Buddy setelah ditutup dengan
            // Esc — tombolnya dulu ada di HomePage, yang sudah dihapus.
            ToolbarItem(placement: .primaryAction) {
                Button(isBuddyModeActive ? "Hide Buddy" : "Show Buddy", systemImage: "figure.stand") {
                    onBuddyMode?()
                }
            }
        }
    }
}

#Preview {
    DashboardTemplate(chat: ChatStore(brains: [:]), buddySettings: BuddySettingsStore(), profile: ProfileStore())
}
```

Di `DinoPocketMac/Presentation/Views/SidebarView.swift`, ganti seluruh `enum DashboardSection` dengan:

```swift
enum DashboardSection: String, CaseIterable, Identifiable {
    case chat = "Apl AI"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .chat: "sparkles"
        case .settings: "gearshape"
        }
    }
}
```

dan pada `#Preview`, ganti `.constant(.home)` dengan `.constant(.chat)`.

- [ ] **Step 6: Lepaskan wellness dari Settings**

Di `DinoPocketMac/Presentation/Views/SettingsPage.swift`:

(a) Hapus baris `    let wellness: WellnessViewModel`.

(b) Ganti seluruh blok `Section("Reminders") { ... }` (dari `            Section("Reminders") {` sampai `}` penutupnya, tepat sebelum `            Section("Buddy") {`) dengan:

```swift
            Section("Reminders") {
                // Reminder dibuat lewat chat. Di sini hanya ada jalan ke izin
                // notifikasi, karena tanpa izin reminder tidak pernah muncul.
                Text("Ask Apl in chat, for example “Remind me to stretch at 3 PM”.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Open Notification Settings") {
                    launcher.open(.notifications)
                }
            }
```

(c) Ganti:

```swift
                    [profile, wellness.erasableStore, chat, buddySettings] + extraErasableStores
```

dengan:

```swift
                    [profile, chat, buddySettings] + extraErasableStores
```

(d) Ganti:

```swift
                    clearNotifications: {
                        await WellnessNotificationCenter.shared.clearScheduledReminders()
                        await ReminderNotificationCenter.shared.cancelAll()
                    }
```

dengan:

```swift
                    clearNotifications: { await ReminderNotificationCenter.shared.cancelAll() }
```

(e) Ganti preview:

```swift
        SettingsPage(chat: ChatStore(brains: [:]), wellness: .preview, buddySettings: BuddySettingsStore(), profile: ProfileStore())
```

dengan:

```swift
        SettingsPage(chat: ChatStore(brains: [:]), buddySettings: BuddySettingsStore(), profile: ProfileStore())
```

Di `DinoPocketMac/Presentation/Views/AIUnavailableCard.swift`, ganti:

```swift
            Text("Your character, reminders, wellness tracking, and history all keep working.")
```

dengan:

```swift
            Text("Your character and reminders keep working.")
```

Di `DinoPocketMac/Presentation/Views/AppColors.swift`, hapus:

```swift
    // Wellness tints
    static let water = Color.teal
    static let stretch = Color.green
    static let meal = Color.orange

```

- [ ] **Step 7: Tulis ulang app dan composition root tanpa wellness**

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
                }
        }
        // Modifier Scene, bukan View. Tanpa ini jendela memakai ukuran bawaan
        // yang bisa memotong sidebar dan halaman chat.
        .defaultSize(width: 1000, height: 680)
        .windowResizability(.contentMinSize)
    }

    @ViewBuilder
    private var rootView: some View {
        if profile.hasCompletedOnboarding {
            dashboard
        } else {
            OnboardingView(profile: profile, chat: chat,
                           onNotificationsGranted: {
                               // Reminder yang dibuat sebelum izin diberikan baru bisa dijadwalkan sekarang.
                               await Self.deps.reminderScheduler.sync(Self.deps.reminderStore.reminders, now: .now)
                           })
        }
    }

    @ViewBuilder
    private var dashboard: some View {
        DashboardTemplate(
            chat: chat,
            buddySettings: buddySettings,
            profile: profile,
            extraErasableStores: Self.deps.erasableStores,
            onBuddyMode: toggleBuddyMode,
            isBuddyModeActive: isBuddyMode
        )
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
        // Buddy Mode menyala sendiri begitu dashboard tampil.
        //
        // Dijalankan sekali per kemunculan dashboard; menyalakan ulang saat
        // sudah aktif akan membangun ulang jendelanya tanpa alasan.
        .task {
            guard !isBuddyMode else { return }
            isBuddyMode = true
        }
    }
}
```

Ganti seluruh isi `DinoPocketMac/App/AppDependencies.swift`:

```swift
//
//  AppDependencies.swift
//  AplMac
//
//  Composition root, mengikuti pola Taggo: satu tempat yang tahu implementasi
//  konkret mana yang dipakai, dan pabrik untuk ViewModel.
//
//  Nilainya bukan kerapian semata — ia yang membuat "Ollama tidak ikut rilis"
//  jadi fakta struktural di satu berkas, bukan disiplin yang harus diingat di
//  setiap tempat `ChatStore` dibuat.
//

import Foundation

@MainActor
struct AppDependencies {

    let systemStatus: SystemStatusProviding
    let appLauncher: AppLaunching
    let launchAtLogin: LaunchAtLoginManaging
    let buddySettings: BuddySettingsStore
    let profile: ProfileStore

    /// Otak yang boleh dipilih. Rilis hanya memuat Apple Intelligence: Ollama
    /// butuh localhost, sementara build ini menyetel
    /// ENABLE_OUTGOING_NETWORK_CONNECTIONS = NO, dan app yang bergantung pada
    /// software eksternal berisiko ditolak App Review.
    let brains: [BrainKind: Brain]

    /// Satu-satunya instance ReminderStore: chat dan daftar reminder harus
    /// membaca daftar yang sama.
    let reminderStore: ReminderStore
    let reminderScheduler: any ReminderScheduling

    /// Didaftarkan eksplisit supaya Erase All Data tidak melewatkannya.
    let erasableStores: [any LocallyErasable]

    static func live() -> AppDependencies {
        // Transcript dipersist supaya percakapan bertahan lintas peluncuran —
        // inti dari "asisten yang ingat kemarin".
        let apple: Brain
        var erasable: [any LocallyErasable] = []
        if #available(macOS 26.0, *) {
            let sessionStore = FileChatSessionStore()
            apple = AppleBrain(sessionStore: sessionStore)
            erasable.append(sessionStore)
        } else {
            apple = AppleBrain()
        }

        #if DEBUG
        let brains: [BrainKind: Brain] = [.apple: apple, .ollama: OllamaBrain()]
        #else
        let brains: [BrainKind: Brain] = [.apple: apple]
        #endif

        let reminderStore = ReminderStore()
        erasable.append(reminderStore)

        return AppDependencies(
            systemStatus: SystemStatusService(),
            appLauncher: AppLauncherService(),
            launchAtLogin: LaunchAtLoginService(),
            buddySettings: BuddySettingsStore(),
            profile: ProfileStore(),
            brains: brains,
            reminderStore: reminderStore,
            reminderScheduler: ReminderNotificationCenter.shared,
            erasableStores: erasable
        )
    }

    // MARK: - Factories

    func makeChatStore() -> ChatStore {
        ChatStore(brains: brains)
    }

    func makeCreateReminderUseCase() -> CreateReminderFromTextUseCase {
        CreateReminderFromTextUseCase(store: reminderStore, notifications: reminderScheduler)
    }
}
```

- [ ] **Step 8: Generate, build, dan jalankan seluruh test**

Run: `xcodegen generate`, lalu Build, lalu Test semua, lalu `./scripts/verify-boundaries.sh`.
Expected: `** BUILD SUCCEEDED **`; sekitar `94 tests in 19 suites passed`; `** TEST SUCCEEDED **`; `✅ batas SharedCore aman`. Kalau build gagal karena ada berkas lain yang masih merujuk tipe yang dihapus, cari dengan grep di Step 9. Hapus rujukannya hanya kalau memang bagian wellness; kalau ternyata bukan wellness, berhenti dan laporkan.

- [ ] **Step 9: Pastikan tidak ada sisa wellness**

Run:

```bash
grep -rnE "WellnessStore|WellnessStoring|WellnessViewModel|WellnessNotificationCenter|ReminderSchedule|ReminderKind|ReminderEvent|TrackFocusSession|IdleTime|ScreenTimeEntry|WellnessGoalProgress|SnoozedReminder|BuddyReminder|\bNotificationScheduling\b|HomePage|HistoryPage" \
  DinoPocketMac SharedCore DinoPocketTests --include='*.swift' \
  | grep -vE "Legacy/|ContentView|PetActivityWidgets|Haptics.swift" \
  | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//'
```

Expected: tidak ada output. Filter terakhir membuang baris komentar, yang boleh menyebut nama lama untuk menjelaskan sejarah (misalnya "Menggantikan ReminderSchedule" di `Reminder.swift`). Kode tidak boleh.

- [ ] **Step 10: Commit**

```bash
git add -A DinoPocketMac SharedCore DinoPocketTests
git commit -m "$(cat <<EOF
refactor(a3): hapus wellness — dashboard, Desk Time, History, target, pet

Di luar visi v1 (chatbot + karakter 3D). Reminder sudah pindah ke domain
sendiri di commit sebelumnya, jadi tidak ada fitur yang rusak. UI
sementara: sidebar Apl AI + Settings, dan tombol Show/Hide Buddy di
toolbar menggantikan tombol di HomePage.

Kode lengkapnya tersimpan di $BASE — pulihkan dengan
git show $BASE:<path> (mis. SharedCore/Infrastructure/Persistence/WellnessStore.swift).

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

Periksa: `git log -1 --format=%B | grep "git show"` harus menampilkan hash nyata, bukan `$BASE`.

---

### Task 8: Apple Intelligence satu-satunya brain (A5, bagian 1)

**Files:**
- Create: `SharedCore/Infrastructure/Services/AplInstructions.swift`
- Delete: `SharedCore/Infrastructure/Services/OllamaBrain.swift`, `SharedCore/Data/Enums/BrainKind.swift`, `SharedCore/Data/Enums/Persona.swift`, `DinoPocketMac/Presentation/Views/BrainSegmentedPicker.swift`, `DinoPocketTests/OllamaBrainTests.swift`
- Modify: `SharedCore/Infrastructure/Services/Brain.swift`, `AppleBrain.swift`
- Rewrite: `DinoPocketMac/Presentation/ViewModels/ChatStore.swift`, `DinoPocketMac/Presentation/Views/SidebarView.swift`, `DinoPocketMac/App/AppDependencies.swift`
- Modify: `ChatPage.swift`, `OnboardingView.swift`, `SettingsPage.swift`, `DashboardTemplate.swift`
- Modify tests: `ChatStoreTests.swift`, `BrainTypesTests.swift`, `AppleBrainTests.swift`
- Rewrite test: `ChatAvailabilityTests.swift`

**Interfaces:**
- Consumes: semua yang dihasilkan Task 2–7.
- Produces:
  - `protocol Brain { func availability() async -> BrainAvailability; func reply(to history: [ChatMessage]) -> AsyncThrowingStream<String, Error> }`
  - `enum AplInstructions { static let text: String }`
  - `ChatStore.init(brain: Brain?)`, `func availability() async -> BrainAvailability`
  - `SidebarView(selection:)` tanpa parameter `chat`
  - `AppDependencies.brain: Brain` (menggantikan `brains`)

- [ ] **Step 1: Sesuaikan test dengan API brain tunggal (gagal)**

Ganti seluruh isi `DinoPocketTests/BrainTypesTests.swift`:

```swift
import Foundation
import Testing
@testable import Apl

struct BrainTypesTests {

    /// Reminder dibuat parser, bukan model. Instructions harus melarang model
    /// mengaku membuat reminder, supaya ia tidak menjawab "Sure!" tanpa bukti.
    @Test func instructionsForbidTheModelFromClaimingReminders() {
        #expect(AplInstructions.text.contains("cannot create, change, or cancel reminders"))
    }

    @Test func chatMessageRoundTripsThroughCodable() throws {
        let msg = ChatMessage(id: UUID(), role: .user, text: "halo", date: Date(timeIntervalSince1970: 0))
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)
        #expect(decoded == msg)
    }
}
```

Di `DinoPocketTests/AppleBrainTests.swift`, hapus:

```swift

    @MainActor @Test func kindIsApple() {
        #expect(AppleBrain().kind == .apple)
    }
```

Ganti seluruh isi `DinoPocketTests/ChatAvailabilityTests.swift`:

```swift
import Foundation
import Testing
@testable import Apl

@Suite("Ketersediaan Apple Intelligence untuk layar chat")
struct ChatAvailabilityTests {

    @MainActor
    @Test func chatReportsWhyAppleIntelligenceIsUnavailable() async {
        let chat = ChatStore(brain: StubBrain(availability: .unavailable("Enable Apple Intelligence in System Settings.")))

        #expect(await chat.availability() == .unavailable("Enable Apple Intelligence in System Settings."))
    }

    @MainActor
    @Test func chatWithoutABrainIsUnavailable() async {
        let chat = ChatStore(brain: nil)

        let availability = await chat.availability()

        guard case .unavailable = availability else {
            Issue.record("expected .unavailable, got \(availability)")
            return
        }
    }
}

private struct StubBrain: Brain {
    let stubbed: BrainAvailability

    init(availability: BrainAvailability) {
        self.stubbed = availability
    }

    func availability() async -> BrainAvailability { stubbed }

    func reply(to history: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}
```

Di `DinoPocketTests/ChatStoreTests.swift`:

(a) Ganti:

```swift
private struct StubBrain: Brain {
    let kind: BrainKind
    var chunks: [String]
    var available: BrainAvailability = .ready
    func availability() async -> BrainAvailability { available }
    func reply(to history: [ChatMessage], persona: Persona) -> AsyncThrowingStream<String, Error> {
```

dengan:

```swift
private struct StubBrain: Brain {
    var chunks: [String]
    var available: BrainAvailability = .ready
    func availability() async -> BrainAvailability { available }
    func reply(to history: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
```

(b) Di `GatedBrain`, hapus baris `    let kind: BrainKind`, hapus baris `    init(kind: BrainKind) { self.kind = kind }` beserta baris kosong sesudahnya, lalu ganti `    func reply(to history: [ChatMessage], persona: Persona) -> AsyncThrowingStream<String, Error> {` dengan `    func reply(to history: [ChatMessage]) -> AsyncThrowingStream<String, Error> {`.

(c) Ganti:

```swift
        let store = ChatStore(brains: [.ollama: StubBrain(kind: .ollama, chunks: ["A", "AB", "ABC"])])
        store.activeBrain = .ollama
```

dengan:

```swift
        let store = ChatStore(brain: StubBrain(chunks: ["A", "AB", "ABC"]))
```

(d) Ganti seluruh test `fallsBackWhenActiveBrainUnavailable()` (dari `    @MainActor @Test func fallsBackWhenActiveBrainUnavailable() async {` sampai `    }` penutupnya) dengan:

```swift
    @MainActor @Test func unavailableAppleIntelligenceLeavesANoticeAndNoReply() async {
        UserDefaults.standard.removeObject(forKey: "jarvis.chat.recent")
        let store = ChatStore(brain: StubBrain(chunks: ["X"], available: .unavailable("nope")))

        await store.send("tes")

        #expect(store.messages.map(\.role) == [.user])
        #expect(store.noticeMessage != nil)
    }
```

(e) Ganti **kedua** kemunculan:

```swift
        let brain = GatedBrain(kind: .ollama)
        let store = ChatStore(brains: [.ollama: brain])
        store.activeBrain = .ollama
```

dengan:

```swift
        let brain = GatedBrain()
        let store = ChatStore(brain: brain)
```

(f) Di `chatHandlingReminders`, ganti `        let chat = ChatStore(brains: [:])` dengan `        let chat = ChatStore(brain: nil)`.

Hapus test Ollama:

```bash
git rm DinoPocketTests/OllamaBrainTests.swift
```

- [ ] **Step 2: Jalankan dan pastikan gagal**

Run: `xcodegen generate`, lalu Test semua.
Expected: FAIL, kompilasi gagal dengan `cannot find 'AplInstructions' in scope` dan `extra argument 'brain' in call` / `incorrect argument label`.

- [ ] **Step 3: Satukan brain**

Buat `SharedCore/Infrastructure/Services/AplInstructions.swift`:

```swift
//
//  AplInstructions.swift
//  SharedCore
//
//  Instructions tetap untuk sesi Foundation Models. Satu persona, satu teks.
//

import Foundation

enum AplInstructions {
    static let text = """
    You are Apl, a warm and friendly companion that lives on this Mac. \
    Speak casually, briefly, and encouragingly without lecturing, in English. \
    You cannot create, change, or cancel reminders yourself. \
    If the user asks for one, tell them to write it like: "Remind me to … at 3 PM".
    """
}
```

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
}
```

Di `SharedCore/Infrastructure/Services/AppleBrain.swift`:

(a) Hapus:

```swift
    nonisolated var kind: BrainKind { .apple }

```

(b) Ganti:

```swift
    /// Wadah sesi hidup beserta persona yang membentuknya. Persona yang berubah
    /// harus memulai sesi baru — instructions hanya bisa ditetapkan saat sesi
    /// dibuat, jadi mempertahankan sesi lama berarti persona di UI berbohong.
    ///
    /// Deployment target sudah macOS 26.2 sehingga `@available` wrapper tidak
    /// lagi diperlukan; stored property bisa dideklarasikan langsung.
    @available(macOS 26.0, iOS 26.0, *)
    final class SessionBox {
        var session: LanguageModelSession?
        var persona: Persona?
    }
```

dengan:

```swift
    /// Wadah sesi hidup. Instructions ditetapkan saat sesi dibuat dan tidak
    /// pernah berubah (`AplInstructions`), jadi satu sesi bertahan selama app hidup.
    ///
    /// Deployment target sudah macOS 26.2 sehingga `@available` wrapper tidak
    /// lagi diperlukan; stored property bisa dideklarasikan langsung.
    @available(macOS 26.0, iOS 26.0, *)
    final class SessionBox {
        var session: LanguageModelSession?
    }
```

(c) Ganti:

```swift
    /// Gabungkan riwayat percakapan menjadi satu prompt untuk Foundation Models
    /// (streamResponse menerima satu String; persona sudah di-set via instructions).
    /// Meniru perilaku multi-turn OllamaBrain yang meneruskan seluruh history.
```

dengan:

```swift
    /// Gabungkan riwayat percakapan menjadi satu prompt untuk Foundation Models
    /// (streamResponse menerima satu String; instructions sudah di-set saat sesi dibuat).
```

(d) Ganti `    nonisolated func reply(to history: [ChatMessage], persona: Persona) -> AsyncThrowingStream<String, Error> {` dengan `    nonisolated func reply(to history: [ChatMessage]) -> AsyncThrowingStream<String, Error> {`

(e) Ganti `                        try await self.stream(history: history, persona: persona) { chunk in` dengan `                        try await self.stream(history: history) { chunk in`

(f) Ganti:

```swift
    private func stream(history: [ChatMessage],
                        persona: Persona,
                        onChunk: @escaping (String) -> Void) async throws {
```

dengan:

```swift
    private func stream(history: [ChatMessage],
                        onChunk: @escaping (String) -> Void) async throws {
```

(g) Hapus:

```swift
        // Persona berubah -> sesi harus lahir ulang (lihat catatan di SessionBox).
        if box.persona != persona { box.session = nil; box.persona = persona }

```

(h) Ganti `                box.session = LanguageModelSession(instructions: persona.systemPrompt)` dengan `                box.session = LanguageModelSession(instructions: AplInstructions.text)`

Ganti seluruh isi `DinoPocketMac/Presentation/ViewModels/ChatStore.swift`:

```swift
import Foundation
import Observation

@MainActor
@Observable
final class ChatStore {
    var messages: [ChatMessage] = []
    var isStreaming = false
    var noticeMessage: String?

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
    private var streamTask: Task<Void, Never>?
    private var streamGeneration = 0

    /// Reminder yang sedang menunggu jawaban "jam berapa?". Hanya bertahan satu
    /// giliran: pesan berikutnya yang bukan ungkapan waktu membuangnya.
    private var reminderAwaitingTime: PendingReminder?

    private struct PendingReminder {
        let title: String?
    }

    init(brain: Brain?) {
        self.brain = brain
        if let data = UserDefaults.standard.data(forKey: "jarvis.chat.recent"),
           let restored = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            messages = restored
        }
    }

    /// Membuang riwayat percakapan yang tersimpan beserta yang ada di memori.
    func eraseAllStoredData() {
        messages = []
        noticeMessage = nil
        reminderAwaitingTime = nil
        UserDefaults.standard.removeObject(forKey: "jarvis.chat.recent")
    }

    /// Ketersediaan Apple Intelligence, tanpa efek samping — untuk gerbang
    /// layar chat, onboarding, dan baris status di Settings.
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
        messages.append(ChatMessage(id: UUID(), role: .user, text: trimmed, date: .now))

        if let reply = await localReminderReply(to: trimmed) {
            noticeMessage = nil
            streamGeneration += 1
            messages.append(ChatMessage(id: UUID(), role: .assistant, text: reply, date: .now))
            persistRecent()
            return
        }

        guard let brain, await brain.availability() == .ready else {
            noticeMessage = "Apple Intelligence isn't available yet. Enable it in System Settings to chat."
            return
        }
        noticeMessage = nil

        let history = messages
        var assistant = ChatMessage(id: UUID(), role: .assistant, text: "", date: .now)
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
    private func localReminderReply(to text: String) async -> String? {
        guard let createReminder else { return nil }

        if let pending = reminderAwaitingTime {
            reminderAwaitingTime = nil
            if case .created(_, let confirmation)? = await createReminder.complete(title: pending.title,
                                                                                 timeText: text) {
                return confirmation
            }
        }

        switch await createReminder.execute(text: text) {
        case .created(_, let confirmation):
            return confirmation
        case .needsTime(let title, let question):
            reminderAwaitingTime = PendingReminder(title: title)
            return question
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
            UserDefaults.standard.set(data, forKey: "jarvis.chat.recent")
        }
    }
}

extension ChatStore: LocallyErasable {}
```

`pendingPrompt` dan `consumePendingPrompt()` ikut dihapus: satu-satunya pengisinya adalah quick action di `HomePage`, yang sudah dihapus di Task 7.

- [ ] **Step 4: Sesuaikan view dan composition root**

`DinoPocketMac/Presentation/Views/ChatPage.swift`:
- Di komentar header, ganti `//  Page: functional chat surface — message history, persona switcher, and` dengan `//  Page: functional chat surface — message history and`
- Ganti:

```swift
        .task {
            availability = await chat.bestAvailability()
            if let pending = chat.consumePendingPrompt() {
                draft = pending
            }
        }
```

dengan:

```swift
        .task {
            availability = await chat.availability()
        }
```

- Hapus seluruh blok toolbar persona:

```swift
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Persona", selection: $chat.persona) {
                    ForEach(Persona.allCases, id: \.self) { persona in
                        Text(persona.label).tag(persona)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
```

- Di `#Preview`, ganti `ChatPage(chat: ChatStore(brains: [:]))` dengan `ChatPage(chat: ChatStore(brain: nil))`

`DinoPocketMac/Presentation/Views/OnboardingView.swift`:
- Ganti `        .task { appleAvailability = await chat.availability(of: .apple) }` dengan `        .task { appleAvailability = await chat.availability() }`
- Di `#Preview`, ganti `ChatStore(brains: [:])` dengan `ChatStore(brain: nil)`

`DinoPocketMac/Presentation/Views/SettingsPage.swift`:
- Hapus blok dari `                #if DEBUG` sampai `}` penutup `Picker("Persona", ...)`:

```swift
                #if DEBUG
                // Ollama hanya tersedia di build DEBUG; tidak pernah ikut rilis.
                Picker("Brain (debug)", selection: $chat.activeBrain) {
                    ForEach(BrainKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                #endif

                Picker("Persona", selection: $chat.persona) {
                    ForEach(Persona.allCases, id: \.self) { persona in
                        Text(persona.label).tag(persona)
                    }
                }
```

- Ganti `            appleAvailability = await chat.availability(of: .apple)` dengan `            appleAvailability = await chat.availability()`
- Di `#Preview`, ganti `ChatStore(brains: [:])` dengan `ChatStore(brain: nil)`

`DinoPocketMac/Presentation/Views/DashboardTemplate.swift`:
- Ganti `            SidebarView(selection: $selection, chat: chat)` dengan `            SidebarView(selection: $selection)`
- Di `#Preview`, ganti `ChatStore(brains: [:])` dengan `ChatStore(brain: nil)`

Ganti seluruh isi `DinoPocketMac/Presentation/Views/SidebarView.swift`:

```swift
//
//  SidebarView.swift
//  Apl
//
//  Organism: dashboard navigation sidebar.
//

import SwiftUI

enum DashboardSection: String, CaseIterable, Identifiable {
    case chat = "Apl AI"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .chat: "sparkles"
        case .settings: "gearshape"
        }
    }
}

struct SidebarView: View {
    @Binding var selection: DashboardSection

    var body: some View {
        List(selection: $selection) {
            ForEach(DashboardSection.allCases) { section in
                Label(section.rawValue, systemImage: section.icon).tag(section)
            }
        }
        .listStyle(.sidebar)
    }
}

#Preview {
    SidebarView(selection: .constant(.chat))
        .frame(width: 220, height: 400)
}
```

Ganti seluruh isi `DinoPocketMac/App/AppDependencies.swift`:

```swift
//
//  AppDependencies.swift
//  AplMac
//
//  Composition root, mengikuti pola Taggo: satu tempat yang tahu implementasi
//  konkret mana yang dipakai, dan pabrik untuk ViewModel.
//

import Foundation

@MainActor
struct AppDependencies {

    let systemStatus: SystemStatusProviding
    let appLauncher: AppLaunching
    let launchAtLogin: LaunchAtLoginManaging
    let buddySettings: BuddySettingsStore
    let profile: ProfileStore

    /// Apple Intelligence — satu-satunya otak (spec A §2 #7).
    let brain: Brain

    /// Satu-satunya instance ReminderStore: chat dan daftar reminder harus
    /// membaca daftar yang sama.
    let reminderStore: ReminderStore
    let reminderScheduler: any ReminderScheduling

    /// Didaftarkan eksplisit supaya Erase All Data tidak melewatkannya.
    let erasableStores: [any LocallyErasable]

    static func live() -> AppDependencies {
        // Transcript dipersist supaya percakapan bertahan lintas peluncuran —
        // inti dari "asisten yang ingat kemarin".
        let brain: Brain
        var erasable: [any LocallyErasable] = []
        if #available(macOS 26.0, *) {
            let sessionStore = FileChatSessionStore()
            brain = AppleBrain(sessionStore: sessionStore)
            erasable.append(sessionStore)
        } else {
            brain = AppleBrain()
        }

        let reminderStore = ReminderStore()
        erasable.append(reminderStore)

        return AppDependencies(
            systemStatus: SystemStatusService(),
            appLauncher: AppLauncherService(),
            launchAtLogin: LaunchAtLoginService(),
            buddySettings: BuddySettingsStore(),
            profile: ProfileStore(),
            brain: brain,
            reminderStore: reminderStore,
            reminderScheduler: ReminderNotificationCenter.shared,
            erasableStores: erasable
        )
    }

    // MARK: - Factories

    func makeChatStore() -> ChatStore {
        ChatStore(brain: brain)
    }

    func makeCreateReminderUseCase() -> CreateReminderFromTextUseCase {
        CreateReminderFromTextUseCase(store: reminderStore, notifications: reminderScheduler)
    }
}
```

Hapus sisa multi-brain:

```bash
git rm SharedCore/Infrastructure/Services/OllamaBrain.swift \
       SharedCore/Data/Enums/BrainKind.swift \
       SharedCore/Data/Enums/Persona.swift \
       DinoPocketMac/Presentation/Views/BrainSegmentedPicker.swift
```

- [ ] **Step 5: Generate, build, dan jalankan seluruh test**

Run: `xcodegen generate`, lalu Build, lalu Test semua, lalu `./scripts/verify-boundaries.sh`.
Expected: `** BUILD SUCCEEDED **`; sekitar `86 tests in 18 suites passed`; `** TEST SUCCEEDED **`; `✅ batas SharedCore aman`.

- [ ] **Step 6: Pastikan tidak ada sisa multi-brain**

Run:

```bash
grep -rnE "Ollama|BrainKind|Persona|activeBrain|bestAvailability|resolveBrain|BrainSegmentedPicker|pendingPrompt|availability\(of:" \
  DinoPocketMac SharedCore DinoPocketTests --include='*.swift' \
  | grep -vE "Legacy/|ContentView|PetActivityWidgets|Haptics.swift" \
  | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//'
```

Expected: tidak ada output.

- [ ] **Step 7: Commit**

```bash
git add -A DinoPocketMac SharedCore DinoPocketTests
git commit -m "$(cat <<'EOF'
refactor(a5): Apple Intelligence satu-satunya brain

Ollama, BrainKind, pemilihan brain, fallback antar-brain, dan toggle
persona dihapus — termasuk di build DEBUG. Brain tinggal satu protokol
kecil untuk test, dan AppleBrain memakai AplInstructions yang tetap,
yang melarang model mengaku membuat reminder.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: Bersihkan data lama, perbarui `verify-release.sh`, dan verifikasi akhir (A5, bagian 2)

**Files:**
- Create: `DinoPocketMac/Infrastructure/Persistence/LegacyDataCleanup.swift`
- Create: `DinoPocketTests/LegacyDataCleanupTests.swift`
- Modify: `DinoPocketMac/App/AppDependencies.swift` (`live()`)
- Rewrite: `scripts/verify-release.sh`
- Modify: `README.md` (baris jumlah test)

**Interfaces:**
- Consumes: `LocallyErasable` (Task 2); `FileChatSessionStore` (sudah ada); `AppDependencies` (Task 8).
- Produces:
  - `@MainActor struct LegacyDataCleanup: LocallyErasable` dengan `init(standard: UserDefaults = .standard, appGroup: UserDefaults? = UserDefaults(suiteName: "group.com.ega.apl"), transcripts: (any LocallyErasable)?, removeKeychainItem: @escaping () -> Void = LegacyDataCleanup.removeAppleUserID, removePendingNotifications: @escaping ([String]) -> Void = LegacyDataCleanup.removePending(withPrefixes:))`, `func run(force: Bool = false)`, konstanta `doneKey`, `appGroupSuite`, `appGroupKeys`, `activeBrainKey`, `chatRecentKey`, `notificationPrefixes`

- [ ] **Step 1: Tulis test pembersihan yang gagal**

Buat `DinoPocketTests/LegacyDataCleanupTests.swift`:

```swift
import Foundation
import Testing
@testable import Apl

@MainActor
private final class CleanupSpy: LocallyErasable {
    private(set) var transcriptErasures = 0
    private(set) var keychainRemovals = 0
    private(set) var notificationPrefixes: [[String]] = []

    func eraseAllStoredData() { transcriptErasures += 1 }
    func removeKeychainItem() { keychainRemovals += 1 }
    func removeNotifications(_ prefixes: [String]) { notificationPrefixes.append(prefixes) }
}

/// Suite "app group" di sini SENGAJA palsu: test tidak boleh menghapus data
/// di suite sungguhan milik mesin pengembang.
@MainActor
struct LegacyDataCleanupTests {

    private func isolatedDefaults(_ name: String) -> UserDefaults {
        let suite = "test.legacy.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func makeCleanup(standard: UserDefaults, appGroup: UserDefaults,
                             spy: CleanupSpy) -> LegacyDataCleanup {
        LegacyDataCleanup(standard: standard, appGroup: appGroup, transcripts: spy,
                          removeKeychainItem: { spy.removeKeychainItem() },
                          removePendingNotifications: { spy.removeNotifications($0) })
    }

    @Test func firstRunRemovesEveryLegacyTrace() {
        let standard = isolatedDefaults("first.standard")
        let appGroup = isolatedDefaults("first.group")
        for key in LegacyDataCleanup.appGroupKeys {
            appGroup.set(Data([1]), forKey: key)
        }
        standard.set("ollama", forKey: LegacyDataCleanup.activeBrainKey)
        standard.set(Data([1]), forKey: LegacyDataCleanup.chatRecentKey)
        let spy = CleanupSpy()

        makeCleanup(standard: standard, appGroup: appGroup, spy: spy).run()

        for key in LegacyDataCleanup.appGroupKeys {
            #expect(appGroup.object(forKey: key) == nil, "kunci \(key) tertinggal")
        }
        #expect(standard.object(forKey: LegacyDataCleanup.activeBrainKey) == nil)
        #expect(standard.object(forKey: LegacyDataCleanup.chatRecentKey) == nil)
        #expect(spy.transcriptErasures == 1)
        #expect(spy.keychainRemovals == 1)
        #expect(spy.notificationPrefixes == [["wellness.", "custom."]])
        #expect(standard.bool(forKey: LegacyDataCleanup.doneKey))
    }

    @Test func laterLaunchesDoNothing() {
        let standard = isolatedDefaults("later.standard")
        let appGroup = isolatedDefaults("later.group")
        let spy = CleanupSpy()
        let cleanup = makeCleanup(standard: standard, appGroup: appGroup, spy: spy)
        cleanup.run()
        appGroup.set(Data([1]), forKey: "pet.mood")

        cleanup.run()

        #expect(appGroup.object(forKey: "pet.mood") != nil)
        #expect(spy.keychainRemovals == 1)
    }

    /// Erase All Data membersihkan lagi, tetapi percakapan milik pengguna
    /// bukan urusan cleanup — `ChatStore` sendiri yang menghapusnya.
    @Test func forcedRunCleansAgainButLeavesTheConversationToChatStore() {
        let standard = isolatedDefaults("forced.standard")
        let appGroup = isolatedDefaults("forced.group")
        let spy = CleanupSpy()
        let cleanup = makeCleanup(standard: standard, appGroup: appGroup, spy: spy)
        cleanup.run()
        appGroup.set(Data([1]), forKey: "pet.mood")
        standard.set(Data([1]), forKey: LegacyDataCleanup.chatRecentKey)

        cleanup.run(force: true)

        #expect(appGroup.object(forKey: "pet.mood") == nil)
        #expect(standard.object(forKey: LegacyDataCleanup.chatRecentKey) != nil)
        #expect(spy.transcriptErasures == 1)
        #expect(spy.keychainRemovals == 2)
    }

    @Test func erasingAllDataForcesTheCleanup() {
        let standard = isolatedDefaults("erase.standard")
        let appGroup = isolatedDefaults("erase.group")
        let spy = CleanupSpy()
        let cleanup = makeCleanup(standard: standard, appGroup: appGroup, spy: spy)
        cleanup.run()
        appGroup.set(Data([1]), forKey: "wellness.goalProgress")

        cleanup.eraseAllStoredData()

        #expect(appGroup.object(forKey: "wellness.goalProgress") == nil)
    }
}
```

- [ ] **Step 2: Jalankan dan pastikan gagal**

Run: `xcodegen generate`, lalu Test dengan `-only-testing:DinoPocketTests/LegacyDataCleanupTests`
Expected: FAIL, `cannot find 'LegacyDataCleanup' in scope`.

- [ ] **Step 3: Implementasikan pembersihan**

Buat `DinoPocketMac/Infrastructure/Persistence/LegacyDataCleanup.swift`:

```swift
//
//  LegacyDataCleanup.swift
//  AplMac
//
//  Membersihkan jejak data dari era wellness dan Sign in with Apple.
//
//  App belum pernah rilis, jadi data lama tidak dimigrasikan (spec A §2 #4) —
//  tetapi ia tetap harus hilang dari disk. Tanpa ini, Erase All Data
//  meninggalkan riwayat wellness di suite app group dan identifier Apple ID
//  di Keychain, karena tidak ada lagi store yang mengaku memilikinya.
//

import Foundation
import Security
import UserNotifications

@MainActor
struct LegacyDataCleanup {

    static let doneKey = "apl.legacyCleanupDone"
    static let appGroupSuite = "group.com.ega.apl"

    /// Kunci `WellnessStore` yang dihapus di sub-project A. Ditulis literal
    /// karena store-nya sudah tidak ada untuk ditanya.
    static let appGroupKeys = [
        "pet.mood", "pet.hunger", "pet.energy", "pet.lastFed", "pet.affection",
        "wellness.screenTimeHistory", "wellness.reminderHistory", "wellness.reminderEventsSeen",
        "wellness.remindersEnabled", "wellness.goalProgress", "wellness.snoozedReminders",
        "pet.customSchedules",
    ]

    static let activeBrainKey = "jarvis.activeBrain"
    static let chatRecentKey = "jarvis.chat.recent"

    /// Identifier notifikasi jadwal wellness bawaan ("wellness.") dan reminder
    /// chat versi lama ("custom.").
    static let notificationPrefixes = ["wellness.", "custom."]

    private let standard: UserDefaults
    private let appGroup: UserDefaults?
    private let transcripts: (any LocallyErasable)?
    private let removeKeychainItem: () -> Void
    private let removePendingNotifications: ([String]) -> Void

    init(standard: UserDefaults = .standard,
         appGroup: UserDefaults? = UserDefaults(suiteName: LegacyDataCleanup.appGroupSuite),
         transcripts: (any LocallyErasable)?,
         removeKeychainItem: @escaping () -> Void = LegacyDataCleanup.removeAppleUserID,
         removePendingNotifications: @escaping ([String]) -> Void = LegacyDataCleanup.removePending(withPrefixes:)) {
        self.standard = standard
        self.appGroup = appGroup
        self.transcripts = transcripts
        self.removeKeychainItem = removeKeychainItem
        self.removePendingNotifications = removePendingNotifications
    }

    /// - Parameter force: `false` saat app dibuka (sekali per instalasi);
    ///   `true` dari Erase All Data (selalu).
    func run(force: Bool = false) {
        let isFirstRun = !standard.bool(forKey: Self.doneKey)
        guard force || isFirstRun else { return }

        for key in Self.appGroupKeys {
            appGroup?.removeObject(forKey: key)
        }
        standard.removeObject(forKey: Self.activeBrainKey)

        // Percakapan lama dibuat dengan instructions persona lama, dan transcript
        // yang dilanjutkan terus membawa instructions itu. Hanya pada jalan
        // pertama: setelahnya percakapan milik pengguna, dan hanya Erase All Data
        // (lewat ChatStore) yang boleh menghapusnya.
        if isFirstRun {
            standard.removeObject(forKey: Self.chatRecentKey)
            transcripts?.eraseAllStoredData()
        }

        removeKeychainItem()
        removePendingNotifications(Self.notificationPrefixes)
        standard.set(true, forKey: Self.doneKey)
    }

    /// Item Keychain milik AccountStore/KeychainStore yang sudah dihapus.
    nonisolated static func removeAppleUserID() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.ega.apl.account",
            kSecAttrAccount as String: "appleUserID",
        ]
        SecItemDelete(query as CFDictionary)
    }

    nonisolated static func removePending(withPrefixes prefixes: [String]) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiers = requests.map(\.identifier).filter { identifier in
                prefixes.contains { identifier.hasPrefix($0) }
            }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }
}

extension LegacyDataCleanup: LocallyErasable {
    func eraseAllStoredData() {
        run(force: true)
    }
}
```

- [ ] **Step 4: Jalankan test pembersihan**

Run: `xcodegen generate`, lalu Test dengan `-only-testing:DinoPocketTests/LegacyDataCleanupTests`
Expected: 4 test PASS.

- [ ] **Step 5: Jalankan pembersihan sebelum store apa pun membaca data**

Di `DinoPocketMac/App/AppDependencies.swift`, ganti:

```swift
        let brain: Brain
        var erasable: [any LocallyErasable] = []
        if #available(macOS 26.0, *) {
            let sessionStore = FileChatSessionStore()
            brain = AppleBrain(sessionStore: sessionStore)
            erasable.append(sessionStore)
        } else {
            brain = AppleBrain()
        }

        let reminderStore = ReminderStore()
        erasable.append(reminderStore)
```

dengan:

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

        // Sebelum store apa pun membaca data: ChatStore memuat percakapan
        // tersimpan saat dibuat, jadi pembersihan harus mendahuluinya.
        let cleanup = LegacyDataCleanup(transcripts: transcripts)
        cleanup.run()

        let reminderStore = ReminderStore()
        erasable.append(reminderStore)
        erasable.append(cleanup)
```

Catatan: unit test berjalan di dalam `Apl.app` sebagai test host, jadi test pertama setelah task ini ikut menjalankan pembersihan satu kali di mesin pengembang. Riwayat chat dan data wellness lama di mesin itu akan hilang, dan memang itu tujuan pembersihannya.

- [ ] **Step 6: Tulis ulang `verify-release.sh`**

Ganti seluruh isi `scripts/verify-release.sh`:

```bash
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
if xcodebuild -project "${PROJECT}.xcodeproj" -target "$TARGET" -showBuildSettings -configuration Release 2>/dev/null \
   | grep -q "INFOPLIST_KEY_NSHumanReadableCopyright = ."; then
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
```

- [ ] **Step 7: Jalankan seluruh pemeriksaan otomatis**

Run, berurutan:
1. `xcodegen generate`
2. Test semua. Expected: sekitar `90 tests in 19 suites passed` dan `** TEST SUCCEEDED **`. Catat angka persisnya untuk Step 8.
3. `./scripts/verify-boundaries.sh`. Expected: `✅ batas SharedCore aman`
4. `./scripts/verify-release.sh`. Expected: tidak ada baris `❌`, baris terakhir `✅ konfigurasi Release siap`, exit code 0. Baris provisioning boleh `⚠️`.
5. DoD grep:

```bash
grep -rnE "ASAuthorization|applesignin|WellnessStore|ReminderKind|ReminderSchedule|Persona|Ollama|BrainKind" \
  DinoPocketMac SharedCore --include='*.swift' \
  | grep -vE "Legacy/|ContentView|PetActivityWidgets|Haptics.swift" \
  | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//'
```

Expected: tidak ada output. Filter terakhir membuang baris komentar yang menjelaskan sejarah.

- [ ] **Step 8: Perbarui jumlah test di README**

Di `README.md`, ganti `./scripts/test.sh DinoPocket DinoPocketMac   # 77 test, 19 suite` dengan angka persis dari Step 7, misalnya `./scripts/test.sh DinoPocket DinoPocketMac   # 90 test, 19 suite`.

- [ ] **Step 9: Verifikasi di app sungguhan**

Build dan buka app:

```bash
xcodebuild build -project DinoPocket.xcodeproj -scheme DinoPocketMac \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath build/dd 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
open build/dd/Build/Products/Debug/Apl.app
```

Lakukan dan catat hasil setiap langkah:
1. Settings → **Erase All Data…** → **Erase Everything**. Expected: app kembali ke onboarding.
2. Onboarding: isi nama panggilan, **Continue**, **Allow notifications**, **Continue**, **Start**. Expected: tidak ada langkah login; dashboard berisi **Apl AI** dan **Settings** saja.
3. Chat: `remind me to call mom in 1 minute`. Expected: konfirmasi `Done — I'll remind you to call mom in 1 minute (…)`. Tunggu sampai sekitar 70 detik. Expected: satu banner notifikasi berjudul **Call mom**, tidak berulang.
4. Chat: `remind me to drink water`. Expected: `What time should I remind you to drink water?`. Lalu kirim `5pm`. Expected: `Done — I'll remind you to drink water today at 5:00 PM.` (atau `tomorrow at` bila sudah lewat pukul 17.00).
5. Chat: `remind me every day at 9am to stretch`. Expected: `Done — I'll remind you to stretch every day at 9:00 AM.`
6. Chat: `remind me to call dad in 1 minute`, lalu **segera** Settings → **Erase All Data…** → **Erase Everything**. Tunggu sekitar 70 detik. Expected: tidak ada notifikasi **Call dad**, dan app kembali ke onboarding.

Kalau salah satu hasil tidak sesuai, jangan commit. Laporkan langkah, hasil yang terlihat, dan hasil yang diharapkan.

- [ ] **Step 10: Commit**

```bash
git add DinoPocketMac/Infrastructure/Persistence/LegacyDataCleanup.swift \
        DinoPocketTests/LegacyDataCleanupTests.swift \
        DinoPocketMac/App/AppDependencies.swift scripts/verify-release.sh README.md
git commit -m "$(cat <<'EOF'
feat(a5): bersihkan data lama dan selaraskan verify-release

LegacyDataCleanup menghapus kunci wellness di suite app group, item
Keychain Apple ID, notifikasi lama, dan (sekali) percakapan berpersona
lama — saat app pertama dibuka dan setiap Erase All Data. verify-release
kini menjaga keputusan A: tanpa entitlement SIWA, tanpa Ollama, dan
setiap model yang dirujuk CharacterAsset benar-benar ada.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

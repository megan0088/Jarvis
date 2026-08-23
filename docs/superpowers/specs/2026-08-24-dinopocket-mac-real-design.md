# DinoPocket — Mac App Versi Real — Design Spec

- Tanggal: 2026-08-24
- Status: Draft (menunggu review user)
- Basis kode: branch `main` @ `8741a0a`
- Target: **macOS** (Apple Silicon, macOS 26+), distribusi **Mac App Store**
- Menggantikan: `2026-08-21-jarvis-appstore-phase-a-design.md` (fase A tetap valid sebagai daftar fitur; dokumen ini menambahkan fondasi arsitektur di bawahnya)

> **Codename.** Nama produk final **belum diputuskan**. Dokumen ini memakai `DinoPocket`
> sebagai codename kerja. Seluruh titik yang harus berubah saat nama final ditetapkan
> terkumpul di §14 — jangan sebar keputusan nama ke luar daftar itu.

---

## 1. Konteks

Kode yang ada sekarang adalah **demo**, bukan produk. Ia dibuat untuk dipresentasikan:
ada tombol pemicu manual di jendela buddy, placeholder "History coming soon", string
Indonesia yang tercecer, dan `DEMO_NOTES.md` yang mendokumentasikan alur demo.

Tujuan dokumen ini: mengubahnya jadi **Mac app sungguhan yang bisa disubmit ke App Store**,
dengan fondasi yang siap menerima companion iPhone sebagai produk berikutnya.

Model produknya mengikuti **ROG OMNI (ASUS)** — companion desktop dengan karakter hidup,
AI lokal, dan pengingat — tapi seluruh kemampuannya dibangun di atas ekosistem Apple.
Ini bukan reverse engineering biner ASUS (mustahil di Mac dan melanggar EULA-nya),
melainkan implementasi ulang perilaku publiknya secara clean-room.

### Prinsip: panen demo, jangan migrasikan produk

Kode lama dibagi tiga, bukan dua:

| Kategori | Isi |
|---|---|
| **Dipanen** | `AppleBrain` (pemetaan availability), `ReminderIntent` (7 test), `PetStore` (akuntansi sesi harian), `Brain` + `ChatStore` (5 test), setup `NSPanel` buddy, `RobotCharacterView` |
| **Dibuang** | 8 tombol demo + selectornya, `Untitled.swift`, `ContentView.swift` (larut), placeholder History, seluruh string Indonesia, `DEMO_NOTES.md` |
| **Dikarantina** | ~1.700 baris karakter SpriteKit → `Legacy/`, tidak ikut build (§9) |

---

## 2. Keputusan yang mengikat

1. **All-Apple.** Otak AI = Foundation Models (on-device). `OllamaBrain` hanya di-wire pada build `DEBUG`; tidak ada entitlement `network.client` di rilis.
2. **Pemisahan target ala Taggo.** `SharedCore` + target per platform, bukan satu target multiplatform ber-`#if`.
3. **Tiga gelombang restrukturisasi selesai SEBELUM fitur v1 dan sebelum submit.** App belum pernah rilis, jadi tidak ada user yang dirugikan oleh pembedahan fondasi.
4. **v1 = Mac saja.** Companion iPhone dapat spec sendiri setelah Mac app jalan.
5. **Karakter = RealityKit 3D.** SpriteKit 2D dikarantina, tidak dihapus.
6. **Aset 3D belum final.** `Robot.usdz` dipakai sementara; user akan menyediakan model sendiri. Kode harus membuat penggantian jadi satu edit struct (§9).
7. **Copy UI: English.**
8. **Sandbox + Hardened Runtime tetap ON.**

---

## 3. Temuan verifikasi platform — JANGAN diselidiki ulang

Semua diverifikasi langsung terhadap SDK macOS 26.5 dan mesin dev (macOS 26.6.2) pada
2026-08-23/24. Dicatat di sini supaya tidak ada yang membuang waktu mengeceknya lagi.

### 3.1 HealthKit TIDAK bisa dipakai di Mac

| Cek | Hasil |
|---|---|
| `HealthKit.framework` di SDK macOS | **ada** |
| `HKHealthStore` anotasi | `API_AVAILABLE(…, macos(13.0))` |
| `HKHealthStore.isHealthDataAvailable()` di mesin nyata | **`false`** |
| `supportsHealthRecords()` | `false` |
| `Health.app` di macOS | **tidak ada** |
| Daemon health berjalan | **tidak ada** |

**Kesimpulan:** framework hadir untuk kompatibilitas Mac Catalyst/source-compat, tetapi
macOS tidak punya database Health. Tidak ada langkah, tidur, atau detak jantung untuk
dibaca — dan entitlement tidak akan memunculkannya.

*Caveat bukti:* probe dijalankan sebagai CLI tanpa signing/entitlement. Absennya Health.app
dan daemon di seluruh sistem adalah korroborasi kuat, bukan bukti formal.

### 3.2 Screen Time API TIDAK bisa dipakai di Mac

```
FamilyControls.AuthorizationCenter  → @available(macOS, unavailable)
DeviceActivity.DeviceActivityCenter → @available(macOS, unavailable)
```

Ketiga framework (`FamilyControls`, `DeviceActivity`, `ManagedSettings`) ada di SDK, tetapi
dua tipe yang dibutuhkan — otorisasi dan pemantauan — ditandai tidak tersedia di macOS.
**Screen time per-aplikasi mustahil di Mac.**

> **Pola yang berulang:** kehadiran framework di SDK ≠ kapabilitas tersedia. Dua kali
> terjadi hari ini. Selalu cek anotasi `@available` pada tipe yang benar-benar dipakai.

### 3.3 Foundation Models tersedia dan bekerja

`SystemLanguageModel.default.availability` → **`.available`** di mesin dev.

API terverifikasi di `.swiftinterface` (`arm64e-apple-macos`):

| API | Baris | Konsekuensi design |
|---|---|---|
| `extension Transcript : Codable` | 935 | Transcript bisa dipersist langsung |
| `LanguageModelSession(transcript:)` | 341 | Sesi bisa dilanjutkan lintas restart |
| `session.transcript` | 321 | Transcript hidup bisa dibaca |
| `prewarm(promptPrefix:)` | 342 | Token pertama bisa dipercepat |
| `GenerationError.exceededContextWindowSize` | 424 | Mode gagal wajib ditangani |
| `.guardrailViolation`, `.assetsUnavailable` | 425–426 | Mode gagal nyata lainnya |
| `init(model:tools:instructions:)` | 338 | Tool calling tersedia (tidak dipakai v1) |

### 3.4 Sinyal wellness yang Mac benar-benar punya

Diuji di mesin dev, semuanya mengembalikan nilai nyata:

| Sinyal | API | Contoh hasil |
|---|---|---|
| Idle sejak input terakhir | `CGEventSource.secondsSinceLastEventType` | `15.0 s` |
| Thermal state | `ProcessInfo.thermalState` | `0` nominal |
| Low power mode | `ProcessInfo.isLowPowerModeEnabled` | `false` |
| Sumber daya + baterai | `IOPSCopyPowerSourcesInfo` | `Battery Power, 65%` |
| Uptime | `ProcessInfo.systemUptime` | `4664 s` |

**Terverifikasi di build ber-sandbox** (Wave 0, Task 9, 2026-08-24). Probe dijalankan
dari dalam `DinoPocketMac.app` yang ber-entitlement `com.apple.security.app-sandbox`,
bukan CLI:

| Sinyal | Hasil di sandbox | Status |
|---|---|---|
| `CGEventSource.secondsSinceLastEventType` | `1227.41` | ✅ selamat |
| `ProcessInfo.thermalState` | `0` | ✅ selamat |
| `ProcessInfo.isLowPowerModeEnabled` | `false` | ✅ selamat |
| `ProcessInfo.systemUptime` | `7370.83` | ✅ selamat |
| `IOPSCopyPowerSourcesInfo` | `1 sumber · AC Power · 70%` | ✅ selamat |

**Kelima sinyal lolos sandbox tanpa entitlement tambahan.** Tidak ada yang perlu
dipetakan jadi `nil` karena diblokir — `IdleTimeProviding` dan `SystemStatusProviding`
di Wave 1 bisa mengandalkan semuanya.

Catatan pelaksanaan: `print` ke stdout **ter-buffer** saat diredirect ke file, sehingga
probe pertama tampak tidak menghasilkan apa-apa padahal berjalan. Probe diubah menulis
ke `FileHandle.standardError` yang tidak di-buffer. Relevan bila kelak ada diagnostik
serupa.

**Sengaja tidak dipakai:** `NSWorkspace.frontmostApplication` berfungsi, tetapi melacak app
yang sedang dipakai adalah pengawasan yang tidak dibutuhkan tujuan wellness. Ritme istirahat
sepenuhnya bisa disimpulkan dari idle time — tahu *kapan* user di meja tanpa tahu *apa* yang
dikerjakan. Manfaat penuh, nol biaya privasi, satu pertanyaan App Review yang tidak perlu dijawab.

### 3.5 Baseline build & test

`xcodebuild test -project Jarvis.xcodeproj -scheme Jarvis -destination 'platform=macOS,arch=arm64'`
→ **`Test run with 28 tests in 6 suites passed` · `** TEST SUCCEEDED **`** (2026-08-24).

Ini jaring pengaman gelombang 0, dan sudah dijalankan — bukan angka yang diwariskan dari
dokumen lama.

### 3.6 Entitlements memakai build setting, bukan file

`grep CODE_SIGN_ENTITLEMENTS project.pbxproj` → **0 hasil**. Project memakai entitlement
berbasis build setting gaya Xcode modern:

```
ENABLE_APP_SANDBOX = YES
ENABLE_HARDENED_RUNTIME = YES
ENABLE_OUTGOING_NETWORK_CONNECTIONS = NO      ← keputusan all-Apple sudah ditegakkan di sini
ENABLE_INCOMING_NETWORK_CONNECTIONS = NO
ENABLE_USER_SELECTED_FILES = readwrite
ENABLE_RESOURCE_ACCESS_* = NO                 (kamera, mikrofon, kontak, lokasi, dll.)
```

**Konsekuensi:** `Jarvis/DinoPocket.entitlements` dan `JarvisIOS.entitlements` adalah file
**yatim** — tidak direferensikan project, sehingga app group `group.com.Jarvis` dan iCloud
kvstore di dalamnya **tidak aktif**. Companion iPhone v1.1 yang mengandalkan sinkronisasi
iCloud harus mengaktifkannya secara eksplisit; jangan berasumsi sudah menyala.

`ENABLE_OUTGOING_NETWORK_CONNECTIONS = NO` berarti item DoD "tanpa `network.client`"
sudah terpenuhi di level build setting.

**Build settings yang harus direplikasi `project.yml`:**

| Setting | Nilai |
|---|---|
| `SWIFT_VERSION` | `5.0` (naik ke `6.0` di gelombang 2) |
| `MACOSX_DEPLOYMENT_TARGET` | `26.2` |
| `PRODUCT_BUNDLE_IDENTIFIER` | `com.Jarvis.Ega` (diganti, §14) |
| `DEVELOPMENT_TEAM` | `R93K2HFM78` |
| `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` | `1.0` / `1` |
| `GENERATE_INFOPLIST_FILE` | `YES` |
| `ASSETCATALOG_COMPILER_APPICON_NAME` | `AppIcon` |
| `SWIFT_APPROACHABLE_CONCURRENCY` | `YES` |
| `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY` | `YES` |
| `ENABLE_PREVIEWS` | `YES` |
| `CODE_SIGN_STYLE` | `Automatic` |

---

## 4. Arsitektur target

Mengikuti bentuk **Taggo** (`/Users/egaaaa/Documents/urbanan`), yang terbukti pada skala
setara (Taggo 5.748 baris, DinoPocket 5.735 baris).

```
DinoPocket/
├── project.yml                      # sumber kebenaran struktur target (XcodeGen)
├── SharedCore/                      # NOL SwiftUI, NOL AppKit/UIKit, NOL #if os()
│   ├── Data/
│   │   ├── Models/                  # ChatMessage, WellnessSnapshot, ReminderSchedule, ScreenTimeEntry
│   │   ├── Enums/                   # BrainKind, Persona, ReminderKind, WellnessMetric, SystemMood
│   │   └── Errors/                  # DinoPocketError
│   ├── Domain/UseCases/
│   └── Infrastructure/
│       ├── Persistence/             # WellnessStore, ChatSessionStore
│       └── Services/                # AppleBrain, OllamaBrain, ReminderIntentParser, NotificationScheduler
├── DinoPocketMac/
│   ├── App/                         # @main, AppDependencies.live
│   ├── Infrastructure/Services/     # BuddyWindowController, SystemStatusService,
│   │                                #   LaunchAtLoginService, AppLauncherService
│   ├── Presentation/
│   │   ├── Character/               # CharacterPresenting, USDZCharacterPresenter, CharacterAsset
│   │   ├── ViewModels/              # ChatStore ADA DI SINI, bukan di SharedCore
│   │   └── Views/
│   ├── Legacy/                      # karakter SpriteKit — excluded dari build
│   └── Resources/                   # Robot.usdz
├── DinoPocketTests/
└── docs/superpowers/
```

### `SharedCore` adalah folder, BUKAN framework target

Diverifikasi langsung di Taggo: target yang ada hanya `TaggoMain`, `TaggoClip`,
`TaggoTests`, `TaggoUITests` — **tidak ada target `SharedCore`** — dan
`grep "public " SharedCore/` mengembalikan **nol hasil**.

SharedCore adalah folder yang file-nya menjadi anggota target aplikasi lewat
`sources:`. Semua tipe tetap `internal`.

**Kenapa penting:** menjadikannya framework akan memaksa setiap tipe, init, dan member
yang dipakai lintas modul ditandai `public` — perubahan mekanis besar di 7 file, plus
friksi `@Observable` dan sintesis `Codable`. Tidak ada manfaat yang sepadan untuk dua
target di satu repo.

**Konsekuensi yang harus diterima:** batas modul **tidak ditegakkan compiler**. File di
`SharedCore/` yang mengimpor AppKit tetap akan ter-compile sebagai bagian target Mac.
Karena itu skrip verifikasi di bawah bukan pelengkap — **ia satu-satunya penegak batas**.

**Aturan penegak `SharedCore`** — bisa diuji, bukan sekadar niat:

1. Tidak boleh `import SwiftUI`, `import AppKit`, `import UIKit`
2. Tidak boleh mengandung satu pun `#if os(...)`
3. File yang butuh guard platform berarti salah kamar — dia milik target

Aturan 1 dan 2 diverifikasi lewat skrip grep di CI/pre-commit, bukan lewat disiplin manual.

**Kenapa XcodeGen, bukan bedah `project.pbxproj`:** sudah terpasang di mesin
(`/opt/homebrew/bin/xcodegen`). Struktur target jadi YAML yang bisa di-review; menambah
target iOS nanti = 3 baris, bukan diff pbxproj 3.000 baris.

---

## 5. Pemetaan 42 file Swift

Klasifikasi berdasarkan guard dan import yang benar-benar ada di tiap file.

### 5.1 → `SharedCore/` (7 file, pindah apa adanya)

| Tujuan | File |
|---|---|
| `Data/Models/`, `Data/Enums/` | `BrainTypes.swift` (dipecah: ChatMessage → Models; Persona, BrainKind → Enums) |
| `Infrastructure/Persistence/` | `PetStore.swift` → **rename `WellnessStore.swift`** |
| `Infrastructure/Services/` | `Brain.swift`, `AppleBrain.swift`, `OllamaBrain.swift`, `ReminderIntent.swift`, `WellnessNotificationCenter.swift` |

`AppleBrain.swift` ikut meski punya `#if canImport(FoundationModels)` — itu guard
ketersediaan framework, bukan percabangan platform. FoundationModels ada di macOS 26
*dan* iOS 26, jadi companion iPhone nanti memakai otak yang sama tanpa duplikasi.

### 5.2 → `DinoPocketMac/` (27 file, guard dihapus saat pindah)

`JarvisApp.swift` + `JarvisApp+macOS.swift` (digabung jadi satu entry point),
`JarvisBuddyWindowController.swift`, `ChatStore.swift`, dan 23 file
`Presentation/Views/*` — seluruhnya kecuali tiga file karakter 2D (§5.3) dan
empat file jalur iOS (§5.4).

Guard `#if os(macOS)` **dihapus** — keanggotaan target yang menggantikan perannya.

### 5.3 → `DinoPocketMac/Legacy/` (3 file, karantina, tidak di-build)

`WalkingJarvisScene.swift` (1.196), `JarvisScene.swift`, `RobotStyle.swift`. Lihat §9.

Efek samping menguntungkan: `typealias PlatformColor` hidup di dua file ini, jadi pola
`#if os(macOS) … NSColor #else … UIColor #endif` keluar sepenuhnya dari build. Target Mac
memakai `NSColor` langsung.

### 5.4 → dibekukan untuk spec iPhone (5 file)

`Haptics.swift`, `ContentView+iOS.swift`, `ContentView.swift`, `PetActivityWidgets.swift`,
`PetWidgetsBundle.swift`.

**Koreksi atas asumsi awal:** `ContentView.swift` bukan shell percabangan tipis. Ia
**934 baris view iOS bergaya retro** (`RetroCardView`, `RetroProgressBar`, `ScanlineOverlay`,
`SpeakerGrille`). Jalur macOS tidak pernah menyentuhnya — `JarvisApp.rootView` mengarah ke
`DashboardTemplate` untuk macOS dan ke `ContentView` hanya untuk iOS. Karena itu file ini
**dibekukan bersama jalur iOS**, bukan dilarutkan.

**Catatan:** `PetWidgetsBundle.swift` ada di `Presentation/Views/` sementara ada folder
target `JarvisWidget/` (kini ter-commit di `65fc0f8`). Duplikasi ini harus diselesaikan
di gelombang 0 — pilih satu sumber kebenaran.

### 5.5 Rekonsiliasi hitungan

`7 (SharedCore) + 27 (Mac) + 3 (Legacy) + 5 (dibekukan) = 42` ✓

Tidak ada file yang "larut". `JarvisApp.swift` dan `JarvisApp+macOS.swift` digabung jadi
satu entry point macOS, dihitung di §5.2.

### 5.6 Kode mati yang ditemukan saat verifikasi

`JarvisBuddyWindowController.startBuddyMode` memanggil `skView.presentScene(nil)` dan
**tidak pernah meng-assign `walkingScene`**. Ketujuh tombol demo (`Small`, `Minum`,
`Stretch`, `Makan`, `Reset ×3`) memanggil `walkingScene?.…` pada optional yang selalu `nil`
— **semuanya sudah no-op**. Hanya `Stop Buddy` yang berfungsi.

Konsekuensi: membuang tombol demo dan mengarantina karakter 2D nyaris tanpa risiko
perilaku. Referensi eksternal ke tiga file 2D hanya dua, keduanya ikut hilang:
`walkingScene` di controller, dan `JarvisScene` di `ContentView.swift:75` (file yang
dibekukan). `RobotStyle`, `PlatformColor`, dan `RobotChargeKind` punya **nol** referensi
eksternal.

---

## 6. Lapisan UseCase

Pola Taggo: **View → ViewModel → UseCase → Service**. Lapisan UseCase hari ini **tidak ada**
— 12 file view menyentuh `PetStore` langsung (`HomePage`, `WellnessCard`, `RemindersCard`,
`ScreenTimeCard`, `CharacterCard`, `DashboardTemplate`, `WalkingJarvisScene`, `JarvisScene`,
`RobotStyle`, `ContentView`, `ContentView+iOS`, `PetActivityWidgets`).

Bentuk UseCase mengikuti Taggo: `struct`, dependensi protokol via `init`, nested
`Input`/`Output`, satu `execute(_:) async throws`.

| UseCase | Dependensi | Menggantikan |
|---|---|---|
| `SendMessageUseCase` | `Brain`, `ChatSessionStoring` | `ChatStore` memanggil `Brain` langsung |
| `CreateReminderFromTextUseCase` | `ReminderParsing`, `WellnessStoring`, `NotificationScheduling` | `ReminderIntent` + penjadwalan tersebar |
| `LogWellnessEventUseCase` | `WellnessStoring` | 12 view menyentuh `PetStore` |
| `FetchWellnessSummaryUseCase` | `WellnessStoring`, `WellnessSourcing` | pembacaan `PetStore` di dashboard |
| `TrackFocusSessionUseCase` | `WellnessStoring`, `IdleTimeProviding` | `resumeScreenTime`/`pauseScreenTime` |
| `SummarizeDayUseCase` | `Brain`, `FetchWellnessSummaryUseCase` | *baru* — insight AI (v1.1) |

### Konvensi protokol

Taggo memakai akhiran `-ing` (`QRManaging`, `CloudKitManaging`). Diikuti:
`WellnessStoring`, `NotificationScheduling`, `ReminderParsing`, `WellnessSourcing`,
`ChatSessionStoring`, `IdleTimeProviding`, `SystemStatusProviding`, `LaunchAtLoginManaging`.

**Penyimpangan yang disengaja:** protokol `Brain` **tidak** diubah. `Brain` sudah merupakan
nama peran abstrak; akhiran `-ing` di Taggo dipakai untuk tipe `Manager`/`Service`.
Dicatat di sini agar terbaca sebagai keputusan, bukan kelalaian.

### Composition root

```swift
// DinoPocketMac/App/AppDependencies.swift
struct AppDependencies {
    let brain: Brain
    let wellnessStore: WellnessStoring
    let wellnessSource: WellnessSourcing
    let chatSessions: ChatSessionStoring
    let systemStatus: SystemStatusProviding
    let launchAtLogin: LaunchAtLoginManaging
    let buddySettings: BuddySettingsStore

    static let live = AppDependencies(
        brain: AppleBrain(),
        wellnessStore: WellnessStore(),
        wellnessSource: ManualWellnessSource(),
        chatSessions: ChatSessionStore(),
        systemStatus: SystemStatusService(),
        launchAtLogin: LaunchAtLoginService(),
        buddySettings: BuddySettingsStore()
    )

    #if DEBUG
    static let debug = AppDependencies(brain: OllamaBrain(), /* … */)
    #endif

    func makeChatViewModel() -> ChatStore { /* … */ }
}
```

---

## 7. Kontrak data wellness

Ini yang membuat companion iPhone v1.1 bisa dicolok tanpa menyentuh dashboard.

```swift
protocol WellnessSourcing: Sendable {
    var provenance: WellnessProvenance { get }        // .manual | .iPhoneHealth
    func snapshot(for day: Date) async throws -> WellnessSnapshot
}

struct WellnessSnapshot: Sendable, Codable, Equatable {
    let day: Date
    let deskTime: TimeInterval           // Mac tahu ini
    let water:     Measured<Int>?
    let stretch:   Measured<Int>?
    let meals:     Measured<Int>?
    let steps:     Measured<Int>?        // nil di v1
    let sleep:     Measured<TimeInterval>?   // nil di v1
    let heartRate: Measured<Double>?     // nil di v1
}

struct Measured<T: Sendable & Codable & Equatable>: Sendable, Codable, Equatable {
    let value: T
    let provenance: WellnessProvenance   // untuk label "manual" / "dari iPhone"
    let recordedAt: Date
}
```

### Aturan: metrik tak diketahui bernilai `nil`, bukan `0`

**Nol adalah klaim.** Kalau Mac tidak tahu jumlah langkah, menampilkan "0 langkah" adalah
kebohongan berbentuk angka — masalah kredibilitas sekaligus risiko App Review pada app
yang menyebut dirinya wellness.

Perilaku kartu:

| Metrik | v1 (Mac) | v1.1 (iPhone tersambung) |
|---|---|---|
| Desk Time | angka nyata | angka nyata |
| Air / stretch / makan | manual, berlabel "manual" | manual + tulis balik ke Health |
| Langkah / tidur / detak | **kartu "Connect iPhone"** | angka nyata, berlabel "dari iPhone" |

Kartu ber-`nil` tidak menampilkan `0` dan tidak disembunyikan — ia jadi ajakan.
Jujur hari ini, sekaligus jalur penemuan alami untuk companion v1.1.

Saat `CloudWellnessSource` tiba di v1.1, `steps` berhenti `nil` dan kartu yang sama
menyala **tanpa satu baris perubahan di dashboard**.

### `ScreenTimeCard` → `DeskTimeCard`

Kartu itu mengukur durasi sesi app-nya sendiri, bukan screen time sistem — dan §3.2
membuktikan screen time sistem mustahil di Mac. Menyebutnya "Screen Time" adalah janji
yang tidak bisa ditepati.

Definisi baru: **Desk Time** = waktu hadir di depan Mac, disimpulkan dari aktivitas input,
jeda otomatis setelah idle melewati ambang (`IdleTimeProviding`).

---

## 8. Lapisan AI

### Masalah pada kode sekarang

`AppleBrain.reply` (`AppleBrain.swift:46-47`) membuat **`LanguageModelSession` baru setiap
pesan**, lalu memipihkan seluruh riwayat jadi satu string via `buildPrompt`. Akibatnya:

1. `Transcript` milik model dibuang tiap giliran — struktur percakapan hilang
2. String riwayat tumbuh tanpa batas → menabrak `exceededContextWindowSize`, dan **tidak
   ada yang menangkapnya**; error diteruskan ke `continuation.finish(throwing:)`
3. Tidak ada `prewarm` — token pertama selalu lambat

"Connect terus" secara harfiah belum ada: tiap pesan adalah sesi baru yang pura-pura ingat.

### Pilar 1 — Reliability (v1)

`availability()` yang ada dipertahankan (pemetaannya benar, terbukti `.available`).
Yang ditambahkan: penanganan eksplisit tiap error generasi.

| Error | Perilaku |
|---|---|
| `exceededContextWindowSize` | Pangkas transcript (buang giliran tertua, **instructions selalu dipertahankan**), ulang sekali otomatis. User tidak melihat kegagalan |
| `guardrailViolation` | Pesan jelas bahwa permintaan diblokir. Bukan bubble kosong |
| `assetsUnavailable` | "Model sedang disiapkan" + tombol coba lagi |
| Stream putus | Tandai pesan + tombol ulangi |

Pemangkasan **reaktif, bukan prediktif** — tidak menebak sisa token, melainkan menangkap
error lalu memangkas dan mengulang. Satu-satunya cara yang dijamin benar tanpa API
penghitung token.

`prewarm()` dipanggil saat permukaan chat dibuka.

### Pilar 2 — Persistensi (v1)

Karena `Transcript` sudah `Codable`, ini komponen kecil:

```swift
protocol ChatSessionStoring: Sendable {
    func loadTranscript() throws -> Transcript?
    func save(_ transcript: Transcript) throws
}
```

Satu sesi hidup per percakapan, dimiliki `SendMessageUseCase`. Saat app ditutup,
`session.transcript` ditulis ke **Application Support** — bukan UserDefaults; transcript
tumbuh dan UserDefaults bukan tempatnya. Saat dibuka, `LanguageModelSession(transcript:)`
melanjutkan di titik terakhir.

### Pilar 3 — Proaktif (v1.1, bukan v1)

**Prinsip: aturan yang memutuskan kapan bicara, model yang menyusun kalimatnya.**

```
SystemStatus / DeskTime / jadwal / (v1.1) sinyal iPhone
        ↓
ProactiveTriggerEngine     ← fungsi murni, bisa dites, TIDAK memanggil AI
        ↓ ProactiveEvent
SummarizeDayUseCase → phrasing via Brain
        ↓
karakter bicara
```

Kalau model yang memutuskan kapan bicara, inferensi harus jalan terus-menerus: boros
baterai, tidak bisa dites, waktunya tak terduga. Dengan aturan sebagai pemutus, pemicunya
jadi fungsi murni ber-unit-test, dan AI hanya dipanggil saat ada yang perlu dikatakan.

Wajib ada: **kuota maksimum interupsi per jam** dan menghormati Focus mode.

### Yang sengaja TIDAK dilakukan

Tool calling tersedia (`tools:` di init) dan menggoda untuk menggantikan `ReminderIntent`.
**Tidak.** Parser tangan yang ada deterministik, punya 7 test, dan **tetap bekerja saat
Apple Intelligence mati** — sementara tool call mati bersama AI-nya. Tool calling masuk
sebagai lapisan tambahan nanti, bukan pengganti.

---

## 9. Karakter

### Keadaan sekarang: dua sistem paralel

- **SpriteKit 2D** — `WalkingJarvisScene` (1.196 baris) + `JarvisScene` + `RobotStyle`
- **RealityKit 3D** — `RobotCharacterView` (64 baris) memuat `Robot.usdz`

`JarvisBuddyWindowController` menyimpan keduanya (`walkingScene` dan `robotHostingView`).
Migrasi ke USDZ belum selesai.

`WalkingJarvisScene` sendiri mengerjakan enam pekerjaan: rig karakter, animasi, **HUD
statistik**, **UI reminder**, **suara (`AVSpeechSynthesizer`)**, dan penjadwal perilaku.
HUD dan UI reminder di dalam scene justru yang harus dihapus ("Buddy Mode bersih").

### Keputusan

**3D dibawa, 2D dikarantina.** File SpriteKit pindah ke `DinoPocketMac/Legacy/`, utuh dan
terbaca, tetapi tidak ikut kompilasi:

```yaml
targets:
  DinoPocketMac:
    sources:
      - path: DinoPocketMac
        excludes: ["Legacy/**"]
```

Bukan dikomentari: kode terkomentar tidak ikut compile sehingga diam-diam membusuk, hilang
dari syntax highlighting, dan mengotori pencarian. Git sudah menyimpan riwayatnya.

### Abstraksi — syarat "tinggal ditempel"

Aset 3D final akan disediakan user kemudian. Kode harus membuat penggantiannya jadi satu
edit struct.

```swift
protocol CharacterPresenting: AnyObject {
    func mount(in container: NSView)
    func play(_ behavior: CharacterBehavior)   // .idle .greet .remind(kind) .sleepy .celebrate
    func unmount()
}

struct CharacterAsset: Sendable {
    let resourceName: String
    let targetSize: Float
    let camera: (distance: Float, height: Float, fov: Float)
    let keyLightIntensity: Float
    let clips: [CharacterBehavior: String]
    let attribution: Attribution?              // nil = aset milik sendiri
}
```

`BuddyWindowController` bicara ke `CharacterPresenting`, tidak pernah ke RealityKit langsung.

**Resolusi klip berjenjang** agar model tanpa animasi lengkap tidak pecah:

```swift
clips[behavior] ?? clips[.idle] ?? availableAnimations.first
```

**Penggantian aset = satu struct literal:**

```swift
extension CharacterAsset {
    static let robot = CharacterAsset(resourceName: "Robot", …,
                                      attribution: .sketchfab(author: "l0wpoly"))
    static let mine  = CharacterAsset(resourceName: "<final>", …,
                                      attribution: nil)   // kredit hilang otomatis
}
```

`attribution: nil` membuat baris kredit di layar About lenyap sendiri — item compliance
menyelesaikan dirinya.

### Yang harus diperbaiki di `RobotCharacterView`

| Baris | Masalah | Perbaikan |
|---|---|---|
| `:15` | `Entity(named: "Robot", …)` hardcoded | dari `CharacterAsset.resourceName` |
| `:50` | `availableAnimations.first` — urutan tak terdefinisi | dari `clips[behavior]` |
| `:41-47` | Kamera/cahaya hardcoded | dari `CharacterAsset` |
| `:16-31` | 9× `print("[JARVIS-DIAG] …")` | dihapus atau `#if DEBUG` |
| `:15-17` | `guard … else { print; return }` → layar kosong | fallback avatar sederhana |

**Dipertahankan:** normalisasi otomatis di `:23-31` (`visualBounds` → skala ke target →
recenter) sudah benar. Model baru tidak perlu dibuat pada skala tertentu.

### Persyaratan aset 3D buatan sendiri

- Skala bebas — dinormalisasi otomatis
- Menghadap **+Z** (kamera berdiri di sisi +Z melihat ke titik nol)
- Animasi di-bake sebagai klip bernama, didaftarkan di `clips`
- Format `.usdz`; jumlah material bebas

### Lisensi `Robot.usdz` (sementara)

Metadata tertanam di file: `SKETCHFAB Standard (https://sketchfab.com/licenses)`,
author `l0wpoly (https://sketchfab.com/l0wpoly)`.

Standard License **mengizinkan** penyematan dalam produk komersial yang didistribusikan.
Yang dilarang: *"sell, license, distribute or otherwise make available the Licensed Material
as a stand-alone file"* — tidak berlaku di sini karena model tertanam dalam bundle `.app`.

Dua kewajiban:
1. **Jangan strip metadata** — lisensi mewajibkan mempertahankan informasi copyright di file
2. Kredit di About: **"3D character by l0wpoly (sketchfab.com/l0wpoly) — Sketchfab Standard License"**

Saat model diganti dengan buatan sendiri, kewajiban ini hilang. **Lisensi model pengganti
apa pun harus dicek ulang** — jangan diasumsikan sama.

---

## 10. Error handling

Prinsip: tidak ada kegagalan yang berujung angka palsu atau layar kosong tanpa penjelasan.

| Situasi | Perilaku |
|---|---|
| Apple Intelligence mati | Kartu penjelasan + tombol buka System Settings. **Sisa app jalan penuh** |
| Model sedang diunduh | "Model sedang disiapkan", input nonaktif, tombol coba lagi |
| Context window penuh | Pangkas transcript + ulang sekali. User tidak melihat apa pun |
| Guardrail menolak | Pesan jelas bahwa permintaan diblokir |
| Model 3D gagal dimuat | `CharacterPresenting` fallback ke avatar sederhana; buddy tetap bisa ditutup |
| Izin notifikasi ditolak | Reminder tetap tercatat in-app + ajakan mengaktifkan |
| Sinyal Mac tidak terbaca di sandbox | Metrik jadi `nil` → kartu "belum tersedia", bukan `0` |
| `SMAppService.register()` gagal | Toggle kembali + pesan singkat; tidak crash |

---

## 11. Testing

Mengikuti Taggo: *"Use Case layer fully tested"*.

- **Tiap UseCase punya test** dengan mock protokol. Ini yang baru — hari ini nol.
- **28 test yang ada tidak boleh regresi.** Mereka jaring pengaman gelombang 0.
- Fungsi murni diprioritaskan: parsing `ReminderIntent`, pemetaan `SystemMood`, clamping
  `BuddySettings`, pemangkasan transcript, resolusi klip karakter.
- `Transcript` round-trip: simpan → muat → sesi lanjut.
- **Tidak ada test yang memanggil Apple Intelligence sungguhan** — `Brain` di-mock.
- Skrip verifikasi batas `SharedCore` (nol `#if os`, nol import AppKit/UIKit) jalan di CI.

---

## 12. Tiga gelombang

Dipisah karena tiap gelombang punya **titik hijau yang bisa diverifikasi sendiri**. Kalau
dicampur lalu build pecah, penyebabnya tidak bisa dibisect antara pemindahan file, lapisan
baru, dan concurrency.

### Gelombang 0 — Struktural

`project.yml` + `xcodegen`; target `SharedCore` + `DinoPocketMac`; `git mv` 42 file
(riwayat per file terbawa); hapus guard platform; 2D → `Legacy/`; buang perancah demo;
selesaikan duplikasi `PetWidgetsBundle` vs `JarvisWidget/`; **verifikasi ulang sinyal Mac
di build ber-sandbox**.

`Jarvis.xcodeproj` lama **dibiarkan hidup** sampai target baru hijau, baru dihapus dalam
satu commit.

> **Hijau bila:** 28 test lulus · app build & jalan · `SharedCore` nol `#if os()` dan nol
> import AppKit/UIKit/SwiftUI · sinyal Mac terverifikasi di sandbox

### Gelombang 1 — Semantik

`Data/{Models,Enums,Errors}`; protokol `-ing`; lapisan UseCase; `AppDependencies`;
`CharacterPresenting` + `CharacterAsset`; `ChatSessionStore`; `DeskTimeCard`.

> **Hijau bila:** nol View menyentuh `WellnessStore` langsung · tiap UseCase punya test ·
> `BuddyWindowController` tidak mengimpor RealityKit

### Gelombang 2 — Swift 6

`SWIFT_VERSION` 5.0 → 6.0; `Sendable`; `@MainActor`.

`SWIFT_APPROACHABLE_CONCURRENCY = YES` sudah aktif — on-ramp resmi Apple, jadi migrasinya
kemungkinan lebih jinak dari yang ditakutkan.

> **Hijau bila:** build bersih tanpa warning concurrency · 28 test + test UseCase lulus

---

## 13. Definition of Done — App Store

Dikerjakan setelah tiga gelombang, bersama fitur v1.

- [ ] `PrivacyInfo.xcprivacy` — `NSPrivacyTracking = false`, `NSPrivacyCollectedDataTypes = []`, `NSPrivacyAccessedAPITypes` untuk UserDefaults (`CA92.1`)
- [ ] `INFOPLIST_KEY_LSApplicationCategoryType` — Health & Fitness atau Productivity *(terbuka, §16)*
- [ ] **Nol placeholder** — `HistoryPage` berisi data nyata; quick action Home benar-benar bekerja
- [ ] Atribusi aset 3D di About (§9), selama masih memakai `Robot.usdz`
- [ ] **Tanpa klaim medis** — audit seluruh copy wellness; posisikan sebagai kebiasaan sehat
- [ ] Ollama tidak di-wire di release; **tanpa** entitlement `network.client`
- [ ] Copy 100% English; nol string Indonesia
- [ ] App icon lengkap semua ukuran macOS
- [ ] Bundle identifier reverse-DNS milik developer, menggantikan `com.Jarvis.Ega`
- [ ] Sandbox + Hardened Runtime tetap ON
- [ ] Apple Developer Program · signing · App Store Connect record
- [ ] Privacy policy URL · screenshot · deskripsi · keyword · age rating
- [ ] TestFlight satu putaran, lalu submit

**Batasan yang diterima:** peluncuran aplikasi arbitrer tidak didukung di sandbox.
`AppLauncherService` hanya membuka System Settings pane, URL scheme, dan dokumen yang
dipilih user.

---

## 14. Rename terpusat

Nama produk final belum diputuskan. Semua titik yang harus berubah, terkumpul di sini:

| Titik | Nilai sekarang |
|---|---|
| Nama folder repo | `DinoPocket` |
| Repo GitHub | `megan0088/Jarvis` — rename di GitHub mempertahankan riwayat + redirect |
| `project.yml` nama target | `DinoPocketMac`, `SharedCore`, `DinoPocketTests` |
| Bundle identifier | `com.Jarvis.Ega` → reverse-DNS milik developer |
| Nama entry point | `JarvisApp.swift` |
| Entitlements | `Jarvis/DinoPocket.entitlements`, `JarvisIOS.entitlements` |
| App group + kvstore | `group.com.Jarvis`, `$(TeamIdentifierPrefix)com.Jarvis` |
| Persona `.jarvis` + system prompt | `BrainTypes.swift` |
| Nama tampilan App Store | belum ada |

Spec fase A mencatat "Jarvis" berisiko bentrok di App Store dan menyerempet merek pihak
ketiga. Keputusan nama harus diambil sebelum App Store Connect record dibuat.

---

## 15. Roadmap setelah v1

| Versi | Isi |
|---|---|
| **v1** | Mac app: buddy 3D bersih, chat andal + persisten, wellness manual + Desk Time, reminder, History nyata |
| **v1.1** | **Companion iPhone** (spec sendiri): baca HealthKit → sync iCloud → `CloudWellnessSource`; tulis balik air/stretch ke Health; insight AI (`SummarizeDayUseCase`); proaktif |
| **v1.2+** | Librarian (PDFKit + FM), transkripsi audio (SpeechAnalyzer), Writing Tools, MenuBarExtra, Widget/Live Activity, TipKit, kustomisasi karakter |

---

## 16. Risiko & pertanyaan terbuka

| Risiko | Mitigasi |
|---|---|
| Reviewer memakai Mac tanpa Apple Intelligence → mengira app rusak | Degradasi eksplisit + catatan di App Review Notes |
| Sinyal Mac terhalang sandbox | Diverifikasi di gelombang 0, bukan diasumsikan; metrik gagal jadi `nil`, bukan `0` |
| Migrasi Swift 6 memuntahkan ratusan error | Gelombang terpisah; `SWIFT_APPROACHABLE_CONCURRENCY` sudah aktif |
| Perilaku karakter 3D harus dibangun ulang dari nol (2D sudah kaya) | `CharacterPresenting` membatasi dampak; 2D tetap di `Legacy/` bila perlu dipanggil kembali |
| Aset 3D final belum ada | `CharacterAsset` membuat penggantian jadi satu struct literal |
| Buddy window mengganggu Mission Control/fullscreen | `collectionBehavior` yang ada dipertahankan; uji multi-display |
| Beban baterai render RealityKit | Buddy opt-in; hentikan animasi saat tersembunyi atau low-power mode |

**Pertanyaan terbuka:**

1. Nama produk final dan bundle identifier (§14)
2. Kategori App Store: Health & Fitness atau Productivity
3. Suara karakter (`AVSpeechSynthesizer` di `WalkingJarvisScene`) — dibawa ke versi 3D atau dibuang? Tidak ada di fase A
4. Persistensi chat: satu percakapan berkelanjutan, atau banyak sesi terpisah?

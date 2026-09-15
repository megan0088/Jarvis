# Apl — Fondasi & Kepatuhan (Sub-project A) — Design Spec

- Tanggal: 2026-09-15
- Status: Desain disetujui per bagian; menunggu review spec
- Basis kode: branch `refactor/taggo-architecture` @ `78fedb3` + 102 perubahan yang belum di-commit
- Target: **macOS 26+** (Apple Silicon), distribusi **Mac App Store**
- Keputusan program dan pemecahan A–D: `2026-09-15-apl-main-window-design.md` §2–§3.
  Dokumen ini merinci **A**; bila bertentangan dengan catatan "Masukan untuk spec A" di
  sana, dokumen ini yang berlaku.

---

## 1. Tujuan

Menyiapkan fondasi yang dipakai B: app tanpa akun, tanpa wellness, dengan reminder yang
jujur (sekali jalan dan harian, judul bebas), dan pemeriksaan rilis yang benar-benar
memeriksa keadaan hari ini. A **tidak** memoles UI — tampilan sementara diganti B.

### Temuan yang membentuk desain ini

| Temuan | Bukti |
|---|---|
| `WellnessStore` memegang reminder, Desk Time, target harian, snooze, riwayat notifikasi, **dan** statistik pet lama (`mood`, `hunger`, `energy`, `affection`, `lastFed`) | `WellnessStore.swift` (539 baris); 9 file produksi dan 5 file test bergantung padanya |
| Parser hanya mengenal air/stretch/meal: "remind me to call mom at 3pm" → `nil` → diteruskan ke AI, yang bisa menjawab seolah reminder sudah dibuat | `ReminderIntent.swift`, `ChatStore.send` |
| Semua notifikasi `repeats: true` | `WellnessNotificationCenter.schedule` |
| Baris yang menggagalkan build ada di sinkronisasi riwayat notifikasi — jalur yang ikut dihapus bersama History | `WellnessNotificationCenter.swift:109` |
| App group `group.com.ega.apl` hanya dipakai `WellnessStore` (dan widget iOS yang dibekukan) | `grep suiteName` |
| `KeychainStore` hanya dipakai `AccountStore` | `grep KeychainStore` |
| `Persona` masuk sampai protokol `Brain.reply(to:persona:)` dan logika sesi `AppleBrain` | `Brain.swift:8`, `AppleBrain.swift:109` |
| Mood Buddy berasal dari `SystemStatus`, bukan wellness | `AplBuddyWindowController.swift:117` |

---

## 2. Keputusan

| # | Keputusan | Alasan |
|---|---|---|
| 1 | Langkah pertama A: perbaiki build, lalu commit seluruh WIP apa adanya sebagai baseline | A butuh titik hijau yang ter-commit; tanpa itu perubahan A bercampur dengan WIP dan tidak bisa di-bisect |
| 2 | Kode wellness **dihapus**, bukan dikarantina; hash commit penghapusan dicatat | Kode itu terkait erat dengan `WellnessStore` yang dibongkar — begitu dikarantina ia langsung tidak terkompilasi. Git menyimpan riwayatnya |
| 3 | Reminder dari chat lewat **parser deterministik yang diperluas + penjaga niat**; bukan tool calling | Tetap bekerja saat Apple Intelligence mati, sepenuhnya dites, dan tidak pernah mengklaim reminder yang tidak dibuat. Ekstraksi terstruktur oleh model bisa ditambahkan kelak di atasnya |
| 4 | **Tanpa migrasi data.** Sebagai gantinya, pembersihan data lama sekali jalan | App belum pernah rilis; satu-satunya data lama ada di mesin pengembang. Pembersihan tetap wajib agar Erase All Data tidak meninggalkan data di disk |
| 5 | Reminder disimpan di `UserDefaults.standard`, bukan suite app group | Tidak ada widget di v1; app group tidak lagi punya pemakai |
| 6 | Satu set instructions tetap untuk Apl; `Persona` dihapus | Keputusan program #5 |
| 7 | **Apple Intelligence satu-satunya brain.** `OllamaBrain`, `BrainKind`, pemilihan brain, dan fallback antar-brain dihapus — **termasuk di build DEBUG**. Protokol `Brain` dipertahankan hanya sebagai titik mock untuk test | Diputuskan pemilik produk 2026-09-16. Jalur kedua yang tidak pernah dirilis hanya menambah kode, UI debug, dan test yang harus dirawat |

---

## 3. Urutan kerja

Tiap langkah adalah commit tersendiri. **Hijau** = build Debug · seluruh test yang tersisa
lulus · app terbuka dan chat bisa dipakai.

| # | Langkah | Isi | Hijau tambahan |
|---|---|---|---|
| **A0** | Baseline | Kembalikan `WellnessNotificationCenter.swift:109` ke bentuk HEAD (`ISO8601DateFormatter()` dibuat per panggilan — terbukti terkompilasi); jalankan test; commit seluruh WIP | — |
| **A1** | Hapus Sign in with Apple | §5 | Onboarding selesai tanpa login |
| **A2** | Pisahkan reminder | Pindahkan jadwal kustom dari `WellnessStore` ke `ReminderStore` **tanpa mengubah perilaku** (masih harian, parser lama) | Test reminder lama tetap lulus |
| **A3** | Hapus wellness | §6 | `grep WellnessStore` = 0 di kode build |
| **A4** | Reminder baru | §4 | Test parser & notifikasi lulus |
| **A5** | Rapikan untuk rilis | Hapus `Persona`; hapus `OllamaBrain`, `BrainKind`, `BrainSegmentedPicker`, dan pemilihan/fallback brain (§6); `LegacyDataCleanup`; `verify-release.sh` (§7) | `verify-release.sh` lulus |

A2 mendahului A3 karena reminder hari ini tinggal di `WellnessStore`: menghapus wellness
lebih dulu merusak reminder di tengah jalan.

**UI sementara setelah A** (diganti B): sidebar hanya **Apl AI** dan **Settings**; chat
menjadi halaman awal; Settings berisi Profile (nama panggilan), Assistant, Buddy, General,
dan **Erase All Data…**.

---

## 4. Domain reminder

### Model

Menggantikan `ReminderSchedule` dan `ReminderKind`.

```swift
struct Reminder: Codable, Equatable, Identifiable, Sendable {
    enum Rule: Codable, Equatable, Sendable {
        case once(Date)
        case daily(hour: Int, minute: Int)
    }

    let id: UUID
    var title: String
    var rule: Rule
    let createdAt: Date

    /// `.once` yang sudah lewat → nil. `.daily` → hari ini bila belum lewat, selain itu besok.
    func nextOccurrence(after now: Date, calendar: Calendar) -> Date?
}
```

### Penyimpanan

```swift
@MainActor
protocol ReminderStoring: AnyObject, LocallyErasable {
    var reminders: [Reminder] { get }
    func add(_ reminder: Reminder)
    func update(_ reminder: Reminder)
    func remove(id: Reminder.ID)
}
```

`ReminderStore` menulis JSON ke `UserDefaults.standard` dengan kunci `apl.reminders`.
Saat dimuat, reminder `.once` yang lewat lebih dari 24 jam dibuang.

### Parser

`ReminderParser.parse(_ text: String, now: Date, calendar: Calendar) -> ReminderParseResult` —
fungsi murni.

```swift
enum ReminderParseResult: Equatable {
    case reminder(title: String, rule: Reminder.Rule)
    case missingTime(title: String?)
    case notAReminder
}
```

**Pemicu:** frasa "remind me" atau "set a reminder" (batas kata). Tanpa pemicu → `.notAReminder`.

**Waktu yang dikenali:**

| Bentuk | Aturan |
|---|---|
| `at 3pm` · `at 3:30 pm` · `at 15:00` | `.once` hari ini; bila sudah lewat → besok |
| `today at …` | sama dengan di atas |
| `tomorrow at …` | `.once` besok |
| `in 20 minutes` · `in 2 hours` · `in an hour` · `in a minute` | `.once` sekarang + durasi |
| `every day at …` · `daily at …` | `.daily` |

Aturan jam dipertahankan dari `ReminderIntent`: angka tanpa am/pm dan tanpa titik dua bukan
waktu; `12am` = 00.00, `12pm` = 12.00; jam/menit di luar rentang diabaikan.

**Judul:** frasa setelah "to" atau "about", dengan bagian waktu dibuang, spasi dan tanda baca
di ujung dirapikan, huruf pertama dikapitalkan. Urutan bebas — "remind me at 3pm to stretch"
dan "remind me to stretch at 3pm" menghasilkan judul yang sama. Tanpa judul → "Reminder".

### Penjaga niat — di `ChatStore`, tanpa AI

| Hasil parser | Perilaku |
|---|---|
| `.reminder` | Buat reminder, balas dengan konfirmasi deterministik |
| `.missingTime(title)` | Balas *"What time should I remind you to ‹title›?"* (tanpa judul: *"What time should I remind you?"*), simpan draft **untuk satu giliran** |
| Draft tersimpan + pesan berikutnya berupa waktu saja ("5pm", "in 10 minutes", "tomorrow at 9") | Selesaikan draft menjadi reminder |
| Draft tersimpan + pesan berikutnya bukan waktu | Buang draft, proses pesan seperti biasa |
| `.notAReminder` | Teruskan ke AI |

Instructions Apl mendapat aturan: *model tidak dapat membuat, mengubah, atau membatalkan
reminder; bila diminta, arahkan pengguna menulis "Remind me to … at 3 PM".*

### Konfirmasi

Teks deterministik, bukan buatan model, dan selalu menyebut kapan:

| Rule | Contoh |
|---|---|
| `.once` hari ini | "Done — I'll remind you to call mom today at 3:00 PM." |
| `.once` besok | "Done — I'll remind you to send the report tomorrow at 9:00 AM." |
| `.once` dari durasi | "Done — I'll remind you to check the oven in 20 minutes (3:20 PM)." |
| `.daily` | "Done — I'll remind you to stretch every day at 9:00 AM." |

Jam yang sudah lewat hari ini otomatis menjadi "tomorrow" — pengguna melihatnya langsung.

### Notifikasi

`WellnessNotificationCenter` → `ReminderNotificationCenter`, di belakang protokol:

```swift
protocol NotificationScheduling: Sendable {
    func requestAuthorization() async -> Bool
    func sync(_ reminders: [Reminder], now: Date) async
    func cancelAll() async
}
```

- `sync` menghapus semua permintaan tertunda berawalan `apl.reminder.`, lalu menjadwalkan ulang
  - `.once` → `UNCalendarNotificationTrigger` dengan tahun/bulan/hari/jam/menit, `repeats: false`
  - `.daily` → jam/menit, `repeats: true`
- Identifier: `apl.reminder.<uuid>`
- Hanya **60** kemunculan terdekat yang dijadwalkan (macOS membatasi jumlah notifikasi tertunda)
- Pemetaan reminder → komponen trigger adalah fungsi murni yang dites
- Sinkronisasi riwayat notifikasi terkirim dihapus

### Use case

| Use case | Dipakai |
|---|---|
| `CreateReminderFromTextUseCase` → `.created(Reminder, confirmation)` · `.needsTime(prompt)` · `.none` | A (`ChatStore`) |
| `CancelReminderUseCase` | B (Up next, Undo) |
| `UpdateReminderUseCase` | B (edit di popover) |

Ketiganya menulis ke `ReminderStoring` lalu memanggil `NotificationScheduling.sync`.

---

## 5. Profil & Erase All Data

- `AccountStore` → **`ProfileStore`**: `nickname: String?` dan `hasCompletedOnboarding`. Kunci
  UserDefaults tetap `account.displayName` dan `onboarding.completed`.
- Dihapus: `userID`, `signIn(with:)`, `signOut()`, `refreshCredentialState()`,
  `debugBypassSignIn()`, `KeychainStore`, import `AuthenticationServices`.
- `DinoPocketMac/DinoPocketMac.entitlements` dihapus, beserta blok `configs: Release:
  CODE_SIGN_ENTITLEMENTS` dan komentar SIWA di `project.yml`. Sandbox dan Hardened Runtime
  tetap lewat build setting.
- `AplApp.rootView`: onboarding bila `!profile.hasCompletedOnboarding`, selain itu dashboard.
- Onboarding sementara: **nama panggilan** (opsional) → **notifikasi** → **Apple Intelligence** → Start.
- `DeleteAccountUseCase` → **`EraseAllDataUseCase`**: memusnahkan setiap `LocallyErasable`
  (`ProfileStore`, `ReminderStore`, `ChatStore`, `FileChatSessionStore`, dan
  `BuddySettingsStore` — yang di A dijadikan `LocallyErasable` agar preferensi karakter ikut
  kembali ke bawaan), memanggil `NotificationScheduling.cancelAll()`, lalu
  `LegacyDataCleanup.run(force: true)`. Setelahnya app kembali ke onboarding.

### `LegacyDataCleanup`

Berjalan sekali saat app dibuka (flag `apl.legacyCleanupDone`) dan setiap Erase All Data.

- Menghapus dari suite `group.com.ega.apl` seluruh kunci lama `WellnessStore`: `pet.mood`,
  `pet.hunger`, `pet.energy`, `pet.lastFed`, `pet.affection`, `wellness.screenTimeHistory`,
  `wellness.reminderHistory`, `wellness.reminderEventsSeen`, `wellness.remindersEnabled`,
  `wellness.goalProgress`, `wellness.snoozedReminders`, `pet.customSchedules`. Daftar ditulis
  literal di sini karena `WellnessStore` sudah tiada.
- Menghapus item Keychain `appleUserID` (service `com.ega.apl.account`) lewat `SecItemDelete`.
- Menghapus notifikasi tertunda dengan identifier lama (awalan `custom.` dan jadwal wellness bawaan).
- Pada jalan pertamanya saja: menghapus transcript percakapan tersimpan
  (`FileChatSessionStore`) dan `jarvis.chat.recent`, karena keduanya dibuat dengan
  instructions persona lama; serta kunci `jarvis.activeBrain`.
- Idempoten.

---

## 6. Yang dihapus di A3

| Lapisan | Berkas |
|---|---|
| View | `HomePage`, `WellnessCard`, `DeskTimeCard`, `RemindersCard`, `ReminderRow`, `HistoryPage`, `CharacterCard`, `DashCard`, `MetricRow`, `RingGauge`, `PillButton` — kecuali yang masih dirujuk UI sementara (diperiksa saat rencana) |
| ViewModel | `WellnessViewModel` |
| Use case | `FetchWellnessSummaryUseCase`, `TrackFocusSessionUseCase` |
| Persistence | `WellnessStore`, `WellnessStoring` |
| Model | `ReminderSchedule`, `ReminderKind`, `ReminderEvent`, model Desk Time/goal/snooze/pet terkait |
| Service | `ReminderIntent` (digantikan `ReminderParser` di A4), `IdleTimeService` + protokol `IdleTimeProviding` (satu-satunya pemakai adalah jalur wellness; C memulihkannya dari commit A3 untuk ajakan istirahat proaktif) |
| Test | `WellnessStoreTests`, `FetchWellnessSummaryTests`, dua suite wellness di `RemindersWiringTests` |

`SystemStatusService` dan `SystemMood` **tetap** — dipakai Buddy.

### Yang dihapus di A5 — brain tunggal

| Lapisan | Perubahan |
|---|---|
| Service | `OllamaBrain` dihapus. `Brain` kehilangan `kind` dan parameter `persona`: `reply(to history: [ChatMessage]) -> AsyncThrowingStream<String, Error>`. `AppleBrain` membuat sesi dengan instructions Apl yang tetap; logika "persona berubah → sesi lahir ulang" dihapus |
| Model | `BrainKind`, `Persona` dihapus |
| `ChatStore` | Menerima satu `Brain`, bukan `[BrainKind: Brain]`. `activeBrain`, `resolveBrain()`, dan fallback di `bestAvailability()` dihapus; availability dibaca langsung dari `AppleBrain` |
| View | `BrainSegmentedPicker` dihapus; bagian "Active brain" di sidebar, picker brain dan persona di Settings, dan picker persona di `ChatPage` dihapus |
| Komposisi | `AppDependencies.brains` menjadi `brain: Brain` |

Pesan commit A3 mencantumkan hash commit sebelumnya dan daftar berkas yang dihapus, agar
spec companion iPhone dapat memulihkannya lewat `git show <hash>:<path>`.

**Di luar scope:** berkas jalur iOS yang dibekukan (`ContentView*.swift`,
`PetActivityWidgets.swift`, `Haptics.swift`, `JarvisWidget/`) sudah dikecualikan dari build
dan tidak disentuh, meski masih merujuk tipe yang dihapus.

---

## 7. `verify-release.sh`

| Pemeriksaan | Perubahan |
|---|---|
| `CODE_SIGN_ENTITLEMENTS` berisi `DinoPocketMac.entitlements` | **Dibalik:** Release harus **kosong** |
| `com.apple.developer.applesignin` ada | **Dibalik:** tidak boleh ada berkas `*.entitlements` di `DinoPocketMac/` yang berisi `applesignin` |
| Aset wajib `Robot.usdz` | **Diganti:** setiap nama berkas yang dirujuk `CharacterAsset.swift` harus ada sebagai `.usdz` di `DinoPocketMac/Resources/`. Daftar dibaca dari kode, bukan disalin ke script |
| `PrivacyInfo.xcprivacy` ada | Tetap |
| — | **Baru:** tidak ada teks `Ollama` di `SharedCore/` dan `DinoPocketMac/` (di luar `Legacy/` dan berkas iOS yang dibekukan) — menjaga keputusan brain tunggal |
| Sandbox, Hardened Runtime, outgoing network NO, kategori, bundle id, nama produk, enkripsi, copyright | Tetap |
| Pesan provisioning | Tidak lagi menyebut capability Sign in with Apple |

---

## 8. Testing

Swift Testing; `Brain` dan `NotificationScheduling` di-mock; tidak ada test yang memanggil
Apple Intelligence sungguhan.

### Nasib test lama

| Test | Nasib |
|---|---|
| `WellnessStoreTests` (4), `FetchWellnessSummaryTests` (4) | Dihapus |
| `RemindersWiringTests` — suite "Pengingat terhubung ke dashboard" (7), "Prompt ringkasan" (2) | Dihapus |
| `RemindersWiringTests` — suite "Ketersediaan otak untuk layar chat": `chatIsUsableWhenAppleIsDownButAnotherBrainIsReady` | Dihapus (tidak ada brain lain) |
| `RemindersWiringTests` — suite yang sama: `chatReportsAppleReasonWhenNoBrainIsReady` | Dipindah ke `ChatStoreTests`, disesuaikan ke brain tunggal |
| `OllamaBrainTests` (6), `BrainTypesTests.brainKindHasBothBackends`, `AppleBrainTests.kindIsApple`, `ChatStoreTests.fallsBackWhenActiveBrainUnavailable` | Dihapus bersama `OllamaBrain` dan `BrainKind` |
| `DeleteAccountUseCaseTests` (5) | Menjadi `EraseAllDataUseCaseTests`; test sign-out dan app-group-suite diganti test `LegacyDataCleanup` |
| `ReminderIntentTests` (7) | Menjadi `ReminderParserTests` |
| `BrainTypesTests.personasHaveNonEmptyDistinctPrompts` | Dihapus bersama `Persona` |
| `ChatStoreTests.sendCreatesReminderWithoutCallingBrain` | Disesuaikan ke model baru |
| Sisa `AppleBrainTests` dan `ChatStoreTests`, `CharacterAssetTests`, `PhaseAComponentTests`, `TranscriptTrimmerTests` | Tetap hijau tanpa perubahan makna (mock brain disesuaikan ke protokol `Brain` yang baru) |

### Test baru

- **`ReminderParserTests`** (berbasis tabel): tiap baris tabel waktu §4; jam lewat → besok;
  `12am`/`12pm`; 24 jam; "an hour"/"a minute"; judul pada kedua urutan kata; tanpa judul →
  "Reminder"; `.missingTime` dengan dan tanpa judul; jam tidak valid (`at 25:00`) →
  `.missingTime`; "what should I eat at 3pm?" → `.notAReminder`
- **`Reminder.nextOccurrence`**: `.once` sebelum/sesudah; `.daily` sebelum/sesudah jamnya; lintas tengah malam
- **`ReminderStore`**: round-trip; `.once` > 24 jam lewat dibuang; erase
- **Pemetaan trigger notifikasi**: `.once` → komponen tanggal lengkap tanpa ulang; `.daily` → jam/menit berulang; batas 60 memilih yang terdekat
- **`ChatStore`**: reminder dibuat tanpa memanggil brain; `.missingTime` bertanya lalu selesai pada giliran berikutnya; draft kedaluwarsa bila giliran berikutnya bukan waktu; konfirmasi menyebut "tomorrow" saat jam sudah lewat
- **`EraseAllDataUseCase`**: tiap store terhapus tepat sekali; notifikasi dibatalkan; cleanup dipanggil
- **`LegacyDataCleanup`**: seluruh kunci lama hilang dari suite; aman dijalankan dua kali

---

## 9. Definition of Done — A

- [ ] A0–A5 masing-masing commit tersendiri dan hijau
- [ ] Build Debug dan Release (`CODE_SIGNING_ALLOWED=NO`) hijau; `scripts/verify-release.sh` lulus
- [ ] Seluruh test lulus; jumlah test dilaporkan
- [ ] Di kode yang di-build, `grep -E "ASAuthorization|applesignin|WellnessStore|ReminderKind|ReminderSchedule|Persona|Ollama|BrainKind"` = 0
- [ ] Diverifikasi di app sungguhan:
  - onboarding selesai tanpa login
  - "remind me to call mom in 1 minute" → notifikasi benar-benar muncul satu kali
  - "remind me to drink water" → Apl menanyakan waktu; "5pm" → reminder dibuat
  - "remind me every day at 9am to stretch" → konfirmasi "every day at 9:00 AM"
  - Erase All Data → kembali ke onboarding; tidak ada reminder maupun notifikasi tertunda

---

## 10. Risiko

| Risiko | Mitigasi |
|---|---|
| Parser tidak mengenali frasa yang wajar ("next Monday", "tonight"), lalu pesan jatuh ke AI | Penjaga niat: selama ada "remind me", pesan tidak pernah sampai ke AI — paling buruk Apl menanyakan waktu. Frasa baru ditambah sebagai baris tabel test |
| AI tetap mengklaim membuat reminder pada kalimat tanpa "remind me" ("don't let me forget…") | Aturan di instructions; frasa pemicu dapat diperluas berbasis test |
| Instructions yang berubah tidak berlaku untuk transcript tersimpan (`LanguageModelSession(transcript:)` membawa instructions lama) | Untuk A: `LegacyDataCleanup` menghapus transcript lama sekali. Untuk jangka panjang dicatat sebagai pekerjaan B/C: ganti entri instructions saat transcript dimuat |
| A3 menghapus berkas yang ternyata masih dipakai UI sementara | Daftar §6 dikonfirmasi ulang dengan `grep` saat rencana; hijau per langkah menangkapnya |
| WIP yang di-commit di A0 menyimpan masalah lain yang belum diketahui | A0 hanya hijau bila seluruh test lulus; kegagalan dilaporkan sebelum commit, bukan ditambal diam-diam |

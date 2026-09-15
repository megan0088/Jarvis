# Apl — Jendela Utama Chat-First (Sub-project B) — Design Spec

- Tanggal: 2026-09-15
- Status: Desain disetujui per bagian; menunggu review spec
- Basis kode: branch `refactor/taggo-architecture` @ `a529a42` + perubahan yang belum di-commit
- Target: **macOS 26+** (Apple Silicon), distribusi **Mac App Store**
- Melanjutkan: `2026-08-24-dinopocket-mac-real-design.md`. Bila bertentangan, dokumen ini
  yang berlaku — lihat §2.
- Mockup: kanvas **Apl Main Window**, artboard **A · Companion stage**
  (https://claude.ai/artifact/2PfwjYZNNBPDKkFjSQuoj7, privat)

---

## 1. Konteks

Visi produk ditegaskan ulang oleh pemilik produk: **chatbot desktop ala ROG OMNI dengan
karakter 3D buatan sendiri, UI yang rapi, dan lolos Mac App Store.**

App hari ini berbentuk *wellness tracker* dengan chat sebagai tambahan: Home berisi
tracking air/stretch/meals, Desk Time, dan History, sementara chat hanya muncul sebagai
sheet. Visi di atas membalik prioritas itu.

### Temuan saat app dijalankan (2026-09-15)

| Temuan | Lokasi | Ditangani di |
|---|---|---|
| Working tree gagal build: `nonisolated private static let iso8601Formatter` ditolak Swift 6 (`ISO8601DateFormatter` bukan `Sendable`) | `WellnessNotificationCenter.swift:109` | A |
| `verify-release.sh` masih mewajibkan `Robot.usdz`, padahal aset sudah diganti 5 berkas ekspresi | `scripts/verify-release.sh` | A |
| Picker "Active brain" di sidebar tidak dibungkus `#if DEBUG` (picker di Settings sudah) | `SidebarView.swift:42` | A (sidebar hilang di B) |
| Sheet Chat tidak punya cara menutup selain Esc | `DashboardTemplate.swift:48` | B |
| Label segmented "Apple Intelligence" terpotong di sidebar | `SidebarView.swift` | B (sidebar hilang) |
| `ReminderSchedule` hanya `hour`/`minute`: "remind me at 3 PM" diam-diam jadi reminder **harian** | `ReminderSchedule.swift` | A |
| Error stream ditulis sebagai teks `"⚠️ Connection lost."` di dalam pesan | `ChatStore.swift` | B |
| Konfirmasi reminder hanya teks; tidak ada cara melihat atau membatalkan reminder | `CreateReminderFromTextUseCase` | A (data) + B (UI) |

---

## 2. Keputusan program (mengikat)

| # | Keputusan | Alasan |
|---|---|---|
| 1 | **v1 = chatbot + karakter 3D + Buddy desktop.** Tracking manual air/stretch/meals, Desk Time, dan halaman History dihapus (kode ikut dihapus; riwayatnya di git — spec A §6) | Di luar visi; menambah permukaan untuk dipolish dan risiko review soal klaim kesehatan |
| 2 | **Sign in with Apple dihapus total.** Nama panggilan ditanya di onboarding; "hapus akun" menjadi **Erase All Data** | App on-device tanpa server; login wajib berisiko Guideline 5.1.1(v) |
| 3 | **Reminder dibuat lewat chat, sekali jalan + harian.** "at 3 PM" / "tomorrow at 9" = sekali; "every day at 9" = harian | Sesuai ekspektasi pengguna chatbot |
| 4 | **Perilaku ala OMNI di v1:** bubble chat dari Buddy, global shortcut, karakter bicara duluan (proaktif), suara (TTS) | Dipilih pemilik produk; semuanya sub-project C |
| 5 | **Satu persona (`Apl`).** Toggle "Standard / Apl" dihapus | Tidak ada kebutuhan dua persona |
| 6 | **Arah visual: native macOS 26 + aksen karakter** | Terasa rumah di Mac, murah dibangun di SwiftUI; kepribadian datang dari robot |
| 7 | **Layout: A · Companion stage** — satu percakapan berkelanjutan, robot selalu terlihat | Karakter tetap sentral tanpa mengorbankan ruang baca; cocok dengan transcript persisten yang sudah ada; tanpa manajemen sesi |
| 8 | **Reminder terdekat tampil sebagai "Up next" di stage** (maks. 3, "See all" → popover) | Selalu terlihat tanpa halaman tambahan |
| 9 | **Ekspresi: satu USDZ per ekspresi + cache** | Aset tetap apa adanya; kode `USDZCharacterView` yang sudah teruji dipertahankan |
| 10 | **Settings pindah ke jendela Settings standar (⌘,)** | Layout A tidak punya sidebar |
| 11 | Nama **Apl** tetap (diputuskan 2026-08-26) | Risiko Guideline 5.2.5 sudah tercatat di spec 2026-08-24 §14 |
| 12 | **Apple Intelligence satu-satunya brain** — Ollama dihapus, termasuk di build DEBUG (diputuskan 2026-09-16) | Rincian di spec A §2 #7 |

Keputusan ini **menggantikan** bagian spec 2026-08-24 berikut: roadmap v1 di §15 (wellness
manual, Desk Time, History nyata), butir §13 "HistoryPage berisi data nyata", dan alur
onboarding dengan Sign in with Apple wajib.

---

## 3. Pemecahan sub-project

Tiap sub-project punya siklus spec → rencana → implementasi sendiri dan titik hijau yang
bisa diverifikasi, meneruskan pola "gelombang" yang sudah dipakai.

| # | Sub-project | Isi | Hijau bila |
|---|---|---|---|
| **A** | Fondasi & kepatuhan | Perbaiki build; `verify-release.sh` untuk 5 USDZ; hapus SIWA; karantina UI wellness; ekstraksi reminder (lihat bawah) | Build Debug + Release hijau · seluruh test lulus · `verify-release.sh` lulus |
| **B** | Jendela utama chat-first | **Dokumen ini** | §11 |
| **C** | Kehadiran di desktop | Bubble chat dari Buddy, global shortcut, mesin proaktif (aturan + kuota + Focus), TTS | Spec sendiri |
| **D** | Rilis | Privacy policy URL, screenshot, deskripsi, keyword, age rating, TestFlight, submit | Spec sendiri |

**Urutan implementasi: A → B → C → D.** B dirancang lebih dulu karena keputusan desainnya
menentukan apa yang dihapus A.

### Spec A

Dirinci di `2026-09-15-apl-foundation-design.md`. Dua hal di sana menggantikan catatan
awal dokumen ini: kode wellness **dihapus** (bukan dikarantina), dan **tidak ada migrasi**
data reminder lama — app belum pernah rilis, jadi A membersihkan data lama alih-alih
memindahkannya. Tipe yang dipakai B dari A: `Reminder` (`.once` / `.daily`),
`ReminderStoring`, `CancelReminderUseCase`, `UpdateReminderUseCase`, `ProfileStore`,
`EraseAllDataUseCase`.

---

## 4. Scope B

**Masuk**

- Jendela utama layout A (§5)
- Onboarding baru tanpa akun (§8)
- Jendela Settings (§8)
- Menu bar **Conversation → Clear Conversation…** dengan konfirmasi — satu percakapan
  berkelanjutan butuh jalan untuk mulai dari awal. Reminder tidak ikut terhapus.
- Design system (§7)
- `CharacterExpressionCache` + `CharacterMoodResolver` (§6)

**Tidak masuk**

- Pekerjaan A (§3). B dibangun **di atas** A yang sudah hijau.
- Semua pekerjaan C. B **tidak** membuat placeholder untuknya: tombol speaker di header
  (terlihat di mockup) dan tab Voice/Shortcut di Settings baru ditambahkan oleh C.
- Tampilan Buddy Mode di desktop tidak berubah di B, selain memakai cache ekspresi yang sama.

---

## 5. Layout jendela utama

Rujukan visual: artboard **A · Companion stage**. Mockup digambar dalam dark; light
diturunkan dari token §7.

| Elemen | Nilai |
|---|---|
| Ukuran awal / minimum jendela | 1000×680 / 720×520 |
| Stage | Panel 320pt, inset 8pt dari tepi kiri/atas/bawah, radius 12 |
| Ambang compact | Lebar jendela < 820pt → stage diganti `CompactStageHeader` (avatar 36pt + nama + status) di atas percakapan |
| Header percakapan | Tinggi 52pt, label tanggal ("Today") |
| Kolom pesan | Padding horizontal 24pt; bubble pengguna maks. 420pt; teks asisten maks. 460pt |
| Composer | Capsule tinggi 40pt, tombol kirim bulat 28pt berwarna aksen |

**Stage, dari atas ke bawah:** robot 3D (area ±280×204pt) dengan glow aksen di belakangnya
dan bayangan lembut di bawah → nama "Apl" (rounded, 24pt semibold) → `StatusLine` (titik
status + teks) → `UpNextList` → `StageActions` (tombol **Buddy Mode** + tombol Settings).

**Teks status per ekspresi:** idle "Here when you need me" · greet "Good morning!" sebelum
12.00, "Good afternoon!" sebelum 18.00, selain itu "Good evening!" · thinking "Thinking…" ·
celebrate "Reminder set for 3:00 PM" · sleepy "Apple Intelligence is off".

**Up next:** maksimal tiga kemunculan terdekat, masing-masing judul + waktu relatif ("Today,
3:00 PM", "Tomorrow, 9:00 AM", "Every day, 9:00 AM"). "See all" membuka popover berisi
semua reminder; di sana reminder bisa dibatalkan atau diedit — judul, waktu, dan
sekali/harian.

**Percakapan:** pesan pengguna sebagai bubble berwarna `userBubble`; pesan asisten sebagai
teks tanpa bubble (meneruskan tampilan `MessageBubble` hari ini, yang latar asistennya
menyatu dengan jendela), dirender Markdown.

---

## 6. Komponen & alur state

```
MainWindow ─┬─ CharacterStage            (atau CompactStageHeader < 820pt)
            │   ├─ USDZCharacterView      ← ekspresi dari CharacterMoodResolver
            │   ├─ StatusLine
            │   ├─ UpNextList ──▶ RemindersPopover  (See all · batal · edit)
            │   └─ StageActions           (Buddy Mode · Settings)
            └─ ConversationView
                ├─ MessageList            (auto-scroll ke pesan terbaru)
                │   ├─ UserBubble
                │   ├─ AssistantMessage   (Markdown: tebal, kode inline, list, blok kode)
                │   ├─ ReminderChip       (Undo)
                │   └─ FailedMessage      (Retry)
                ├─ TypingIndicator
                └─ Composer  |  AIUnavailableBanner
```

`MainWindow` menggantikan `DashboardTemplate`, `HomePage`, `SidebarView`, dan sheet chat.

### State

- **`ChatStore`** tetap sumber pesan dan `isStreaming`. Tambahan:
  - `ChatMessage.attachment: Attachment?` dengan kasus `.reminder(id)` — chip dirender dari
    data, bukan dengan menebak teks. Pesan tersimpan tanpa kunci ini tetap ter-decode.
  - `lastEvent: (kind: .reminderCreated | .failed, at: Date)?`
  - Kegagalan stream menandai pesan `status: .failed`, bukan menyisipkan teks peringatan.
  - `persona`, `BrainKind`, dan pemilihan brain sudah dihapus di A; `ChatStore` memegang
    satu `Brain` (Apple Intelligence).
- **`ReminderListViewModel`** (baru): reminder terurut menurut kemunculan terdekat, `cancel`,
  `undo`; membaca repository reminder dari A dan menjadwalkan ulang notifikasi.
- **`CharacterMoodResolver`** — fungsi murni `(availability, isStreaming, lastEvent,
  windowActivatedAt, now) → CharacterBehavior`, dievaluasi berurutan:
  1. Apple Intelligence tidak tersedia → `.sleepy`
  2. `lastEvent == .failed` ≤ 3 dtk → `.sleepy`
  3. `isStreaming` → `.thinking`
  4. `lastEvent == .reminderCreated` ≤ 3 dtk → `.celebrate`
  5. Jendela dibuka/aktif ≤ 3 dtk → `.greet`
  6. Selain itu → `.idle`

  Pemanggil menjadwalkan evaluasi ulang tepat saat jendela 3 detik berakhir; resolver
  sendiri tidak menyimpan timer.
- **`CharacterExpressionCache`** (`@MainActor`): memuat kelima USDZ sekali saat pertama
  dibutuhkan, lalu menyerahkan `clone(recursive: true)`. `USDZCharacterView.show(_:)`
  mengambil dari cache alih-alih `Entity(named:)`; normalisasi skala dan `stage` yang
  bertahan tetap seperti sekarang. Pergantian ekspresi mendapat "pop" skala singkat
  (dilewati saat Reduce Motion). Buddy memakai cache yang sama.

### Alur contoh — "Remind me to stretch at 3 PM"

1. `ChatStore.send` → `CreateReminderFromTextUseCase` membuat reminder `once`
2. Pesan konfirmasi ditambahkan dengan `attachment: .reminder(id)`; `lastEvent = .reminderCreated`
3. Resolver → `.celebrate` selama 3 detik, lalu `.idle`
4. `UpNextList` memperbarui diri dari repository
5. **Undo** → reminder dihapus, notifikasi dijadwalkan ulang, chip berganti "Reminder removed"

---

## 7. Design system

### Warna

Warna semantik sistem dipakai di mana pun bisa (latar jendela, label, separator, kontrol).
Token custom hanya:

| Token | Dark | Light |
|---|---|---|
| `AccentColor` (asset catalog) | `#5EC4D6` — kontras 8,2:1 pada `#1E1E1E` | `#127A8A` — kontras 5,0:1 pada putih |
| `userBubble` | aksen 16% | aksen 12% |
| `stageGlow` | aksen 20% | aksen 12% |
| Status | `systemGreen` / `systemOrange` | sama |

Aksen dipasang lewat `AccentColor` sehingga toggle, focus ring, dan tombol sistem ikut teal
tanpa kode tambahan. Token wellness (`water`, `stretch`, `meal`) dihapus.

Asal aksen: diambil dari robot (telinga `#4A718E`, glow dada `#76FFFF`), lalu disesuaikan
agar kontrasnya lolos di kedua mode.

### Tipografi & bentuk

- Teks: text style sistem (SF Pro; body 13pt)
- Judul: `.system(..., design: .rounded).weight(.semibold)`
- Kode: `.monospaced`
- Spacing: skala `Spacing` yang ada (4/8/12/16/24)
- Radius: 7 (tombol ikon) · 8 (kontrol) · 12 (bubble, card, stage) · capsule (composer)

### Komponen reusable

`IconButton`, `StageButton`, `ReminderChip`, `Composer`, `AIUnavailableBanner` (pengganti
`AIUnavailableCard`), `StatusDot` (sudah ada). Tiap komponen punya `#Preview` untuk state
utamanya, dalam light dan dark.

### Aksesibilitas & keyboard

- Robot punya label VoiceOver yang mengikuti ekspresi ("Apl, thinking")
- Return kirim · ⇧Return baris baru · Esc menghentikan jawaban yang sedang ditulis
- Reduce Motion mematikan gerak bob dan pop
- Seluruh copy UI dalam bahasa Inggris

---

## 8. Onboarding & Settings

### Onboarding — satu jendela, 3 langkah, tanpa akun

1. **Welcome** — robot `.greet`, "Hi, I'm Apl.", kolom *What should I call you?* (opsional)
2. **Reminders** — penjelasan singkat, **Allow notifications** / **Not now**
3. **Apple Intelligence** — ✓ Ready, atau **Open System Settings** bila belum aktif.
   **Start** selalu aktif: reminder dan karakter tetap berguna tanpa AI.

Selesai = flag `hasCompletedOnboarding`; tidak ada keychain maupun kredensial.

### Settings (⌘,) — `TabView`

| Tab | Isi |
|---|---|
| General | Nama panggilan · Launch at login |
| Character | Ukuran · opacity · keep on top · wander (`BuddySettings` yang sudah ada) |
| Privacy | **Erase All Data…** — konfirmasi menyebut apa yang dihapus (percakapan, reminder, preferensi), lalu kembali ke onboarding |

Build `DEBUG` menambah tab **Debug** berisi satu kontrol: paksa status availability Apple
Intelligence (Ready · Not enabled · Device not eligible · Model downloading) untuk menguji
state AI mati. Tab ini tidak dikompilasi di Release.

Kredit aset di About panel standar; kosong karena `CharacterAsset.attribution == nil`.

---

## 9. Error handling

| Situasi | Perilaku |
|---|---|
| Apple Intelligence mati / perangkat tidak mendukung | `AIUnavailableBanner` menggantikan composer; robot `.sleepy`; Up next dan reminder tetap bekerja; availability dicek ulang setiap jendela aktif |
| Model sedang diunduh | Composer nonaktif dengan "Getting ready…", aktif sendiri saat tersedia |
| Stream gagal | `FailedMessage` + **Retry**; `lastEvent = .failed` |
| Guardrail menolak | Balasan netral "I can't help with that one." — bukan gaya error |
| Context window penuh | Ditangani lapisan AI (spec 2026-08-24 §8); B hanya merender hasilnya |
| Model 3D gagal dimuat | Stage tetap menampilkan nama, status, dan Up next tanpa robot; tidak crash |
| Izin notifikasi ditolak | Reminder tetap tercatat; Up next menampilkan "Notifications are off" + tautan System Settings |
| Markdown belum lengkap saat streaming (mis. blok kode belum ditutup) | Dirender toleran: sisa teks tampil apa adanya sampai blok ditutup |

---

## 10. Testing

Swift Testing; `Brain` di-mock; **tidak ada test yang memanggil Apple Intelligence sungguhan.**

- `CharacterMoodResolver` — setiap cabang prioritas dan batas 3 detik, dengan `now` di-inject
- `ReminderListViewModel` — urutan kemunculan terdekat, `once` yang lewat tidak tampil, cancel, undo
- `ChatMessage` — round-trip `attachment`; data lama tanpa `attachment` tetap ter-decode
- Helper Markdown — pemisahan blok kode/teks, termasuk blok yang belum ditutup
- Fungsi ambang layout compact
- Seluruh test yang ada dan `scripts/verify-boundaries.sh` tetap hijau

**Verifikasi manual** (app sungguhan, bukan preview): screenshot light dan dark pada 1000×680
dan 740×520; satu putaran VoiceOver; Reduce Motion aktif; state AI mati lewat override
khusus `DEBUG`.

---

## 11. Definition of Done — B

- [ ] Jendela utama sesuai artboard A dalam dark, dan light mengikuti token §7
- [ ] `DashboardTemplate`, `HomePage`, `SidebarView`, dan sheet chat tidak lagi ada di build
- [ ] Ekspresi robot mengikuti `CharacterMoodResolver`; pergantian tanpa kedip dan tanpa jeda muat
- [ ] Up next menampilkan, membatalkan, dan meng-undo reminder dari chat
- [ ] Onboarding 3 langkah tanpa akun; Settings (⌘,) dengan tiga tab
- [ ] Clear Conversation dan Erase All Data dengan konfirmasi
- [ ] Nol teks peringatan di dalam isi pesan; kegagalan tampil sebagai `FailedMessage`
- [ ] Setiap komponen baru punya `#Preview`
- [ ] Test §10 lulus; test lama tidak regresi
- [ ] Verifikasi manual §10 selesai dengan screenshot

---

## 12. Risiko

| Risiko | Mitigasi |
|---|---|
| Memori 5 model di cache | Ukur di Instruments. Mesh dan tekstur badan identik antar berkas; bila berat, beralih ke tukar tekstur wajah saja tanpa mengubah `CharacterAsset` |
| Render RealityKit terus-menerus di stage menguras baterai | Hentikan animasi saat jendela tidak terlihat atau di-minimize, dan saat Low Power Mode |
| Pergantian ekspresi terlalu sering saat streaming pendek | Resolver berbasis prioritas + jendela 3 detik; evaluasi ulang hanya pada perubahan input |
| Light mode belum pernah digambar | Diverifikasi lewat screenshot manual §10; kanvas diperbarui bila hasilnya meleset |
| Nama "Apl" dekat dengan "Apple" (Guideline 5.2.5) | Keputusan sadar pemilik produk; dicatat ulang untuk App Review Notes di D |

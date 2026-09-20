# Apl — Apl yang Memulai Bicara (Sub-project C2) — Design Spec

- Tanggal: 2026-09-20
- Status: Disetujui
- Basis kode: branch `refactor/taggo-architecture` @ `f39fab6` (working tree bersih)
- Target: **macOS 26+** (Apple Silicon), distribusi **Mac App Store**
- Melanjutkan: `2026-09-19-apl-quick-ask-design.md` (C1). Bila bertentangan, dokumen ini
  yang berlaku untuk hal-hal di §2.

---

## 1. Konteks

C1 memberi Apl jalan masuk dari mana saja: satu tombol, satu bubble di samping robot, satu
percakapan. Tapi Apl masih menunggu — ia tidak pernah bicara lebih dulu.

C2 memberinya hak itu, dan hak itu harus dibatasi sebelum diberikan. App ini pernah
berbentuk wellness tracker yang mengingatkan minum dan stretch; sub-project A membuang
seluruh kerangka itu. Yang membuat pengingat-pengingat itu buruk bukan idenya, melainkan
tidak adanya aturan: ia bicara karena timer, bukan karena ada yang perlu dikatakan.

Karena itu C2 sempit dengan sengaja. Dua pemicu, keduanya berakar pada data yang **sudah
ada**; tidak ada satu pun jenis data perilaku baru yang dilacak.

### Yang sudah ada dan dipakai apa adanya

`ReminderStore.reminders` dan `Reminder.nextOccurrence(after:)` (sub-project A),
`SystemStatusProviding.currentMood()` → `SystemMood` (fase A), `BubblePlacement` dan
`AplBuddyWindowController.characterScreenFrame` / `pauseStrolling()` (C1), `ChatStore` (B).

---

## 2. Keputusan yang mengikat

1. **Apl bicara lewat balon di robot**, bukan lewat notifikasi sistem. Notifikasi tetap
   milik reminder, dan perannya berbeda (lihat #4).
2. **Tidak ada izin sistem baru dan tidak ada entitlement baru.** Status Focus TIDAK
   dibaca — `INFocusStatusCenter` ada sejak macOS 12, tetapi menuntut capability Focus
   Status dan satu dialog izin lagi. Konsekuensinya diterima: Apl bisa menyapa saat
   pengguna sedang dalam sesi Focus.
3. **Dua pemicu saja**: reminder yang sebentar lagi berbunyi, dan keadaan mesin (panas
   atau baterai menipis). Tidak ada sapaan harian, dan **tidak ada pelacakan durasi
   kerja** — yang terakhir itu justru wellness tracking yang dibuang di A.
4. **Balon mendahului, notifikasi menandai waktunya.** Balon muncul 5 menit sebelum
   reminder; notifikasinya tetap berbunyi tepat waktu dan tidak pernah dibatalkan.
5. **Suara hanya untuk balon proaktif, mati secara bawaan.** Jawaban atas pertanyaan
   pengguna tidak pernah dibacakan.
6. **Balon tidak bisa menerima fokus keyboard** — sifat panelnya, bukan bendera yang bisa
   salah disetel.
7. **Sapaan masuk percakapan hanya bila diklik.** Balon yang diabaikan tidak meninggalkan
   jejak di riwayat.

---

## 3. Arsitektur

Tujuh unit; hanya dua yang menyentuh AppKit.

| Unit | Tanggung jawab | Bergantung pada |
|---|---|---|
| `Nudge` | Apa yang hendak dikatakan: jenis, teks, kunci kuota | — |
| `NudgeRules` | **Fungsi murni**: (waktu, reminder, mood, riwayat, sinyal) → `Nudge?` | — |
| `NudgeHistory` | Apa yang sudah dikatakan dan kapan; satu kunci `UserDefaults` | `UserDefaults` |
| `QuietSignals` | Nilai yang menjawab "boleh bicara sekarang?" | pembacanya disuntikkan |
| `NudgePanelController` | Panel pasif yang tidak bisa jadi key | `BubblePlacement`, buddy |
| `NudgeSpeaker` | `AVSpeechSynthesizer`, mati secara bawaan | — |
| `NudgeScheduler` | Detak: kumpulkan sinyal → tanya aturan → tampilkan, catat, bacakan | semuanya di atas |

### Antarmuka

```swift
struct Nudge: Equatable {
    enum Kind: Equatable {
        case reminderSoon(Reminder.ID, at: Date)
        case machine(SystemMood)
    }
    let kind: Kind
    let text: String
    /// Kunci kuota: satu kejadian hanya boleh disapa sekali.
    var key: String { get }
}

struct QuietSignals: Equatable {
    var otherAppIsFullScreen = false
    var screenIsAsleepOrLocked = false
    var aplIsFrontmost = false
    var quickAskIsOpen = false
    var buddyIsRunning = true
    var aNudgeIsOnScreen = false

    var allowsSpeaking: Bool { get }
}

enum NudgeRules {
    static func next(now: Date,
                     reminders: [Reminder],
                     mood: SystemMood,
                     moodSince: Date?,
                     history: NudgeHistory.Snapshot,
                     signals: QuietSignals) -> Nudge?
}
```

### Aliran

`NudgeScheduler` berdetak → membaca `ReminderStore`, `SystemStatusProviding`,
`QuietSignals`, `NudgeHistory` → `NudgeRules.next(...)` → bila ada isinya: **catat ke
riwayat lebih dulu**, lalu tampilkan panel, lalu bacakan bila suara menyala.

Urutan itu disengaja: kalau app berhenti di tengah, kuota sudah terpakai. Lebih baik satu
sapaan hilang daripada sapaan yang sama muncul lagi setiap kali app dibuka.

---

## 4. Aturan

**Pemicu 1 — reminder sebentar lagi.** Kemunculan berikutnya berjarak **≤ 5 menit** dan
belum lewat. Sekali per kemunculan, dikunci pasangan (id reminder, waktu kemunculan):
reminder harian tidak pernah mengulang untuk hari yang sama, dan reminder yang dibuat 2
menit sebelum waktunya memang tidak pernah dapat balon. Tidak terkena kuota harian —
pengguna sendiri yang memintanya dengan membuat reminder itu.

**Pemicu 2 — keadaan mesin.** `SystemMood` `.hot` atau `.lowBattery` yang bertahan
**minimal 10 menit**, bukan lonjakan sesaat. Paling banyak **sekali per 4 jam** dan **dua
kali sehari**.

**Satu balon pada satu waktu.** Balon yang sedang tampil tidak pernah ditimpa; yang
berikutnya menunggu detak berikutnya.

**Peredam**, semuanya terbaca tanpa izin baru:

| Sinyal | Cara membacanya |
|---|---|
| App lain sedang layar penuh | `CGWindowList`: jendela terdepan menutupi seluruh `frame` layar |
| Layar tidur atau terkunci | `NSWorkspace.screensDidSleep`/`screensDidWake`, `CGSessionCopyCurrentDictionary` |
| Apl sendiri di depan | `NSApp.isActive` |
| Bubble quick ask terbuka | `QuickAskPanelController.shared.isOpen` |
| Buddy Mode mati | Tidak ada robot, tidak ada jangkar |
| Balon terakhir diabaikan | Balon mesin mundur 1 jam |

**Low Power Mode dan Mac panas BUKAN peredam.** Keduanya sempat masuk daftar, lalu
dikeluarkan: justru keadaan itulah isi pemicu 2, jadi membungkam di situ berarti pemicu 2
tidak akan pernah menyala. Kekhawatiran sebenarnya adalah beban baterai, dan itu urusan
detak: **di Low Power Mode detak melambat dari 1 menit jadi 5 menit.**

---

## 5. Balon

**Bentuk.** Kapsul `.regularMaterial` selebar isinya, maksimal 300pt, ditambatkan lewat
`BubblePlacement` yang digeneralisasi menerima ukuran. Satu baris: reminder menampilkan
judul dan jamnya ("Stretch · 3:00 PM"), mesin menampilkan satu kalimat pendek. Tanpa
tombol.

**Umur.** Hilang sendiri setelah **8 detik**, atau setelah suaranya selesai bila lebih
lama. Kursor di atasnya menahannya. Robot berhenti melangkah selama balon tampil.

**Klik** membuka bubble quick ask, dengan sapaan itu dimasukkan ke `ChatStore` sebagai
giliran asisten pada saat itu juga, composer siap dijawab.

**Kalimatnya pasti, bukan acak** (`NudgeText`). Sapaan acak sudah dihapus di C1 justru
karena tidak punya aturan; menggantinya dengan acak yang lain berarti mengulang kesalahan
yang sama.

**Suara.** `AVSpeechSynthesizer` dengan suara sistem, mati secara bawaan, satu toggle di
tab Character ("Speak when Apl greets you"). Berhenti seketika saat balon hilang atau
diklik. Tidak pernah ada dua kalimat berbunyi bersamaan.

**Aksesibilitas.** Balon tidak bisa menerima fokus, jadi VoiceOver tidak menemukannya
sendiri: kemunculannya diumumkan lewat `NSAccessibility.post(.announcementRequested)`
berprioritas **rendah** — dikabarkan tanpa memotong yang sedang dibacakan. Reduce Motion
menghilangkan animasi.

---

## 6. Privasi dan penyimpanan

C2 menambah dua preferensi (`nudge.speaks`) dan satu catatan kuota (`nudge.history`).
Keduanya lokal, ikut terhapus oleh Erase All Data, dan ditulis dengan `synchronize()`
seperti store lain.

Tidak ada data perilaku baru: tidak ada durasi kerja, tidak ada app yang dicatat, tidak
ada riwayat kehadiran. Sinyal peredam dibaca saat ditanya dan langsung dibuang.

---

## 7. Pengujian

### Unit

- **`NudgeRules`** — hampir seluruh C2 ada di sini: jendela 5 menit; sekali per kemunculan;
  reminder harian tidak mengulang; mood harus bertahan 10 menit; kuota 1 per 4 jam dan 2
  per hari; reminder tidak terkena kuota; tiap sinyal peredam membungkam sendiri-sendiri;
  mundur 1 jam setelah diabaikan; tidak ada keadaan yang menghasilkan dua balon.
- **`NudgeHistory`** — bertahan lintas peluncuran, berganti hari, terhapus oleh Erase All
  Data, suite terisolasi.
- **`NudgeText`** — kalimat untuk tiap jenis, termasuk format jam.
- **`BubblePlacement`** — tes C1 tetap hijau apa adanya, plus ukuran non-360.

### Manual

1. Balon muncul di samping robot dan hilang sendiri setelah 8 detik.
2. Kursor di atas balon menahannya.
3. Klik membuka bubble berisi sapaan itu sebagai giliran asisten.
4. Toggle suara di Settings → balon berikutnya dibacakan sekali.
5. App lain layar penuh → tidak ada balon.
6. Apl di depan → tidak ada balon.
7. Regresi C1: ⌥Space, klik robot, dan Esc masih seperti semula.

---

## 8. Definition of Done

- [ ] Test unit §7 hijau; suite C1 dan B tetap hijau.
- [ ] `verify-boundaries` dan `verify-release` hijau.
- [ ] Daftar manual §7 dijalankan di app sungguhan, hasilnya dicatat di plan.
- [ ] Suara mati secara bawaan.
- [ ] `DinoPocket.entitlements` **tidak berubah sama sekali**.
- [ ] `nudge.speaks` dan `nudge.history` hilang saat Erase All Data.

---

## 9. Yang sengaja tidak dikerjakan

- **Membaca status Focus.** Butuh capability dan dialog izin; lihat §2 #2.
- **Sapaan harian dan pelacakan durasi kerja.** Yang kedua adalah wellness tracking yang
  dibuang di sub-project A.
- **Membacakan jawaban biasa.** Suara hanya untuk yang tidak diminta, yang jumlahnya
  sudah dibatasi kuota.
- **Balon di layar sekunder.** Robot masih terkunci di `NSScreen.main` (batasan C1 §11).
- **Aksi di dalam balon** (Snooze, Done). Klik membuka percakapan; di situ semuanya bisa
  dikatakan dengan kalimat.

---

## 10. Risiko yang diketahui

**Deteksi app layar penuh lewat `CGWindowList` adalah satu-satunya sinyal di §4 yang belum
pernah dijalankan di app ini.** Bila ternyata tidak dapat diandalkan tanpa izin Screen
Recording, jatuhnya ke aturan yang lebih kasar: anggap layar penuh bila jendela terdepan
milik app lain menutupi seluruh layar menurut `NSWorkspace` dan `NSScreen`, dan bila itu
pun gagal, sinyal ini dibuang dan dicatat sebagai batasan — bukan diganti dengan izin baru.

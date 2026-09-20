# Apl — Panggil dari Mana Saja (Sub-project C1) — Design Spec

- Tanggal: 2026-09-19
- Status: Disetujui. Rencana implementasi: `docs/superpowers/plans/2026-09-19-apl-quick-ask.md`
  (penyesuaian saat perencanaan di §13)
- Basis kode: branch `refactor/taggo-architecture` @ `b2a6d5b` (working tree bersih)
- Target: **macOS 26+** (Apple Silicon), distribusi **Mac App Store**
- Melanjutkan: `2026-09-15-apl-main-window-design.md` (sub-project B). Bila bertentangan,
  dokumen ini yang berlaku untuk hal-hal di §2.

---

## 1. Konteks

Sub-project A merapikan fondasi, B mengubah jendela utama jadi chat-first. Keduanya
mengandaikan orang membuka jendela Apl lebih dulu. Robot di desktop sudah ada sejak
sebelum keduanya — ia berjalan-jalan, berganti ekspresi, dan kalau diklik mengucapkan
kalimat sapaan acak — tetapi ia tidak bisa diajak bicara. Satu-satunya cara bertanya
adalah kembali ke jendela utama.

**Sub-project C** menutup jarak itu: Apl hadir di desktop, bukan menunggu di jendelanya.
C terlalu besar untuk satu spec, jadi dipecah dua:

| | Isi | Status |
|---|---|---|
| **C1** | Shortcut global, bubble satu giliran di robot, klik robot untuk bicara | Dokumen ini |
| **C2** | Mesin proaktif (aturan, kuota, Focus) dan TTS | Spec sendiri, setelah C1 |

Pemisahan ini bukan kenyamanan administratif. C1 hanya memindahkan jalan masuk ke
percakapan yang sudah ada; C2 memberi Apl hak untuk memulai bicara, dan hak itu butuh
aturan, kuota, dan penghormatan pada Focus — keputusan yang tidak boleh diselundupkan
lewat spec tentang shortcut.

### Yang sudah ada dan dipakai apa adanya

`ChatStore` (B) memiliki `send(_:)`, `retry(_:)`, `stopStreaming()`, `messages`,
`isStreaming`, dan `lastEvent`. `AplBuddyWindowController.shared` mengelola panel robot.
`CharacterMoodResolver` memetakan keadaan percakapan ke ekspresi. Ketiganya tidak diubah
perilakunya oleh C1, hanya dipakai dari tempat baru.

---

## 2. Keputusan yang mengikat

1. **Bubble memakai `ChatStore` yang sama dengan jendela utama.** Tidak ada penyimpanan
   percakapan kedua dan tidak ada sinkronisasi. Apa pun yang ditanyakan lewat robot
   muncul utuh di jendela utama, dan sebaliknya.
2. **Bubble menampilkan tepat satu giliran**: pertanyaan terakhir dan jawabannya.
   Riwayat tinggal di jendela utama, dicapai lewat tautan "Buka di Apl".
3. **Shortcut dipilih dari daftar siap pakai**, bukan perekam tombol: Off, ⌥Space
   (bawaan), ⌥⌘A, ⌃⌥Space.
4. **Klik robot membuka bubble siap diketik.** Kalimat sapaan acak
   (`AplBuddyWindowController.greetings` beserta `greetingTimer`) dihapus; sapaan yang
   muncul sendiri adalah urusan C2, dengan aturan dan kuota.
5. **Pendaftaran hotkey lewat `RegisterEventHotKey`** (Carbon), bukan `CGEventTap`.
   Tanpa izin Accessibility, aman untuk App Store.
6. **Bubble tidak menutup sendiri setelah menjawab.** Ia menutup hanya karena tindakan:
   Esc, klik di luar, shortcut ditekan lagi, app lain diaktifkan, atau "Buka di Apl".
7. **C1 tidak menambah satu pun jenis data baru** selain satu preferensi shortcut.

---

## 3. Arsitektur

Enam unit baru, masing-masing bisa dipahami dan diuji sendiri, plus satu tambahan kecil
pada pengendali robot yang sudah ada.

| Unit | Tanggung jawab | Bergantung pada |
|---|---|---|
| `ShortcutPreset` | Enum pilihan siap pakai → kode tombol, modifier, teks tampilan; baca/tulis preferensi | `UserDefaults` |
| `QuickAskShortcut` | Mendaftarkan dan mencabut hotkey global, memanggil satu closure di main thread | `HotKeyRegistering` |
| `QuickAskRouter` | Menerjemahkan penekanan tombol jadi satu dari tiga tindakan | — (fungsi murni) |
| `BubblePlacement` | Menghitung frame bubble dari frame robot dan layarnya | — (fungsi murni) |
| `FocusRestorer` | Mencatat app yang di depan sebelum Apl aktif, memulihkannya sekali saat bubble tutup | `NSWorkspace` lewat protokol kecil |
| `QuickAskPanelController` | Panel yang bisa menerima fokus keyboard, isinya `QuickAskBubble`; buka, tutup, kembalikan fokus | lima unit di atas + `ChatStore` |

Tambahan pada `AplBuddyWindowController`: satu properti baca
`characterScreenFrame: (rect: CGRect, screen: NSScreen)?`, dan kemampuan menahan langkah
robot selama bubble terbuka (`pauseStrolling()` / `resumeStrolling()`, memakai
`strollTimer` yang sudah ada). Penghapusan `greetings` dan `greetingTimer` terjadi di
berkas yang sama.

### Antarmuka yang dipakai antar-unit

```swift
enum ShortcutPreset: String, CaseIterable {
    case off, optionSpace, optionCommandA, controlOptionSpace
    var keyCode: UInt32? { get }        // nil untuk .off
    var modifiers: UInt32 { get }       // bendera Carbon
    var displayName: String { get }     // "⌥Space", "Off", ...
}

protocol HotKeyRegistering {
    /// Mengembalikan false bila sistem menolak (tombol sudah dipegang pihak lain).
    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) -> Bool
    func unregister()
}

enum QuickAskAction: Equatable { case focusComposer, toggleBubble, openMainWindow }

enum QuickAskRouter {
    static func action(mainWindowIsFrontmost: Bool, buddyIsRunning: Bool) -> QuickAskAction
}

enum BubblePlacement {
    static func frame(robot: CGRect, screen: CGRect, contentHeight: CGFloat) -> CGRect
}
```

### Aliran data

Penekanan tombol → `QuickAskShortcut` → `QuickAskRouter` → salah satu dari:

- `.focusComposer` — jendela utama sudah di depan; fokus pindah ke composer di sana.
- `.toggleBubble` — Buddy Mode hidup; `QuickAskPanelController` buka atau tutup.
- `.openMainWindow` — Buddy Mode mati; jendela utama ke depan, composer fokus.

`QuickAskRouter` hanya tahu dua fakta itu. Kalau ia memutuskan `.toggleBubble` tetapi
robot belum punya frame (Buddy baru saja menyala), `QuickAskPanelController` yang
menurunkan tindakan jadi `.openMainWindow` — keputusan itu milik controller, bukan
router, karena hanya controller yang bisa bertanya ke `AplBuddyWindowController`.

Di dalam bubble, mengirim memanggil `chat.send(_:)`; bubble menggambar dari
`chat.messages.suffix(2)` dan `chat.isStreaming`. Tidak ada jalur balik dari bubble ke
penyimpanan — satu arah, dari `ChatStore` ke layar.

---

## 4. Perilaku bubble

**Membuka.** Panel muncul di samping kepala robot dengan composer langsung fokus.
Sebelum Apl mengambil fokus, app yang sedang di depan dicatat. Robot berhenti melangkah
selama bubble terbuka; ekspresinya tetap mengikuti `CharacterMoodResolver` yang sama
dengan jendela utama, jadi wajah berpikir dan wajah gagal sama persis di kedua tempat.

**Penempatan.** Lebar tetap 360pt. Tinggi mengikuti isi sampai 280pt, setelah itu isinya
digulir. Bubble muncul di sisi robot yang ruangnya lebih lega; bila mentok tepi layar ia
pindah sisi; bila kedua sisi sempit ia dijepit ke dalam `visibleFrame`. Layarnya selalu
layar tempat robot berada.

**Mengetik.** Return mengirim, ⇧Return menyisipkan baris baru — memakai monitor
`ShiftReturnNewline` yang sudah ada di `Composer.swift`. Selama menjawab, teks tumbuh di
tempat dan tombol kirim berubah jadi stop, sama seperti jendela utama.

**Esc.** Sedang menjawab → hentikan jawaban (`chat.stopStreaming()`). Tidak sedang
menjawab → tutup bubble. Dua kali Esc berarti berhenti lalu tutup. Monitor Esc milik
`AplBuddyWindowController` harus meneruskan event yang ditujukan ke panel bubble, persis
seperti yang sudah dilakukannya untuk jendela biasa sejak perbaikan di B.

**Satu giliran.** Bubble menampilkan pertanyaan terakhir dan jawabannya. Mengirim lagi
mengganti isinya, tidak menumpuk. Di bawah jawaban ada "Buka di Apl" yang membawa jendela
utama ke depan, menggulir ke bawah, dan menutup bubble.

**Menutup.** Esc, klik di luar, shortcut ditekan lagi, app lain diaktifkan, atau "Buka di
Apl". Saat menutup, fokus kembali ke app yang tadi dipakai dan robot melangkah lagi.
Tidak ada yang hilang saat bubble tertutup: setiap giliran sudah ada di `ChatStore`.

**Reminder.** Reminder yang terbentuk tampil sebagai satu baris konfirmasi dengan "Undo" —
yaitu `ReminderChip` yang sama dengan jendela utama (lihat §13 #1). Pembuatannya lewat jalur
B tanpa perubahan.

**Apple Intelligence mati.** Satu baris ringkas di atas composer menautkan ke Settings —
versi pendek `AIUnavailableBanner`. Reminder tetap bisa dibuat, sebagaimana di B.

---

## 5. Shortcut dan Settings

**Pilihan.** Off, **⌥Space** (bawaan), **⌥⌘A**, **⌃⌥Space**. ⌃Space sengaja tidak
ditawarkan: macOS memakainya untuk berpindah sumber input. ⌥Space sendiri adalah bawaan
Raycast dan Alfred — karena itu Off dan dua alternatif wajib ada, bukan pelengkap.

**Pendaftaran.** `RegisterEventHotKey` dengan satu `InstallEventHandler`, dipasang di
main thread, dicabut saat pilihan berubah dan saat app berhenti.

**Kegagalan pendaftaran** tidak boleh diam. Bila `register` mengembalikan false, satu
baris status muncul di bawah pilihan: "⌥Space sedang dipakai app lain — coba pilihan
lain."

**Penyimpanan.** Satu kunci `UserDefaults`, `shortcut.quickAsk`, berisi `rawValue`
preset, diikuti `synchronize()` sesuai aturan durabilitas yang ditetapkan di B. Nilai tak
dikenal jatuh ke ⌥Space; Off tetap Off.

**Tempatnya** satu baris di tab General di Settings. Tab Voice menunggu C2.

**Ditemukan orang.** Langkah terakhir onboarding menyebut tombolnya dalam satu kalimat —
teks saja, tanpa layar baru — dan barisnya ada di General untuk dilihat lagi.

Shortcut hanya hidup selama Apl berjalan. Buka-saat-login adalah pertanyaan rilis
(sub-project D), bukan C1.

---

## 6. Keadaan pinggir dan kegagalan

| Keadaan | Perilaku |
|---|---|
| Shortcut ditekan saat Apl sedang menjawab | Bubble menutup; jawaban **tidak** dihentikan dan tetap ditulis ke `ChatStore`. Hanya Esc yang menghentikan. |
| App lain sedang layar penuh | Panel bubble memakai `collectionBehavior` `[.canJoinAllSpaces, .fullScreenAuxiliary]` agar tetap muncul. |
| Layar berubah (monitor dicabut, resolusi berganti) | `didChangeScreenParametersNotification` memicu hitung ulang lewat `BubblePlacement`. |
| Buddy Mode dimatikan saat bubble terbuka | Bubble menutup. |
| Erase All Data saat bubble terbuka | Bubble menutup lebih dulu, lalu jalur hapus B berjalan. |
| Jawaban gagal | Satu baris "Apl couldn't finish this reply." dengan Retry, di dalam bubble. |
| Shortcut ditekan berulang cepat | Buka bersifat idempoten; satu controller, tidak mungkin ada dua bubble. |
| Robot belum punya frame (Buddy baru menyala) | Shortcut jatuh ke `.openMainWindow` alih-alih membuka bubble tanpa jangkar. |

**Batasan yang dipilih dengan sadar:** bubble tidak punya riwayat. Bila orang lupa apa
yang tadi ditanyakan, jawabannya ada di jendela utama.

---

## 7. Aksesibilitas

Panel `.nonactivatingPanel` tidak mendapat perlakuan aksesibilitas gratis, jadi tiga hal
diurus sendiri:

1. Panel punya label ("Apl quick ask") dan fokus berpindah ke composer saat terbuka.
2. Selesainya jawaban diumumkan lewat `NSAccessibility.post(element:notification:)`
   dengan `.announcementRequested`. Tanpa itu pengguna VoiceOver tidak tahu jawabannya
   sudah ada.
3. Reduce Motion menghilangkan animasi munculnya bubble; isinya tetap sama.

---

## 8. Privasi

C1 tidak menambah data baru selain preferensi shortcut. Bubble tidak menyimpan apa pun
sendiri, tidak membaca app lain, dan tidak meminta izin sistem baru — `RegisterEventHotKey`
tidak butuh Accessibility. Erase All Data tidak perlu tahu tentang C1 kecuali satu hal:
`shortcut.quickAsk` ikut terhapus bersama preferensi lain.

---

## 9. Pengujian

### Unit (Swift Testing, `UserDefaults(suiteName:)` terisolasi)

- **`BubblePlacement`** — ruang cukup di kanan → di kanan sejajar kepala; mentok kanan →
  pindah kiri; sempit di dua sisi → dijepit ke `visibleFrame`; robot di layar sekunder →
  frame berada di layar itu; isi melebihi 280pt → tinggi berhenti di 280.
- **`QuickAskRouter`** — tiga cabang §3 diuji tanpa satu pun `NSWindow`.
- **`ShortcutPreset`** — tiap preset ke kode tombol dan modifier yang benar, teks
  tampilannya, bolak-balik lewat `UserDefaults`, nilai tak dikenal jatuh ke ⌥Space, Off
  tetap Off.
- **Keadaan bubble** — mengirim mengganti giliran alih-alih menumpuk; Esc saat menjawab
  memanggil `stopStreaming`; Esc saat diam menutup; jawaban gagal menyalakan Retry.
  Memakai `ChatStore` dengan Brain palsu yang sudah ada dari B.
- **`FocusRestorer`** — mencatat app depan sebelum aktivasi, memulihkan sekali saat
  tutup, diam bila app itu sudah tidak ada. `NSWorkspace` dibungkus protokol kecil.

Pendaftaran hotkey selalu lewat `HotKeyRegistering` palsu: test berjalan di dalam
`Apl.app` dan tidak boleh mendaftarkan tombol sungguhan ke sistem.

### Manual (alat verifikasi dari B: `apl-launch.sh`, `apl-winid`, `apl-shot.sh`, `ax`)

1. ⌥Space dari Finder → bubble muncul di samping robot, langsung bisa diketik.
2. ⌥Space saat Xcode layar penuh → bubble tetap terlihat.
3. Ketik lalu Return → jawaban tumbuh; Esc menghentikan; Esc lagi menutup; app yang tadi
   di depan kembali aktif.
4. "Buka di Apl" → jendela utama ke depan, giliran itu ada di percakapan.
5. Hide Buddy lalu ⌥Space → jendela utama ke depan, composer fokus, tidak ada bubble.
6. Jendela utama sudah di depan lalu ⌥Space → composer fokus, tidak ada bubble.
7. Dua monitor: bubble berada di layar yang sama dengan robot meski app depan di layar
   lain.
8. Preset Off → ⌥Space tidak melakukan apa pun; preset ⌥⌘A → jalan.
9. Klik robot → bubble terbuka siap diketik, tidak ada kalimat sapaan acak.

### Regresi B yang wajib dicek ulang

- Esc di jendela utama masih menghentikan jawaban dan **tidak** membunuh Buddy.
- ⇧Return masih menyisipkan baris baru di composer jendela utama dan di bubble.

---

## 10. Definition of Done

- [x] Semua test unit §9 hijau; suite B tetap hijau. **193 test di 39 suite.**
- [x] `verify-boundaries` dan `verify-release` hijau.
- [x] Daftar manual §9 dijalankan di app sungguhan, hasilnya dicatat di plan
      ("Catatan eksekusi").
- [x] `greetings` dan `greetingTimer` hilang dari `AplBuddyWindowController`.
- [x] Baris shortcut ada di tab General; jalur gagal-daftar terpasang, tetapi tidak
      pernah terpicu di Mac ini (ketiga preset diterima sistem).
- [ ] VoiceOver: bubble terbaca, dan selesainya jawaban diumumkan (diuji oleh pemilik
      produk, seperti item terakhir di B).

---

## 11. Yang sengaja tidak dikerjakan

- **Perekam tombol bebas.** Daftar siap pakai menutup 95% kebutuhan tanpa UI perekam,
  tanpa deteksi bentrok, tanpa penyimpanan kombinasi sembarang.
- **Riwayat di dalam bubble.** Jendela utama sudah menjadi tempatnya.
- **Sapaan proaktif, TTS, penghormatan Focus.** Semuanya C2.
- **Robot di layar sekunder.** Hari ini robot terkunci di `NSScreen.main`
  (`AplBuddyWindowController` memakai `NSScreen.main` untuk semua perhitungan posisi).
  `BubblePlacement` sudah menerima layar mana pun, jadi memperbaiki robot nanti tidak
  menyentuh bubble.
- **Buka-saat-login.** Sub-project D.

---

## 12. Temuan basis kode yang membentuk desain ini

| Temuan | Lokasi | Akibat pada desain |
|---|---|---|
| Buddy Mode menyala sendiri saat jendela utama tampil dan **tidak** disimpan antar-sesi (`@State var isBuddyMode`) | `AplApp.swift:20`, `:118` | Cabang `.openMainWindow` jarang terpakai, tapi tetap perlu: Hide Buddy berlaku dalam satu sesi |
| Buddy bersifat aditif — jendela utama tidak disembunyikan | `AplApp+macOS.swift:18-29` | Router harus membedakan "jendela utama di depan" dari "Buddy hidup"; keduanya bisa benar bersamaan |
| Panel robot memakai `[.canJoinAllSpaces, .stationary, .ignoresCycle]`, tanpa `.fullScreenAuxiliary` | `AplBuddyWindowController.swift:78` | Bubble menambahkan `.fullScreenAuxiliary`; apakah robot sendiri terlihat di app layar penuh diperiksa saat uji manual dan dicatat, bukan diam-diam diubah |
| Posisi robot selalu dihitung dari `NSScreen.main` | `AplBuddyWindowController.swift:261`, `:307` | Robot terkunci di layar utama; dicatat sebagai batasan, bukan diperbaiki di C1 |
| Klik robot memunculkan kalimat acak selama 2,6 detik | `AplBuddyWindowController.swift:342-356` | Dihapus; klik sekarang membuka bubble |
| Monitor Esc Buddy sudah meneruskan event milik jendela lain | `AplBuddyWindowController.swift:211` | Panel bubble tinggal ikut aturan yang sama |

---

## 13. Penyesuaian saat perencanaan

Ditemukan saat menulis `docs/superpowers/plans/2026-09-19-apl-quick-ask.md` dan membaca
ulang kode yang akan dipakai.

1. **Reminder memakai `ReminderChip` yang sudah ada.** §4 semula menulis "bukan chip penuh";
   ternyata chip itu memang sudah satu kapsul satu baris dengan tombol Undo — persis yang
   dimaksud. Versi kedua hanya akan jadi tempat kedua yang bisa berbeda. Bubble memakai
   `MessageRow`, yang memilih chip itu sendiri dari lampiran pesan.
2. **Dua batas tinggi, bukan satu.** `answerMaxHeight` (200pt) membatasi area jawaban di
   dalam SwiftUI; `maxHeight` (280pt) menjepit panel sebagai jaring pengaman. Tanpa batas
   dalam, `NSHostingView` meminta tinggi sebesar isinya dan penjepitan dari luar akan
   memotong composer, bukan jawabannya.
3. **Esc ditangani di satu tempat**, monitor lokal milik panel. Monitor lokal menerima event
   sebelum responder chain, jadi `Composer.onKeyPress(.escape)` tidak pernah melihat Esc di
   dalam bubble; penanganan kedua di sana akan jadi kode mati.
4. **Monitor Esc Buddy tidak perlu diubah sama sekali** — §4 semula menyebutnya sebagai
   sesuatu yang "harus" meneruskan event; ia sudah melakukannya sejak perbaikan di B.
5. **Fokus composer jendela utama lewat penghitung, bukan Bool.** `ComposerFocus.token`
   naik tiap permintaan: menekan shortcut dua kali saat composer sudah fokus harus terbaca
   sebagai dua permintaan, dan `Bool` yang sudah `true` tidak memicu `onChange` kedua.

---

## 14. Penyesuaian saat pelaksanaan

Ditemukan saat menjalankan app sungguhan; rinciannya di "Catatan eksekusi" pada plan.

1. **Tinggi bubble 200pt untuk jawaban, langit-langit 360pt untuk panel** (§4 semula menulis
   "sampai 280pt"). Tinggi panel ditentukan `NSHostingView`, bukan `setFrame`: jawaban
   terpanjang menghasilkan 318pt dan composer dua baris 332pt. Yang benar-benar membatasi
   adalah area jawaban 200pt; 360pt hanya jaring pengaman untuk perhitungan posisi.
2. **Fokus keyboard bubble butuh tiga penegasan**, bukan satu `makeKeyAndOrderFront`.
   `NSApp.activate()` tidak langsung, dan saat app benar-benar aktif AppKit mengembalikan
   status key ke jendela utama.
3. **Klik pada robot ditangani di AppKit**, bukan `onTapGesture` SwiftUI: view RealityKit
   menelan tap sebelum SwiftUI melihatnya.
4. **Robot di app layar penuh: terlihat.** §12 menyisakan ini sebagai pertanyaan;
   jawabannya ya — `canJoinAllSpaces` pada panel robot sudah cukup, dan bubble dengan
   `fullScreenAuxiliary` ikut tampil di atasnya.
5. **Dua bug bawaan sub-project B ikut diperbaiki** karena C1 bergantung padanya: robot
   yang berdiri di luar semua layar pada Mac dua-layar, dan klik robot yang tidak pernah
   sampai. Keduanya membuat Buddy Mode tampak menyala tanpa melakukan apa pun.
6. **Panel bubble menyatakan diri bisa jadi main window.** Dilaporkan pemilik produk saat
   memakai app: satu klik pada robot memunculkan dua hal — bubble DAN jendela percakapan.
   Penyebabnya `NSApp.activate()`, yang wajib agar bubble bisa diketik, dan yang mengangkat
   MAIN window app. Panel biasanya tidak bisa jadi main, jadi yang terangkat adalah jendela
   utama. Dengan `canBecomeMain`, panel itu sendiri yang terangkat dan jendela utama tetap
   di tempatnya — §4 sekarang berlaku apa adanya: klik robot memunculkan bubble, titik.

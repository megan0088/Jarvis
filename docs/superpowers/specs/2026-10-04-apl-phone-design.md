# Apl — Companion iPhone (Sub-project H) — Design Spec

- Tanggal: 2026-10-04
- Status: Menunggu tinjauan pemilik produk
- Basis kode: branch `chore/remove-play` @ `ac821c6` (tanpa permainan, tanpa fitur gambar G)
- Branch kerja: `feat/apl-phone`
- Target: **iPhone, iOS 26+**, potret. Distribusi App Store **ditunda** ke spec rilis sendiri.
- Tidak mengubah: target `DinoPocketMac`, test-nya, maupun satu baris pun di `DinoPocketMac/`.

---

## 1. Konteks

Spec Mac 2026-08-24 §2 #4 menetapkan "v1 = Mac saja; companion iPhone dapat spec sendiri
setelah Mac app jalan". Ini spec itu.

Yang sudah siap: `SharedCore/` bebas platform dan berisi otak (`AppleBrain`, sudah
ber-`@available(macOS 26.0, iOS 26.0, *)`), model pesan, serta seluruh mesin reminder —
parser, store, UseCase, dan penjadwal notifikasi.

Yang tidak siap, dan membentuk desain di bawah:

1. **Logika yang dibutuhkan iPhone tidak semuanya di `SharedCore`.** `ChatStore`,
   `ReminderListViewModel`, `CharacterMoodResolver`, dan beberapa unit murni lain tinggal di
   `DinoPocketMac/Presentation/`. Isinya bebas platform; tempatnya saja yang milik Mac.
2. **Tidak ada sinkronisasi.** Reminder dan percakapan tersimpan lokal. Entitlement iCloud
   lama tidak aktif.
3. **1.404 baris view iOS lama** (`ContentView*.swift`, `PetActivityWidgets.swift`,
   `Haptics.swift`) menggambarkan produk yang sudah tidak ada: pet dan wellness tracker.

---

## 2. Keputusan yang mengikat

1. **Apl berdiri sendiri di iPhone.** Chat dan reminder hidup di iPhone itu sendiri. Tidak
   ada sinkronisasi dengan Mac, tidak ada iCloud, tidak ada jaringan. Janji "semuanya lokal"
   tidak berubah.
2. **Versi pertama berisi inti saja:** chat dengan Apple Intelligence, reminder dari kalimat
   biasa dengan notifikasi, daftar Up next, onboarding, Settings dengan Erase All Data, dan
   robot 3D dengan lima ekspresinya.
3. **Satu layar, tata letak A:** robot di atas, percakapan di bawah, reminder sebagai sheet.
   Tidak ada tab bar.
4. **Target terpisah di repo yang sama.** Folder `AplPhone/`, target `AplPhone`, bundle id
   `com.ega.apl.ios`. `SharedCore/` dikompilasi dari folder yang sama oleh kedua target.
5. **Logika milik folder Mac DISALIN, bukan dipindah.** Pemilik produk memilih app yang
   terpisah: pekerjaan iPhone tidak boleh menyentuh kode Mac. Harganya ditulis di §8.
6. **App Store ditunda.** Target dibangun dan dijalankan di perangkat lewat Xcode. Listing,
   screenshot, dan keputusan "satu listing atau dua" milik spec rilis iPhone.
7. **View iOS lama tidak dipakai dan tidak dihapus.** Ia tetap dibekukan; menghapusnya
   mengubah folder Mac, dan itu di luar keputusan #5.
8. **Teks antarmuka Inggris**, komentar dan dokumen Indonesia — sama dengan Mac.

---

## 3. Struktur

```
AplPhone/
├── App/            AplPhoneApp.swift, PhoneDependencies.swift
├── Shared/         salinan dari DinoPocketMac (daftar di §3.1)
├── Presentation/   view iOS, ditulis baru (§4)
├── DesignSystem/   PhoneColors.swift + salinan Spacing/Radius/AppFont
└── Assets.xcassets AppIcon, AccentColor
AplPhoneTests/      Swift Testing, dijalankan di simulator iOS 26
```

`project.yml` mendapat dua target (`AplPhone`, `AplPhoneTests`) dan satu scheme
(`AplPhone`). Sumber target `AplPhone`: `SharedCore`, `AplPhone`, dan **lima berkas**
`DinoPocketMac/Resources/Robot*.usdz` yang dirujuk langsung — asetnya tidak digandakan.

### 3.1 Berkas kembaran

Disalin dari `DinoPocketMac/` ke `AplPhone/Shared/`. Isinya tidak diubah kecuali yang
disebut di kolom ketiga.

| Asal (di `DinoPocketMac/`) | Test yang ikut disalin | Perubahan |
|---|---|---|
| `Presentation/ViewModels/ChatStore.swift` | `ChatStoreTests`, `ChatAvailabilityTests` | tidak ada |
| `Presentation/ViewModels/ChatEvent.swift` | — | tidak ada |
| `Presentation/ViewModels/ReminderListViewModel.swift` | `ReminderListViewModelTests`, `ReminderFakes` | tidak ada |
| `Presentation/Stage/ReminderDraft.swift` | `ReminderDraftTests` | tidak ada |
| `Infrastructure/Persistence/ProfileStore.swift` | `ProfileStoreTests` | tidak ada |
| `Presentation/Character/CharacterAsset.swift` | `CharacterAssetTests` | tidak ada |
| `Presentation/Character/CharacterExpressionCache.swift` | `CharacterExpressionCacheTests` | tidak ada |
| `Presentation/Character/CharacterMoodResolver.swift` | `CharacterMoodResolverTests` | tidak ada |
| `Presentation/Character/CharacterStatusText.swift` | `CharacterStatusTextTests` | tidak ada |
| `Presentation/Chat/ComposerState.swift` | `ComposerStateTests` | tidak ada |
| `Presentation/Chat/MarkdownBlocks.swift` | `MarkdownBlocksTests` | tidak ada |
| `Presentation/DesignSystem/{Spacing,Radius,AppFont}.swift` | — | tidak ada |
| `Infrastructure/Services/DebugAvailabilityBrain.swift` | `DebugAvailabilityBrainTests` | tidak ada |

`TestTime.swift` ikut disalin sebagai penunjang test.

**Aturan salinan:** berkas kembaran membawa satu baris komentar kepala yang menyebut
asalnya dan commit saat ia disalin. Itulah satu-satunya cara tahu, nanti, seberapa jauh
keduanya sudah menyimpang.

### 3.2 `SharedCore` di iOS

`SharedCore` belum pernah dikompilasi untuk iOS. Kalau ada yang gagal, perbaikannya
dilakukan **di `SharedCore`** dengan cara yang netral platform (`#if os(` tetap haram di
sana, ditegakkan `scripts/verify-boundaries.sh`), dan suite Mac dijalankan ulang untuk
membuktikan Mac tidak berubah. Ini satu-satunya pengecualian atas "tidak menyentuh Mac",
dan ia terbatas pada `SharedCore`.

---

## 4. Layar

Semua view di bawah ditulis baru untuk iOS. Tidak ada yang disalin dari view Mac: tata
letaknya dua kolom dan warnanya lewat `NSColor`.

### 4.1 Layar utama (`PhoneHomeView`)

- **Header robot.** Robot di tengah di atas glow aksen, nama "Apl", dan satu baris status
  dengan titik berwarna (`CharacterStatusText`). Tinggi penuh saat percakapan kosong atau
  berada di paling atas; mengecil menjadi baris ringkas (robot kecil + status) saat
  percakapan digulir, supaya pesan mendapat ruang.
- **Kiri atas:** tombol lonceng dengan jumlah reminder mendatang; membuka sheet §4.2.
  Tanpa angka bila nol.
- **Kanan atas:** tombol gir; membuka Settings §4.4.
- **Percakapan.** Pesan pengguna rata kanan dalam gelembung bertint aksen; pesan Apl rata
  kiri tanpa gelembung, dirender lewat `MarkdownBlocks`. Konfirmasi reminder membawa chip
  (ikon lonceng, judul, waktu, **Undo**). Jawaban gagal membawa **Retry** — hanya pada
  jawaban terakhir, aturan yang sama dengan Mac. Indikator mengetik selama potongan pertama
  belum datang. Daftar mengikuti pesan terbaru.
- **Keadaan kosong:** "Say hi to Apl" dan contoh "Remind me to stretch at 3 PM".
- **Composer.** Kolom kapsul multi-baris (1–6 baris) dengan tombol kirim bulat; berubah
  menjadi tombol stop selama menjawab. Menempel di atas keyboard; mengetuk percakapan
  menutup keyboard.
- **Notice** (`ChatStore.noticeMessage`) tampil sebagai satu baris di bawah percakapan,
  tidak pernah sebagai isi pesan.

### 4.2 Sheet reminder (`PhoneRemindersSheet`)

Daftar Up next dari `ReminderListViewModel`, terurut waktu. Geser untuk menghapus; ketuk
untuk mengubah judul dan waktu lewat `ReminderDraft`. Keadaan kosong menjelaskan cara
membuat reminder dari chat. Bila izin notifikasi ditolak, satu baris di atas daftar
mengatakannya dan menawarkan jalan ke Settings sistem — reminder yang tidak akan berbunyi
tanpa keterangan adalah janji palsu.

### 4.3 Onboarding (`PhoneOnboardingView`)

Tiga langkah, bisa dilewati kecuali yang terakhir: nama panggilan (boleh kosong); izin
notifikasi, diminta **hanya** saat tombolnya diketuk; dan status Apple Intelligence dengan
jalan ke Settings bila belum aktif. Selesai menandai `ProfileStore.hasCompletedOnboarding`.

### 4.4 Settings (`PhoneSettingsView`)

Nama panggilan; **Clear Conversation** (dengan konfirmasi; reminder tetap); **Erase All
Data** (dengan konfirmasi; memanggil `EraseAllDataUseCase` atas setiap store dan
membatalkan semua notifikasi, lalu kembali ke onboarding); versi app. Di build DEBUG saja:
pemaksa status Apple Intelligence lewat `DebugAvailabilityBrain`.

### 4.5 Warna dan tipografi

`PhoneColors` memberi nama yang sama dengan `AppColor` Mac (`accent`, `userBubble`,
`stageGlow`, `controlFill`, `statusOK`, `statusWarning`) di atas warna semantik UIKit dan
`AccentColor` di asset catalog (teal yang sama). Mengikuti terang/gelap sistem. Seluruh teks
memakai gaya Dynamic Type; tidak ada ukuran huruf yang dipaku.

---

## 5. Aliran data

Sama dengan Mac, tanpa jalur gambar:

```
kalimat → ChatStore.send
            ├─ reminder?  → CreateReminderFromTextUseCase → ReminderStore + notifikasi
            │               → pesan Apl berlampiran .reminder(id) → chip
            └─ selain itu → AppleBrain (streaming) → pesan Apl
ChatStore.lastEvent + isStreaming + ketersediaan → CharacterMoodResolver → ekspresi robot
```

- `PhoneDependencies` adalah composition root: satu `ReminderStore`, satu `ChatStore`,
  satu `ProfileStore`, `ReminderNotificationCenter.shared`, dan daftar `LocallyErasable`
  yang eksplisit. Disuntikkan lewat properti, bukan `@Environment`.
- Penyimpanan: `UserDefaults.standard` dan berkas transcript di container app iPhone.
  **Tidak ada App Group**, tidak ada iCloud.
- Momen "window activated" di `CharacterMoodResolver` dipetakan ke app menjadi aktif
  (`scenePhase == .active`): robot menyapa 3 detik saat app dibuka.
- Robot berhenti beranimasi saat app tidak aktif atau Low Power Mode menyala.

---

## 6. Ketersediaan dan kesalahan

- **Apple Intelligence mati atau belum siap.** Banner satu baris di atas composer dengan
  tombol ke Settings sistem. Composer tetap menerima ketikan: reminder tidak memakai model
  dan harus tetap bisa dibuat. Pesan biasa menghasilkan `ChatStore.unavailableNotice`.
- **Izin notifikasi ditolak.** Reminder tetap tersimpan dan tampil; keterangannya ada di
  sheet §4.2. Reminder yang dibuat sebelum izin diberikan dijadwalkan begitu izin ada —
  perilaku `sync` yang sudah ada di `ReminderScheduling`.
- **Jawaban gagal / diblokir guardrail / dihentikan.** Seluruhnya perilaku `ChatStore` yang
  sudah ada; view hanya merendernya dari `status`.
- **Aset robot gagal dimuat.** Header menampilkan ruang kosong berukuran sama dengan glow,
  bukan crash dan bukan tata letak yang melompat.
- **VoiceOver.** Robot punya label dari `CharacterStatusText`; pesan pengguna dibacakan
  dengan penanda "You said"; jawaban yang selesai diumumkan lewat
  `UIAccessibility.post(.announcement)`.

---

## 7. Pengujian

**Unit (target `AplPhoneTests`, simulator iOS 26).** Salinan test di §3.1 harus hijau tanpa
perubahan — itu bukti salinannya utuh dan `SharedCore` berperilaku sama di iOS. Test baru
untuk logika yang lahir di iOS, masing-masing unit murni yang terpisah dari view:

- pemilihan bentuk baris dari data pesan (peran, status, lampiran), bukan dari bunyi teks;
- header robot: penuh atau ringkas sebagai fungsi dari posisi gulir;
- lencana lonceng: jumlah reminder mendatang, tanpa angka bila nol;
- langkah onboarding dan syarat selesainya;
- Erase All Data di `PhoneDependencies`: setiap store terdaftar ikut terhapus.

**Regresi Mac.** `xcodebuild test -scheme DinoPocketMac` tetap hijau dengan jumlah test
yang sama seperti sebelum pekerjaan ini; `verify-boundaries` dan `verify-release` hijau.

**Manual, di iPhone 17 fisik:**

1. Onboarding selesai; izin notifikasi diminta hanya saat tombolnya diketuk.
2. Pertanyaan biasa dijawab streaming; robot berwajah "thinking" selama itu.
3. "Remind me to stretch at 3 PM" membuat reminder, chip tampil, robot merayakan.
4. Reminder berbunyi saat app ditutup.
5. **Undo** di chip dan geser-hapus di sheet sama-sama membatalkan notifikasinya.
6. Tutup dan buka app: percakapan dan reminder masih ada.
7. Header mengecil saat digulir dan kembali penuh di atas.
8. Keyboard tidak menutupi composer; baris kedua tumbuh ke atas.
9. Terang dan gelap; Dynamic Type sampai ukuran aksesibilitas terbesar tanpa teks terpotong.
10. VoiceOver membaca robot, pesan, chip, dan mengumumkan jawaban.
11. **Erase All Data** mengosongkan semuanya dan kembali ke onboarding.
12. Milik pemiliknya: mematikan Apple Intelligence untuk melihat banner dan notice-nya.

---

## 8. Risiko dan harga yang diketahui

- **Dua salinan logika.** Perbaikan di `ChatStore` Mac tidak sampai ke iPhone, dan
  sebaliknya. Mitigasinya hanya catatan asal di kepala berkas (§3.1) dan tabel kembaran di
  spec ini. Bila keduanya mulai menyimpang, jalan keluarnya adalah memindahkan unit itu ke
  `SharedCore` — pekerjaan yang sengaja tidak dilakukan sekarang.
- **Robot di iOS.** `USDZCharacterView` Mac punya riwayat masalah latar transparan dan
  kamera di RealityKit. **Tugas pertama rencana** adalah membuktikan satu ekspresi robot
  tampil benar di iPhone, di atas glow, dan bisa ditukar tanpa berkedip — sebelum layar
  lain dibangun. Kalau `RealityView` tidak bisa, jalan mundurnya gambar diam per ekspresi
  dari `docs/assets/r_*.png`.
- **Apple Intelligence di simulator** hanya berjalan bila Mac induknya mengaktifkannya.
  Test unit tidak bergantung padanya (`brain: nil` dan stub); chat yang sesungguhnya
  diperiksa di perangkat.
- **`SharedCore` di iOS** belum pernah dicoba (§3.2).

---

## 9. Definition of Done

- [ ] `AplPhone` terbangun untuk simulator iOS 26 dan terpasang di iPhone 17 fisik.
- [ ] `AplPhoneTests` hijau; salinan test §3.1 lulus tanpa diubah.
- [ ] Suite Mac hijau dengan jumlah test yang tidak berubah; `git diff` terhadap basis
      tidak menyentuh `DinoPocketMac/` maupun `DinoPocketTests/`.
- [ ] `verify-boundaries` dan `verify-release` hijau.
- [ ] Tidak ada entitlement jaringan, iCloud, atau App Group di target `AplPhone`.
- [ ] Daftar manual §7 dijalankan di perangkat, hasilnya dicatat di plan.

---

## 10. Yang sengaja tidak dikerjakan

- **Sinkronisasi** reminder atau percakapan dengan Mac, dalam bentuk apa pun.
- **Gambar dari Image Playground** — menunggu G lolos verifikasi di Mac.
- **Widget, Live Activity, Siri/App Intents** — masing-masing target dan API sendiri.
- **Sapaan proaktif**, Buddy Mode, shortcut global, dan sisi Code — milik desktop.
- **iPad dan orientasi lanskap.**
- **App Store:** listing, screenshot, privasi, harga, dan universal purchase.
- **Memindahkan logika bersama ke `SharedCore`** dan menghapus view iOS lama.

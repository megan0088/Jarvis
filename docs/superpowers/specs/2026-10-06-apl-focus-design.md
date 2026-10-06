# Apl — Sesi Fokus dan Live Activity (Sub-project I) — Design Spec

- Tanggal: 2026-10-06
- Status: Menunggu tinjauan pemilik produk
- Basis kode: branch `feat/apl-phone` @ `4717483` (companion iPhone, Task 1–8 selesai)
- Target: **iPhone, iOS 26+**, potret. Mac tidak ikut.
- Menunggu: **H Task 9** selesai — spec ini menumpang layar chat dan `PhoneDependencies`
  yang dibangun di sana.

---

## 1. Konteks

Apl hari ini hanya punya satu hal yang berjalan di waktu: reminder, yang berbunyi sekali
lalu selesai. Permintaan pemilik produk — Live Activity — menuntut sesuatu yang
**sedang berlangsung** dan terlihat tanpa membuka app.

Reminder bukan kandidat yang baik untuk itu, dan alasannya teknis: **Live Activity hanya
bisa dimulai saat app berada di depan.** Memulainya dari latar belakang menuntut push
server, dan janji Apl adalah tanpa jaringan sama sekali. Reminder untuk jam 3 sore yang
dibuat pagi hari tidak akan pernah bisa menumbuhkan kartu saat app tertutup.

Sesi fokus tidak punya masalah itu: ia selalu dimulai pada detik kamu mengetiknya, durasinya
pendek dan pasti, dan ia memang sesuatu yang sedang berlangsung. Karena itu fitur ini
**menambah satu konsep produk baru** — sesi — bukan sekadar permukaan baru untuk yang lama.

---

## 2. Keputusan yang mengikat

1. **Sistem yang menghitung mundur, bukan app.** Live Activity dimulai sekali dengan
   tanggal berakhir, dan widget memakai timer bawaan SwiftUI. Apl hanya mengirim pembaruan
   saat keadaan berubah. Konsekuensinya: hitungan tidak pernah meleset, jatah pembaruan
   ActivityKit tidak terpakai, dan kartunya tetap berdetak walau app ditutup.
2. **Dimulai dengan mengetik**, dikenali lokal tanpa menyentuh model — jalur kedua sesudah
   reminder, pola yang sama dengan "remind me". Tidak ada kontrol baru di layar utama.
3. **Berakhir dengan notifikasi dan satu kalimat Apl** di percakapan — pasti, bukan acak:
   `"Focus session done — 25 minutes."` Notifikasi dijadwalkan sejak sesi dibuat, jadi ia
   berbunyi walau app sudah lama ditutup.
4. **Satu tombol di kartunya: Stop.** Tidak ada jeda dan tidak ada perpanjangan. Menjeda
   timer yang dirender sistem berarti mengakhiri aktivitas dan memulai yang baru dengan
   tanggal berbeda — dua keadaan tambahan untuk kenyamanan yang jarang dipakai.
5. **Durasi dibatasi 5–120 menit.** Di atas itu Live Activity dimatikan sistem sebelum
   sesinya selesai, dan timer yang menghilang diam-diam lebih buruk daripada ditolak.
6. **Tidak ada App Group, tidak ada iCloud, tidak ada jaringan** — batasan companion iPhone
   tidak berubah.
7. **iPhone saja.** Mac sudah siap rilis; membuka kembali target itu bukan bagian dari
   permintaan ini.

---

## 3. Arsitektur

| Unit | Tanggung jawab | Murni? |
|---|---|---|
| `FocusCommand` | Mengenali ajakan fokus dan **mengambil durasinya**; menolak yang mirip | **ya** |
| `FocusSession` | Satu sesi: mulai, berakhir, dan nasibnya (`running`/`finished`/`stopped`) | **ya** |
| `FocusOutcome` | Memutuskan kapan kalimat penutup layak masuk percakapan, **tepat sekali** | **ya** |
| `FocusActivityController` | Memulai, memperbarui, mengakhiri Live Activity (ActivityKit) | tidak |
| `FocusNotifier` | Satu notifikasi lokal di waktu berakhir; dibatalkan bila sesi dihentikan | tidak |
| `FocusStore` | Keadaan sesi yang dibaca layar; dimiliki `PhoneDependencies` | tidak |
| `StopFocusIntent` | `LiveActivityIntent` di balik tombol Stop | tidak |

**Target baru: `AplPhoneWidgets`**, sebuah widget extension. Live Activity dirender proses
lain — itulah sebabnya hitungannya tetap berjalan saat Apl ditutup.

### 3.1 Pengecualian lapis yang diambil dengan sadar

Tipe `ActivityAttributes` adalah **kontrak antara dua target** dan wajib
`import ActivityKit`. Aturan `AplPhone/Domain/` melarang impor selain `Foundation`, jadi ia
tidak boleh tinggal di sana. Ia diberi folder sendiri, `AplPhoneShared/`, di luar tiga lapis
dan dikompilasi oleh app maupun widget. `scripts/verify-phone-layers.sh` mendapat satu
aturan baru: folder itu hanya boleh berisi tipe atribut, supaya ia tidak pelan-pelan menjadi
tempat sampah lintas-target.

### 3.2 Aliran

```
"focus 25 minutes" → ChatStore menangkap lokal (tanpa model)
   → FocusStore membuat FocusSession, menyimpannya ke disk
   → FocusActivityController.start(endsAt:)   → kartu muncul, sistem menghitung mundur
   → FocusNotifier.schedule(at: endsAt)       → alarm berbunyi walau app ditutup
waktu habis → notifikasi berbunyi
   → app dibuka → FocusOutcome memutuskan → ChatStore.appendAssistantNote(satu kalimat)
```

Sesi **wajib tersimpan ke disk saat dibuat**, di `UserDefaults.standard` dengan kunci
`focus.session`, dan terdaftar `LocallyErasable` seperti seluruh penyimpanan lain. Tanpa itu,
app yang dibuka kembali tidak tahu sesi itu pernah ada, dan kalimat penutupnya hilang.

---

## 4. Empat permukaan

**Batasan yang menentukan tampilannya:** widget tidak bisa merender robot 3D — tidak ada
RealityKit di proses widget. Keempat permukaan memakai **PNG datar** dari `docs/assets/`
(`r_Flat.png`, `r_BigSmile.png`), aset yang sudah ada.

1. **Lock Screen / banner.** Robot kecil di kiri; "Focus" di atas dan hitung mundur
   monospasi besar di bawahnya; bilah kemajuan 3pt di dasar kartu; tombol **Stop** di kanan.
   Latar lewat `activityBackgroundTint` teal gelap, mengikuti terang/gelap sistem.
2. **Dynamic Island, ringkas kiri.** Wajah robot 16pt — satu-satunya tempat identitas Apl
   muncul saat kamu memakai app lain.
3. **Dynamic Island, ringkas kanan.** Hitung mundur `12:34`, monospasi, teal.
4. **Minimal.** Satu lingkaran kemajuan teal 2pt dengan wajah robot di tengah. Tanpa angka:
   di ruang sekecil itu angka hanya jadi noda.
5. **Membentang.** Robot 44pt di kiri atas, "Focus session" di sebelahnya, hitung mundur
   besar di kanan, bilah kemajuan penuh, dan tombol **Stop**.

**Dua keadaan akhir**, keduanya terlihat sebentar sebelum menghilang:

- **Selesai:** wajah `r_BigSmile`, teks "Done — 25 minutes", hitung mundur hilang, kartu
  menghilang sendiri setelah dua menit (`dismissalPolicy`).
- **Dihentikan:** wajah `r_Flat`, teks "Stopped", menghilang segera.

Yang tidak pernah terjadi: kartu membeku di `00:00` tanpa penjelasan.

**VoiceOver** membaca permukaan ringkas sebagai "Focus, 12 minutes left" — bukan deretan
angka dan titik dua.

---

## 5. Gangguan

- **App dimatikan dari switcher.** Tidak ada yang berubah: hitungan milik sistem, notifikasi
  sudah dijadwalkan. Syaratnya sesi tersimpan ke disk (§3.2).
- **iPhone restart.** **Live Activity tidak selamat** — sistem mengakhiri semuanya. Notifikasi
  lokal selamat, jadi alarm tetap berbunyi dan kalimat penutup tetap muncul. Kartunya tidak
  dipulihkan; berpura-pura memulihkan yang sudah dibunuh sistem hanya menambah keadaan palsu.
- **Stop ditekan dari Dynamic Island.** Memakai `LiveActivityIntent` (iOS 17+; protokol
  pendahulunya sudah deprecated untuk diganti ini), yang dijalankan **di proses app**, bukan
  extension. Satu tombol itu mengakhiri aktivitas, membatalkan notifikasi, dan menulis
  keadaan sesi — semuanya di tempat yang benar, tanpa App Group.
- **Sesi baru saat satu sedang jalan.** Yang lama berakhir sebagai `stopped`, yang baru
  mulai, dan Apl mengatakannya dalam satu kalimat. Menolak permintaan yang jelas disengaja
  lebih menyebalkan daripada mengganti.
- **Izin notifikasi ditolak.** Sesinya tetap berjalan dan kartunya tetap tampil — keduanya
  tidak memerlukan izin apa pun. Yang hilang hanya alarmnya, dan itu dikatakan satu kali
  saat sesi dimulai, bukan didiamkan.
- **Reminder berbunyi di tengah sesi.** Dibiarkan berbunyi. Membungkamnya demi ketenangan
  sesi berarti mengingkari janji yang lebih tua.

---

## 6. Pengujian

**Tanpa perangkat.** `FocusCommand` mengenali "focus 25 minutes", "fokus 50 menit",
"focus for 1 hour"; menolak "remind me to focus at 3pm" dan "how do I focus better?"; dan
menolak durasi di luar 5–120 menit. `FocusSession` diuji dengan jam yang disuntikkan: sisa
waktu, kemajuan, dan ketiga perpindahan keadaan. `FocusOutcome` membuktikan kalimat penutup
muncul **tepat sekali**, tidak muncul untuk sesi yang dihentikan, dan tetap muncul untuk
sesi yang berakhir sewaktu app tertutup. `FocusStore` diuji di atas **protokol palsu** untuk
aktivitas dan notifikasi — tidak satu test pun menyentuh ActivityKit.

**Yang jujur tidak bisa diuji otomatis:** rendernya sendiri. Keempat permukaan, tombol Stop,
perilaku setelah restart, dan hilangnya kartu dua menit setelah selesai — semuanya daftar
periksa manual di iPhone fisik. Simulator bisa menampilkan Dynamic Island, tetapi yang
menentukan tetap perangkat.

**Regresi.** Suite Mac tetap hijau dengan jumlah test yang sama; suite iPhone bertambah
hanya oleh test di atas; `verify-boundaries`, `verify-release`, dan `verify-phone-layers`
hijau.

---

## 7. Definition of Done

- [ ] Mengetik "focus 25 minutes" memunculkan kartu di Lock Screen dan Dynamic Island.
- [ ] Hitung mundur tetap berjalan setelah app ditutup dari switcher.
- [ ] Notifikasi berbunyi tepat waktu; kalimat penutup muncul sekali saat app dibuka.
- [ ] Tombol Stop mengakhiri kartu **dan** membatalkan notifikasinya.
- [ ] Durasi di luar 5–120 menit ditolak dengan kalimat yang menjelaskan.
- [ ] Test §6 hijau; suite Mac tidak berubah jumlahnya.
- [ ] `AplPhoneShared/` hanya berisi tipe atribut, ditegakkan `verify-phone-layers`.
- [ ] Tidak ada App Group, iCloud, atau entitlement jaringan yang bertambah.
- [ ] Daftar manual §6 dijalankan di perangkat, hasilnya dicatat di plan.

---

## 8. Yang sengaja tidak dikerjakan

- **Live Activity untuk reminder** — tidak bisa dimulai dari latar belakang tanpa push
  server, dan server berarti jaringan.
- **Jeda dan perpanjangan sesi** (§2 #4).
- **Sesi fokus di Mac**, widget layar utama, Siri, dan App Intents di luar tombol Stop.
- **Statistik fokus** — berapa sesi minggu ini, rentetan harian. Itu produk lain.
- **Membungkam notifikasi lain selama sesi**, termasuk reminder.
- **Push-to-start token** dan segala bentuk pembaruan dari server.

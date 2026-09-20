# Apl — Siap Submit (Sub-project D) — Design Spec

- Tanggal: 2026-09-20
- Status: Disetujui
- Basis kode: branch `refactor/taggo-architecture` @ `9689bb6` (working tree bersih)
- Target: **macOS 26+** (Apple Silicon), distribusi **Mac App Store**
- Menutup program A → B → C1 → C2. Bila bertentangan dengan spec sebelumnya soal
  konfigurasi rilis, dokumen ini yang berlaku.

---

## 1. Konteks

Kodenya sudah jadi app. Yang belum: berkas-berkas kecil yang menentukan apakah ia boleh
masuk toko, dan kalimat-kalimat yang menentukan apakah orang mengerti untuk apa ia ada.

Keadaan hari ini lebih siap dari dugaan: ikon app lengkap sepuluh ukuran,
`PrivacyInfo.xcprivacy` menyatakan tidak ada data yang dikumpulkan, dan
`scripts/verify-release.sh` sudah menjaga delapan keputusan yang bila dilanggar tetap
menghasilkan build hijau. Yang tersisa adalah sisa-sisa era lama dan materi yang memang
belum pernah ditulis.

### Yang ditemukan saat survei

| Temuan | Akibat bila dibiarkan |
|---|---|
| Kategori `public.app-category.healthcare-fitness` | App dinilai di rak yang salah; peninggalan wellness tracker yang dibuang di A |
| Deployment target `26.2`, padahal API tertinggi yang dipakai 26.0 | Mac App Review dengan 26.0/26.1 **tidak bisa memasang** app-nya |
| `DinoPocketMac/DinoPocket.entitlements` tidak dirujuk `CODE_SIGN_ENTITLEMENTS` mana pun | Berkas mati berisi app group dan iCloud KV yang tidak pernah berlaku — menunggu suatu hari disambungkan dan meminta capability yang tidak dipakai |
| `JarvisWidget/`, `JarvisUITests/`, `JarvisIOS.entitlements` tidak dirujuk `project.yml` | Kode mati dengan nama codename lama |
| README menjanjikan "pengingat kebiasaan sehat" | Janji yang sudah tidak ditepati app-nya sejak A |

---

## 2. Keputusan yang mengikat

1. **Kategori: `public.app-category.productivity`.** Apl adalah asisten yang menjawab dan
   mengingatkan; itu rak yang benar, dan pembandingnya benar.
2. **Deployment target: macOS 26.0**, bukan 26.2. Tidak satu pun API 26.2 dipakai
   (`FileChatSessionStore` sudah dijaga `#available(macOS 26.0, *)`), dan batas yang lebih
   tinggi dari kebutuhan hanya mengurangi siapa yang bisa memasang — termasuk App Review.
3. **Tidak ada submit oleh saya.** Archive disiapkan dan diperiksa; mengunggah,
   menandatangani dengan Apple ID, dan menekan Submit for Review adalah tindakan pemilik
   produk ke pihak luar.
4. **Deskripsi tidak menjanjikan apa yang belum ada.** Tidak ada pelacakan kebiasaan sehat
   (dibuang di A), tidak ada membaca CLI atau Xcode (belum dibangun).
5. **Screenshot tidak memuat app pihak ketiga.** Jendela Apl dipotret sendiri lalu disusun
   di atas latar polos — desktop pemilik produk bukan bahan pamer, dan App Review menolak
   merek lain di dalam gambar.
6. **Berkas mati dihapus, berkas yang dikarantina tidak.** `Legacy/` dan `ContentView*.swift`
   sudah sengaja dikecualikan dari build dan didokumentasikan; mereka tinggal.
7. **Kunci `"jarvis.chat.recent"` tidak diganti.** Namanya peninggalan, tetapi menggantinya
   berarti membuang percakapan orang.

---

## 3. Perubahan repo

**Konfigurasi** (`project.yml`): kategori jadi `productivity`, `deploymentTarget.macOS` jadi
`"26.0"`.

**Dihapus:** `JarvisWidget/`, `JarvisUITests/`, `JarvisIOS.entitlements`,
`DinoPocketMac/DinoPocket.entitlements`, dan baris `excludes` untuk berkas terakhir itu.

**README** ditulis ulang pada bagian yang menjanjikan wellness, dan diberi satu paragraf
tentang apa yang app ini lakukan sekarang: chat on-device, reminder dari kalimat biasa,
karakter di desktop, shortcut global, dan sapaan proaktif berkuota.

**`scripts/verify-release.sh`** bertambah tiga pemeriksaan — semuanya menjaga keputusan yang
hari ini bisa dilanggar tanpa membuat build merah:

| Pemeriksaan | Menjaga |
|---|---|
| Kategori **persis** `public.app-category.productivity` | Bukan sekadar "ada kategori apa pun" seperti sekarang |
| `MACOSX_DEPLOYMENT_TARGET` = `26.0` | Batas yang naik diam-diam mengusir pemasang, termasuk App Review |
| Tidak ada `*.entitlements` yang tidak dirujuk | Berkas mati yang suatu hari tersambung dan meminta capability tak terpakai |

---

## 4. Materi listing

Satu berkas siap tempel: `docs/appstore/2026-09-20-listing.md`.

| Bidang | Isi |
|---|---|
| Nama | Apl |
| Subtitle | On-device desktop companion |
| Kategori | Productivity |
| Usia | 4+ |
| App Privacy | Data Not Collected |
| Keywords | assistant, reminder, desktop, companion, on-device, apple intelligence, chat, robot |

**Deskripsi** menulis apa yang ada hari ini dan menyebut syaratnya di awal, bukan di
catatan kaki: chat memerlukan Apple Intelligence, dan pengingat berjalan tanpanya.

**Review notes** memuat tiga hal yang akan membingungkan reviewer bila tidak dikatakan:

1. Chat butuh Apple Intelligence, yang di Mac reviewer kemungkinan besar mati. App
   menjelaskannya sendiri di layar dengan tautan ke System Settings, dan pengingat tetap
   berfungsi — banner itu dibangun di B persis untuk keadaan ini.
2. Tidak ada akun dan tidak ada server, jadi tidak ada kredensial uji.
3. Robot melayang di atas jendela lain dan ada shortcut global — keduanya lewat `NSPanel`
   dan `RegisterEventHotKey`, tanpa izin Accessibility dan tanpa perekaman layar.

**Yang harus datang dari pemilik produk**, dan tidak bisa dikarang: URL kebijakan privasi
(wajib untuk semua app, bahkan yang tidak mengumpulkan apa pun), URL dukungan,
ketersediaan nama "Apl" di App Store Connect, dan harga.

---

## 5. Screenshot

Empat gambar **1280×800** di `docs/appstore/screenshots/` — ukuran sah paling kecil, dan
satu-satunya yang bisa diambil 1:1 di layar mesin ini tanpa memperbesar piksel:

1. Jendela utama dengan percakapan dan chip reminder.
2. Robot di desktop dengan bubble quick ask terbuka.
3. Balon sapaan proaktif di samping robot.
4. Tab Character di Settings.

Jendela Apl dipotret sendiri (panelnya transparan), lalu disusun di atas latar polos oleh
alat kecil yang dibuat untuk itu. Percakapan pemilik produk **tidak dihapus** demi
merapikan gambar; screenshot memakai giliran baru di bawahnya.

---

## 6. Verifikasi

`verify-release.sh` hijau dengan tiga aturan baru, seluruh suite tetap hijau setelah
pembersihan, lalu **archive Release dibangun secara lokal** dan `Info.plist` di dalamnya
diperiksa satu per satu: kategori, bundle id, `CFBundleShortVersionString`,
`CFBundleVersion`, `LSMinimumSystemVersion`, hak cipta, `ITSAppUsesNonExemptEncryption`,
dan ikon yang benar-benar terbundel.

Archive yang lolos pemeriksaan itu adalah bukti terdekat dengan "siap submit" yang bisa
diberikan tanpa Apple ID pemilik produk.

---

## 7. Definition of Done

- [x] Kategori `productivity` dan deployment target `26.0`, dijaga `verify-release.sh`.
- [x] Empat berkas mati terhapus; build dan seluruh suite tetap hijau (**225 test**).
- [x] README tidak lagi menjanjikan pelacakan kebiasaan sehat.
- [x] `docs/appstore/2026-09-20-listing.md` lengkap, termasuk review notes dan daftar
      "harus datang dari pemilik produk".
- [x] Empat screenshot 1280×800, tanpa app pihak ketiga di dalamnya.
- [x] Archive Release terbangun dan `Info.plist`-nya diperiksa — sepuluh kunci benar,
      `AppIcon.icns` terbundel.

---

## 8. Yang sengaja tidak dikerjakan

- **Mengunggah dan submit.** Lihat §2 #3.
- **Mengganti nama target, folder, dan project** dari codename `DinoPocket`. Tidak terlihat
  pengguna maupun App Review; memindahkannya berarti menyetel ulang skema tanpa imbalan.
- **Menaikkan versi di atas 1.0 (1).** Ini submit pertama.
- **Menghapus `Legacy/` dan `ContentView*.swift`.** Dikarantina dengan sengaja, bukan
  terlupakan.

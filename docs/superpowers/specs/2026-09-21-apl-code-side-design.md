# Apl — Sisi Code (Sub-project E) — Design Spec

- Tanggal: 2026-09-21
- Status: Disetujui
- Basis kode: branch `main` @ `b7ee0cb` (working tree bersih)
- Target: **macOS 26+** (Apple Silicon), distribusi **Mac App Store**
- Melanjutkan: `2026-09-20-apl-release-design.md` (D). Tidak mengubah apa pun yang sudah
  dikirim ke App Store kecuali yang disebut §3.

---

## 1. Konteks

Apl bisa diajak bicara dari mana saja, mengingatkan, dan menyapa lebih dulu. Yang belum:
ia tidak tahu apa-apa tentang kode yang sedang dikerjakan pemiliknya.

Permintaannya: "seperti Code dalam Claude — pisahkan antara chat dan code". Pemisahan itu
bagian yang mudah. Yang menentukan adalah apa yang ada di belakangnya, dan di situ ada
satu kenyataan yang tidak bisa dinegosiasikan.

### Batas yang membentuk seluruh desain

**Foundation Models on-device punya sekitar 4.096 token untuk segalanya** — instructions,
riwayat, isi berkas, dan jawabannya sekaligus. Bukan karena kurang dioptimalkan: model itu
dimuat sistem dan dipakai bersama semua app, cache attention-nya tinggal di RAM yang sedang
dipakai Xcode dan Safari, dan ia harus hidup juga di dalam iPhone. Apple memang punya model
yang lebih besar (Private Cloud Compute), tetapi **tidak membukanya untuk app pihak ketiga**.

Sub-project B sudah bertabrakan dengan batas ini: `AppleBrain` menangkap
`exceededContextWindowSize` lalu mencoba ulang dengan transcript terpangkas. Sisi Code
tidak menambal tabrakan itu — ia **mencegahnya**, dengan anggaran token yang terlihat di
layar.

Konsekuensi yang diterima sejak awal: sisi Code berguna untuk "kenapa error ini", "fungsi
ini apa", "ubah bagian ini". Ia **tidak** akan memahami arsitektur proyek atau menulis
fitur. Menjanjikan itu berarti berbohong pada model sebesar ini.

---

## 2. Keputusan yang mengikat

1. **Otak tetap on-device.** Janji "semuanya tetap di Mac ini" — yang tertulis di deskripsi
   App Store, tab Privacy, dan README — tidak dicabut.
2. **Ruang kedua di jendela utama**, bukan jendela terpisah dan bukan mode di percakapan
   yang sama. Pemilih Chat | Code di atas kolom percakapan.
3. **Otak kedua, sesi dan transcript sendiri**, dengan instructions sendiri. Satu sesi yang
   dipakai bergantian akan membawa obrolan pagi ke jawaban koding, dan konteks sekecil ini
   tidak punya ruang untuk ingatan yang tidak relevan.
4. **Konteks ditunjuk pengguna, bukan ditebak Apl.** Anda memilih folder sekali, lalu
   menunjuk berkas yang dibicarakan. Tidak ada pencarian otomatis di versi ini.
5. **Ingatan pendek: dua giliran terakhir.** Cukup untuk "jelaskan lebih detail", tanpa
   membawa isi berkas lama yang sudah tidak relevan.
6. **Boleh menulis langsung, dan selalu ada jalan kembali.** Setiap penulisan menyimpan
   versi sebelumnya dan meninggalkan Undo di percakapan.
7. **Tidak ada izin sistem baru dan tidak ada entitlement baru.**
   `ENABLE_USER_SELECTED_FILES: readwrite` sudah ada sejak sebelum sub-project ini.

---

## 3. Arsitektur

| Unit | Tanggung jawab | Murni? |
|---|---|---|
| `CodeWorkspace` | Folder pilihan sebagai security-scoped bookmark; membuka dan menutup akses | tidak |
| `WorkspaceListing` | Menyaring isi folder jadi daftar berkas yang masuk akal | **ya** |
| `ContextBudget` | Perkiraan token tiap berkas, sisa anggaran, menerima atau menolak | **ya** |
| `CodeAnswer` | Memeriksa jawaban model sebelum dipakai menulis | **ya** |
| `CodeInstructions` | Instructions sisi Code: ringkas, teknis, selalu menyebut nama berkas | **ya** |
| `CodeChatStore` | Percakapan sisi Code; kunci `UserDefaults` sendiri, otak sendiri | tidak |
| `FileWriter` | Menulis di dalam workspace, mencadangkan, menyediakan Undo | tidak |
| `CodeView` | Daftar berkas, percakapan, composer — memakai ulang `MessageRow` dan `Composer` | tidak |

**Aliran:** pilih folder → bookmark tersimpan → `WorkspaceListing` menyusun daftar → tunjuk
berkas → `ContextBudget` memutuskan muat atau tidak → isi berkas + pertanyaan + dua giliran
terakhir masuk ke otak kedua → jawaban → bila `CodeAnswer` meloloskannya, `FileWriter`
menulis dan meninggalkan chip Undo.

**Yang tidak berubah:** `ChatStore`, bubble quick ask, robot, shortcut global, mesin
proaktif. Sisi Code adalah ruang kedua, bukan perombakan.

---

## 4. Anggaran token

| Bagian | Jatah |
|---|---|
| Instructions sisi Code | ~300 token |
| Ingatan dua giliran terakhir | ~400 token |
| Ruang jawaban | ~700 token |
| **Berkas yang ditunjuk** | **~1.600 token ≈ 5,5 KB** |

Total ~3.000 dari ~4.096. Sisanya margin yang disengaja: perkiraan dihitung dari jumlah
karakter dibagi 3,5, dan tokenizer sebenarnya bisa meleset 20–30% pada kode.

**Yang tidak muat ditolak dengan jujur**, beserta sisa ruangnya — tidak pernah dipotong
diam-diam. Berkas tunggal yang lebih besar dari anggaran juga ditolak; versi ini tidak
memotong berkas jadi sebagian, karena potongan yang salah menghasilkan jawaban yang
percaya diri dan keliru.

**Ukurannya terlihat di layar** ("1.240 / 1.600 token") dan berubah saat berkas ditambah
atau dilepas.

---

## 5. Daftar berkas

`WorkspaceListing` melewati: berkas tersembunyi, `.git`, `build`, `DerivedData`,
`node_modules`, `Pods`, `.build`, berkas biner, dan apa pun di atas 200 KB. Yang tersisa
hanya berkas teks yang memang bisa dibicarakan, diurutkan menurut path relatif.

---

## 6. Menulis berkas

1. **Hanya berkas yang utuh ada di konteks yang boleh ditulis ulang.** Model yang hanya
   melihat separuh berkas tidak boleh menulis ulang berkas itu — hasilnya bukan suntingan,
   melainkan penghapusan bagian yang tidak pernah ia lihat. Berkas yang tidak ditunjuk di
   giliran itu ditolak.
2. **Berkas yang berubah di disk sejak dilampirkan ditolak.** Tanggal ubah dan ukuran
   dicatat saat dilampirkan dan diperiksa lagi tepat sebelum menulis; tanpa ini, suntingan
   yang baru saja dibuat di Xcode lenyap tanpa suara.
3. **Jawaban diperiksa lebih dulu** (`CodeAnswer`): tepat satu blok kode berpagar, tidak
   kosong, dan ukurannya antara setengah sampai dua kali berkas asli. Di luar itu tidak ada
   yang ditulis; bloknya tetap tampil sebagai jawaban biasa beserta alasannya.
4. **Cadangan disimpan di container app**, bukan di folder pengguna — Undo tetap bekerja
   setelah app ditutup, dan folder kerja tidak dikotori berkas `.bak`.
5. **Chip di percakapan**: `Foo.swift · 12 baris berubah · Undo`. Undo menolak bila berkas
   sudah berubah lagi sejak ditulis, dan mengatakannya.
6. **Tidak pernah keluar dari workspace.** Path dengan `..` atau yang menunjuk ke luar
   ditolak sebelum menyentuh disk.

---

## 7. Tampilan

Pemilih **Chat | Code** di atas kolom percakapan; stage dan robot tetap dipakai bersama.
Sisi Code menambah satu baris tipis: nama folder kerja, chip berkas yang ditunjuk (bisa
dilepas), tombol **+** yang membuka daftar berkas, dan pengukur token di ujung kanan.

Di bawah 820pt stage tetap meringkas jadi header seperti sekarang; baris berkas itu tidak
ikut menyusut, karena ia yang memberi tahu kapan jawaban mulai memburuk.

Keadaan kosong: ajakan memilih folder, satu tombol.

---

## 8. Pengujian

**Unit** — `WorkspaceListing` (yang disaring, yang dilewati, urutan), `ContextBudget`
(perkiraan, menerima, menolak, sisa, berkas tunggal kebesaran), `CodeAnswer` (satu blok,
blok kosong, dua blok, ukuran di luar rentang), `CodeInstructions` (muat di jatahnya), dan
`FileWriter` dengan berkas sungguhan di folder sementara: menulis hanya di dalam workspace,
menolak `..`, menolak berkas basi, membuat cadangan, Undo mengembalikan, Undo menolak bila
berkas berubah lagi.

**Manual** — pilih folder; lampirkan dua berkas dan perhatikan pengukurnya; lampirkan
berkas ketiga yang tidak muat dan pastikan penolakannya jelas; ajukan pertanyaan; minta
perubahan dan pastikan chip Undo muncul; tekan Undo; sunting berkas di Xcode lalu minta
perubahan lagi dan pastikan ditolak; tutup app, buka lagi, pastikan Undo masih bekerja.

**Regresi** — sisi Chat, bubble quick ask, shortcut, dan mesin proaktif tidak berubah
perilakunya.

---

## 9. Definition of Done

- [ ] Test unit §8 hijau; seluruh suite lama tetap hijau.
- [ ] `verify-boundaries` dan `verify-release` hijau.
- [ ] `DinoPocket.entitlements` tidak ada, dan `project.yml` tidak menambah entitlement.
- [ ] Pengukur token terlihat dan sesuai perkiraan yang dinyatakan.
- [ ] Undo terbukti bekerja setelah app ditutup dan dibuka lagi.
- [ ] Daftar manual §8 dijalankan, hasilnya dicatat di plan.

---

## 10. Yang sengaja tidak dikerjakan

- **Pencarian otomatis potongan relevan.** Dengan model sekecil ini, salah pilih potongan
  menghasilkan jawaban yang percaya diri dan salah.
- **Membaca berkas yang sedang terbuka di Xcode.** Butuh Source Editor Extension (hanya
  jalan saat dipanggil dari menu) atau AppleScript yang tidak lolos review.
- **Menjalankan perintah** (`git`, `swift build`). Proses anak mewarisi sandbox; hasilnya
  rapuh dan setengah jalan.
- **Tampilan diff.** Versi ini menulis utuh dan menyediakan Undo; diff adalah pekerjaan
  tersendiri yang lebih besar dari sisi Code itu sendiri.
- **Beberapa folder sekaligus.** Satu workspace pada satu waktu.

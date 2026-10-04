# Apl — Gambar dari Image Playground (Sub-project G) — Design Spec

- Tanggal: 2026-09-23
- Status: Disetujui
- Basis kode: branch `main` @ `f884625` (working tree bersih)
- Target: **macOS 26+**, distribusi **Mac App Store**, kategori tetap **Productivity**
- Melanjutkan: F (main suit). Tidak mengubah Chat, Code, shortcut, permainan, maupun mesin proaktif.

---

## 1. Konteks

Apl sampai hari ini hanya bisa menjawab dengan kalimat. Foundation Models — satu-satunya
otak yang dipakai sejak A — memang hanya teks; tidak ada API gambar untuk aplikasi pihak
ketiga di sana, dan tidak akan ada hanya karena kita menginginkannya.

Yang ada adalah **ImagePlayground**, framework terpisah yang membungkus generator gambar
on-device milik Apple. Sebuah probe pada 2026-09-22 membuktikan ia bekerja di Mac ini, di
dalam App Sandbox, **tanpa entitlement baru**: satu gambar 1536×1536 bergaya ilustrasi
selesai dalam 3,8 detik. Probe itu juga menemukan dua hal yang membentuk seluruh desain di
bawah:

1. **Generasi ditolak kalau app tidak sedang di depan** (`backgroundCreationForbidden`).
   Dua percobaan pertama gagal justru karena itu — sekali dari proses baris perintah,
   sekali dari app GUI yang memaksa mengaktifkan dirinya sendiri.
2. **`ImageCreator` — API tanpa UI — sudah deprecated di SDK 27**, dengan pesan resmi yang
   menyuruh pindah ke `ImagePlaygroundViewController` atau `imagePlaygroundSheet`.

Gaya yang tersedia di Mac ini: `animation`, `illustration`, `sketch`, `emoji`. Tidak ada
yang fotorealistis, dan itu bukan kekurangan yang bisa kita tutup.

---

## 2. Keputusan yang mengikat

1. **Sheet Apple adalah satu-satunya mesin.** `imagePlaygroundSheet` yang menangani
   generasi, pemilihan gaya, dan "coba lagi". Kita tidak memakai `ImageCreator`: membangun
   fitur baru di atas API yang sedang dipensiunkan adalah utang yang tanggal jatuh temponya
   sudah tertulis. Efek sampingnya menguntungkan — syarat "app harus di depan" terpenuhi
   dengan sendirinya, karena pengguna sendiri yang membuka sheet itu.
2. **Dua pintu masuk, satu permintaan.** **Mengetik** ("gambarkan kucing pakai topi")
   memberi konsep; **menu di composer** memberi dua baris — "Describe an image…" membuka
   sheet kosong, "Use a photo…" membuka panel berkas lebih dulu. Keduanya bertemu di
   `PictureRequest` yang sama.
3. **Hanya di jendela utama.** Balon robot dan bubble ⌥Space tidak ikut: sheet butuh
   jendela untuk ditempelkan, dan robot yang membuka panel Apple di atas pekerjaan orang
   adalah kejutan, bukan fitur.
4. **Gambar masuk percakapan dan bertahan**, tersimpan di container app, ikut hilang saat
   Erase All Data.
5. **Apl diam saat sheet dibatalkan.** Mengetik ajakan menggambar TIDAK langsung menaruh
   kalimat jawaban — berbeda dari "main suit" di F. Pesan Apl baru ada kalau gambarnya
   benar-benar ada; kalau tidak, satu-satunya jejak adalah kalimat yang diketik pengguna.
6. **Bytes disalin apa adanya**, tanpa dikompresi ulang. Menurunkan mutu barang yang baru
   saja dibuat pengguna, tanpa diminta, bukan hak kita.
7. **Tidak ada entitlement baru.** Panel berkas memakai `user-selected` yang sudah dipakai
   sisi Code sejak E. Kategori App Store tidak berubah.

---

## 3. Arsitektur

| Unit | Tanggung jawab | Murni? |
|---|---|---|
| `DrawCommand` | Mengenali ajakan menggambar **dan memotong konsepnya** dari kalimat; menolak yang mirip | **ya** |
| `PictureRequest` | Permintaan yang berjalan: konsep + URL foto sumber opsional | **ya** |
| `PictureAvailability` | Memutuskan "buka sheet" atau "jawab belum tersedia" | **ya** |
| `ImageStore` | Menyimpan PNG di container, menamai, memangkas, ikut terhapus | tidak |
| `ChatMessage.Attachment.picture(name:concept:)` | Fakta yang menempel di pesan | **ya** |
| `PictureBubble` | Menampilkan gambar di percakapan, dengan **Save** | tidak |

**Aliran:** ketik "gambarkan …" → `ChatStore` menangkapnya **lokal, tanpa menyentuh model**
(jalur ketiga sesudah reminder dan "main suit") → `pictureRequested(PictureRequest)` →
jendela utama menyalakan `imagePlaygroundSheet` dengan konsep terisi → pengguna memilih di
UI Apple → `onCompletion` memberi satu URL → `ImageStore` menyalinnya ke container → pesan
Apl berlampiran gambar masuk percakapan.

**Bentuk pesannya:** teks pesan Apl **kosong**; yang membawa arti adalah lampirannya.
`PictureBubble` menampilkan gambar dengan konsep sebagai keterangan kecil di bawahnya.
Apl tidak menuliskan kalimat pengantar seperti "Here's your image" — gambarnya sudah di
sana, dan mengulanginya dengan kata-kata hanya menambah baris yang harus dibaca.

**Varian sheet yang dipakai** (keduanya sudah dipastikan ada di SDK 27):
`imagePlaygroundSheet(isPresented:concept:sourceImage:onCompletion:onCancellation:)` untuk
jalur ketik, dan varian `sourceImageURL:` untuk jalur foto.

Urutan pemeriksaan di `ChatStore.send` menjadi: reminder → "main suit" → menggambar →
model. Ajakan menggambar duduk **sesudah** reminder dengan alasan yang sama seperti F:
"remind me to draw the logo at 4pm" adalah pengingat.

---

## 4. Penyimpanan

- **Tempat:** `Application Support/Apl/Images/`, bersebelahan dengan `Apl/CodeBackups`
  milik E. Di dalam container app, bukan folder pengguna.
- **Nama berkas:** UUID. Konsep yang diketik bisa berisi apa saja, dan menuliskannya jadi
  nama berkas berarti menaruh isi percakapan ke sistem berkas tanpa alasan.
- **Batas — folder adalah fungsi dari percakapan.** Setiap kali gambar baru disimpan,
  berkas yang **tidak lagi dirujuk pesan mana pun** dibuang. `ChatStore` hanya menyimpan 20
  pesan terakhir, jadi gambar yang sudah tergulung keluar memang tidak punya cara untuk
  ditampilkan lagi. Di atasnya ada pagar keras **20 gambar**, menyisakan yang terbaru.
  Terburuknya sekitar 80 MB.
- **Berkas yang hilang bukan kesalahan.** Pesan menyimpan nama, bukan gambarnya. Kalau
  berkasnya tidak ada lagi, gelembungnya menampilkan satu baris tenang
  "Image no longer stored".
- **Save:** panel simpan biasa dengan nama awal `Apl image <tanggal>.png`. Tidak ada
  seret-dan-lepas di versi ini.
- **Erase All Data:** `ImageStore` mendaftar `LocallyErasable` dan memusnahkan foldernya
  sendiri — pola yang sama dengan setiap penyimpanan lain di app ini.

---

## 5. Ketersediaan dan kesalahan

- **Apple Intelligence mati / Image Playground belum siap.** Diperiksa dengan
  `ImagePlaygroundViewController.isAvailable` **sebelum** apa pun dibuka. Kalimat ketiknya
  tetap dikenali lokal dan dijawab satu baris — "Image Playground isn't available yet" —
  dengan jalan ke System Settings yang sudah dipakai `AIUnavailableBanner` sejak B. Menu di
  composer **dinonaktifkan, bukan disembunyikan**, beserta alasannya. Unduhan modelnya
  sendiri tidak kita bangun ulang; sheet Apple punya progresnya.
- **Sheet dibatalkan.** Tidak ada yang ditambahkan (keputusan §2 #5).
- **Foto yang tidak bisa dipakai.** Panel dibatasi `UTType.image`. Penolakan yang lebih
  halus — wajah terlalu kecil, gambar tidak didukung — dilaporkan UI Apple, dan kita tidak
  menirunya. Berkas yang tidak terbaca sama sekali dikatakan sebelum sheet dibuka.
- **Penyalinan gagal.** URL dari Apple hidup di tempat sementara. Kalau menyalin gagal,
  Apl mengatakannya: "I couldn't keep that image." Tidak ada lampiran rusak yang masuk
  diam-diam.
- **Permintaan kedua saat sheet terbuka.** Diabaikan.
- **VoiceOver.** Lampiran menyimpan konsep yang diminta dan membacakannya sebagai
  "Image of ⟨konsep⟩", lalu diumumkan berprioritas sedang lewat `AnswerAnnouncement`.

---

## 6. Pengujian

**Unit** — `DrawCommand` mengenali varian ("gambarkan X", "gambar X", "buatkan gambar X",
"draw a X") dan **memotong konsepnya** sebagai string persis; menolak dua kelompok:
`"remind me to draw the logo at 4pm"` yang harus tetap jadi pengingat, dan
`"how do I draw a circle in SwiftUI?"` yang harus tetap jadi pertanyaan ke model — kata
"draw" terlalu umum di percakapan tentang koding untuk dipercaya begitu saja.
`ImageStore` menyimpan, memangkas yang tak dirujuk, menegakkan pagar 20, mengosongkan diri,
dan mengembalikan `nil` untuk berkas yang hilang — seluruhnya di direktori sementara.
`ChatMessage` tetap membaca percakapan yang tersimpan sebelum G, dan lampiran gambar
bolak-balik utuh. `PictureAvailability` diuji tanpa framework sama sekali.

**Test yang paling menentukan:** `ChatStore(brain: nil)` menerima "gambarkan kucing" dan
tetap memicu permintaan gambar dengan konsep yang benar, tanpa notice dan tanpa stream.

**Manual** — sheet terbuka dengan konsep terisi; menu dua baris; foto terpakai sebagai
dasar; hasil bertahan setelah app ditutup; Save menulis berkas; batal meninggalkan
percakapan bersih; Erase All Data mengosongkan folder; VoiceOver membaca label gambar.
Satu item milik pemiliknya: mematikan Apple Intelligence untuk melihat kalimat dan menu
nonaktifnya — pengaturan sistem tidak disentuh dari sini.

---

## 7. Definition of Done

- [x] Test unit §6 hijau; seluruh suite lama tetap hijau.
- [x] Ajakan menggambar tidak pernah sampai ke model.
- [x] `project.yml` tidak menambah entitlement; kategori tidak berubah.
- [ ] Folder `Images/` ikut hilang saat Erase All Data.
- [x] Percakapan yang tersimpan sebelum G tetap terbaca.
- [ ] Daftar manual §6 dijalankan, hasilnya dicatat di plan.

---

## 8. Yang sengaja tidak dikerjakan

- **`ImageCreator`** dan segala bentuk generasi tanpa UI Apple — deprecated di SDK 27, dan
  ditolak sistem saat app tidak di depan.
- **Gambar dari balon robot atau bubble ⌥Space** — sheet butuh jendela.
- **Genmoji dan `NSAdaptiveImageGlyph`** — jalur berbeda, dengan penyimpanan dan
  penyuntingan teks yang berbeda pula.
- **Seret-dan-lepas, galeri, dan penyuntingan gambar.** Apl bukan aplikasi foto.
- **Menjadikan gambar sebagai wajah robot.** Karakternya aset 3D dengan lima ekspresi yang
  punya arti; menggantinya dengan gambar acak membuang arti itu.

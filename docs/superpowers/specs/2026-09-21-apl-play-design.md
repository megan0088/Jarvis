# Apl — Main Suit dengan Robot (Sub-project F) — Design Spec

- Tanggal: 2026-09-21
- Status: Disetujui
- Basis kode: branch `main` @ `b006638` (working tree bersih)
- Target: **macOS 26+**, distribusi **Mac App Store**, kategori tetap **Productivity**
- Melanjutkan: E (sisi Code). Tidak mengubah Chat, Code, shortcut, maupun mesin proaktif.

---

## 1. Konteks

Robot di desktop punya lima ekspresi yang dibangun di sub-project B, dan sampai hari ini
semuanya hanya dipakai untuk satu hal: melaporkan keadaan mesin dan percakapan. Permintaan
pemilik produk — "mini-game, robotnya yang diajak main" — memberi ekspresi itu alasan kedua
untuk ada, tanpa menambah satu aset pun.

Permainannya **suit**: batu, gunting, kertas. Dipilih karena ia satu giliran, tidak butuh
animasi baru, tidak butuh papan, dan hasilnya bisa disampaikan seluruhnya lewat wajah.

---

## 2. Keputusan yang mengikat

1. **Model tidak pernah dilibatkan.** Lemparan robot diacak secara lokal; ajakan main
   ditangkap `ChatStore` seperti jalur reminder, tanpa menyentuh Foundation Models.
   Konsekuensinya permainan tetap jalan saat Apple Intelligence mati.
2. **Robot memilih lebih dulu, dan pilihannya dikunci saat ronde dibuat** — sebelum
   pengguna memilih. Kalau diacak sesudahnya, tidak ada cara membuktikan ia tidak curang,
   bahkan bagi yang menulis kodenya.
3. **Dipicu dengan mengetik** ("main suit"), bukan tombol permanen di panggung dan bukan
   ajakan proaktif. Panggung adalah ruang karakter, bukan toolbar; dan C2 hanya menyapa
   soal hal yang sedang terjadi — ajakan main bukan salah satunya.
4. **Dimainkan di balon yang ditambatkan ke robot**, dan **balon ini boleh menerima fokus
   keyboard** — berbeda dari balon sapaan C2. Alasannya konsisten: sapaan datang tanpa
   diminta dan tidak boleh mencuri ketikan; permainan ini dimulai pengguna sendiri.
5. **Tidak ada kalimat acak.** Robot tidak berkomentar; hasilnya disampaikan wajahnya dan
   satu baris teks yang pasti. Sapaan acak dibuang di C1 karena tidak punya aturan.
6. **Tanpa robot, permainan tetap bisa dimainkan** di dalam chat sebagai pesan biasa.
7. **Tidak ada entitlement baru, tidak ada aset baru, kategori App Store tidak berubah.**

---

## 3. Arsitektur

| Unit | Tanggung jawab | Murni? |
|---|---|---|
| `Throw` | Batu, gunting, kertas — beserta namanya di layar | **ya** |
| `RoundOutcome` | Siapa menang, dari dua lemparan | **ya** |
| `PlayCommand` | Mengenali ajakan main dari kalimat biasa, dan menolak yang mirip | **ya** |
| `SuitRound` | Satu ronde; lemparan robot dikunci saat dibuat | **ya** |
| `GameScore` | Tally menang/kalah/seri, bertahan, ikut terhapus | tidak |
| `AnchoredPanel` | Bagian bersama balon: penempatan, jangkar robot, tahan langkah | tidak |
| `PlayPanelController` | Balon permainan; **bisa** jadi key window | tidak |
| `SuitBalloon` | Tampilannya | tidak |

**Perapian yang ikut masuk:** `NudgePanelController` (C2) dan panel permainan ini adalah
balon yang sama — penempatan lewat `BubblePlacement`, robot berhenti melangkah selama
tampil, menghilang saat ditutup. Bagian bersamanya ditarik ke `AnchoredPanel` alih-alih
disalin; dua salinan yang nyaris sama adalah cara paling pasti membuat perbaikan di satu
tempat tidak sampai ke tempat lain.

**Aliran:** ketik "main suit" → `ChatStore` menangkap secara lokal → `SuitRound` dibuat
(lemparan robot terkunci) → balon muncul di samping robot → pengguna memilih (klik atau
1/2/3) → robot `.thinking` ~0,75 detik → hasil terungkap, ekspresi berubah, skor diperbarui
→ **Again** atau **Done**.

---

## 4. Satu ronde

- Balon: satu baris ajakan, tiga tombol, skor kecil (`You 3 · Apl 2`).
- Setelah memilih: wajah `.thinking` ~0,75 detik, lalu hasil.
- Ekspresi hasil: robot **bersorak** saat menang, **murung** saat kalah, `.idle` saat seri.
- Setelah terungkap: **Again** (Return) dan **Done** (Esc).
- Keyboard: **1 / 2 / 3** memilih, **Return** main lagi, **Esc** selesai.
- Reduce Motion menghilangkan animasi terungkapnya; jeda berpikir tetap — itu waktu, bukan
  gerak.
- Hasil diumumkan ke VoiceOver berprioritas sedang; permainan ini diminta pengguna.

---

## 5. Penyimpanan

Satu kunci, `game.suit.score`, berisi tiga angka. Ditulis dengan `synchronize()` dan
terdaftar sebagai `LocallyErasable` — seperti seluruh penyimpanan lain di app ini.

---

## 6. Pengujian

**Unit** — `RoundOutcome` pada **kesembilan** kombinasi; `PlayCommand` mengenali varian
("main suit", "ayo suit", "rock paper scissors") dan **menolak yang mirip**, khususnya
"remind me to play football at 3pm" yang harus tetap jadi reminder; `SuitRound` membuktikan
lemparan robot terkunci saat dibuat; `GameScore` bertahan lintas peluncuran dan terhapus.

**Test yang paling menentukan:** satu ronde penuh berjalan dengan `ChatStore(brain: nil)` —
kalau permainan pernah menyentuh model, test itu yang memberi tahu.

**Manual** — ketik "main suit"; balon muncul di samping robot; 1/2/3 dan klik sama-sama
bekerja; ekspresi berubah sesuai hasil; Again dan Esc; skor bertahan setelah app ditutup;
Hide Buddy lalu main lagi → rondenya berlangsung di dalam chat.

---

## 7. Definition of Done

- [ ] Test unit §6 hijau; seluruh suite lama tetap hijau.
- [ ] Permainan berjalan penuh tanpa Apple Intelligence.
- [ ] `project.yml` tidak menambah entitlement; tidak ada aset baru.
- [ ] `game.suit.score` ikut hilang saat Erase All Data.
- [ ] `NudgePanelController` memakai `AnchoredPanel` yang sama, bukan salinan.
- [ ] Daftar manual §6 dijalankan, hasilnya dicatat di plan.

---

## 8. Penyesuaian setelah tinjauan rencana

Empat hal ketahuan saat rencananya ditinjau sebelum satu baris kode ditulis. Dua di
antaranya mengubah keputusan produk, bukan sekadar urutan kerja.

1. **Ekspresi kalah butuh case baru.** `CharacterBehavior` hanya punya `idle`, `greet`,
   `sleepy`, `celebrate`, `thinking` — dan yang memakai berkas `RobotSad` adalah `.sleepy`,
   yang juga berarti baterai menipis. Robot yang tampak **mengantuk** setiap kali pengguna
   menang adalah salah pesan. Ditambahkan `case sad`, dipetakan ke aset `RobotSad` yang
   sudah ada: tidak ada aset baru, hanya arti yang dipisahkan dari sebabnya.
2. **Robot desktop belum punya pintu untuk mengganti ekspresi.** `BuddyCharacterHost`
   menghitungnya murni dari `SystemMood`. Ditambahkan override yang **hanya berlaku selama
   ronde** dan menang atas mood mesin; begitu ronde selesai, mood kembali memegang kendali.
   Panas dan baterai tetap terlihat — hanya tertunda beberapa detik, dan itu harga yang
   wajar untuk permainan yang diminta pengguna.
3. **Jeda berpikir adalah milik `SuitGame`, bukan view.** Kalau ia tinggal di tampilan, ia
   tidak bisa diuji sama sekali. Jam-nya disuntikkan, jadi "robot berpikir dulu, baru
   mengungkap" bisa dibuktikan tanpa menunggu.
4. **Balon permainan ikut membungkam sapaan proaktif.** `QuietSignals` C2 tidak tahu
   apa-apa soal balon ini, jadi tanpa satu bendera tambahan Apl akan menyela permainannya
   sendiri.
5. **Tempat bermain adalah keputusan yang bisa diuji**, bukan cabang `if` di dalam view:
   `PlayVenue.decide(buddyIsRunning:)` memilih balon atau chat.

---

## 9. Yang sengaja tidak dikerjakan

- **Papan peringkat, lawan daring, taruhan.**
- **Komentar robot yang digenerate model** — lambat, boros konteks, dan tidak punya aturan.
- **Suara.** Pembaca C2 hanya untuk sapaan; suara permainan keputusan tersendiri.
- **Permainan kedua.** Satu permainan yang rapi lebih baik daripada tiga yang setengah.

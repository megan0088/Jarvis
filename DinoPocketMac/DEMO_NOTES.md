# Jarvis Demo Notes

## Tombol Trigger Buddy Mode

Pada versi macOS, Buddy Mode sekarang memiliki tombol demo untuk memunculkan pop-up reminder secara manual:

- `Minum`: memunculkan pengingat hidrasi.
- `Stretch`: memunculkan pengingat stretching.
- `Makan`: memunculkan pengingat makan.
- `Stop Buddy`: menutup Buddy Mode.

Alur demo yang disarankan:

1. Jalankan aplikasi macOS.
2. Aktifkan `Buddy Mode`.
3. Tekan salah satu tombol trigger di pojok kanan atas.
4. Pop-up akan muncul di dekat karakter Jarvis.
5. Tekan `Sudah` untuk menambah goal harian, atau `Belum` untuk snooze 10 menit.

## Penjelasan Teknologi yang Digunakan

### Swift sebagai bahasa pemrograman utama

Swift digunakan sebagai fondasi utama aplikasi Jarvis karena aman, modern, dan terintegrasi penuh dengan ekosistem Apple. Dengan Swift, logika seperti status pet, screen time, reminder, dan penyimpanan data dapat ditulis dengan struktur yang rapi dan mudah dirawat.

### SwiftUI untuk membangun antarmuka aplikasi

SwiftUI digunakan untuk membuat tampilan utama aplikasi di iOS dan macOS. Pendekatan deklaratif SwiftUI memudahkan pembuatan layout responsif, dashboard statistik, tombol interaksi, dan panel wellness tanpa harus menulis UI secara terpisah untuk setiap perubahan kecil.

### SpriteKit untuk animasi karakter dan Buddy Mode

SpriteKit dipakai untuk membangun karakter Jarvis, animasi idle, ekspresi, efek visual, dan interaksi Buddy Mode. Framework ini cocok untuk kebutuhan karakter 2D yang bergerak di layar dan memunculkan prompt reminder secara visual.

### ActivityKit untuk fitur Live Activity di iOS

ActivityKit digunakan pada versi iOS untuk menampilkan Live Activity. Fitur ini memungkinkan status Jarvis atau aktivitas tertentu ditampilkan secara ringkas dan real-time di area sistem iPhone, sehingga interaksi tidak selalu harus dibuka dari aplikasi utama.

### AppKit untuk fitur khusus macOS seperti floating desktop window

AppKit digunakan untuk kebutuhan yang spesifik di macOS, terutama saat Buddy Mode berjalan sebagai jendela transparan yang melayang di desktop. Dengan AppKit, Jarvis bisa tampil di atas layar kerja tanpa mengubah struktur utama aplikasi SwiftUI.

### UserDefaults dan iCloud Key-Value Store untuk penyimpanan data ringan

UserDefaults digunakan untuk menyimpan data ringan secara lokal, seperti mood pet, level energi, progress goal harian, riwayat reminder, dan screen time. iCloud Key-Value Store dipakai untuk sinkronisasi sederhana, sehingga data penting tetap bisa dipertahankan dan dibaca lintas perangkat Apple tanpa memerlukan backend khusus.

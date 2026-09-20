# Apl D — Siap Submit — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Repo, materi listing, dan screenshot siap diunggah ke App Store Connect — tanpa
ada yang diunggah oleh siapa pun selain pemilik produk.

**Architecture:** Tidak ada kode aplikasi baru. Yang berubah: konfigurasi build, berkas
mati yang dihapus, skrip pemeriksa yang diperketat, dokumen listing, dan empat gambar.

**Tech Stack:** XcodeGen, `xcodebuild archive`, `plutil`, Swift (alat penyusun screenshot),
`screencapture`.

**Spec:** `docs/superpowers/specs/2026-09-20-apl-release-design.md`

## Global Constraints

- **Tidak ada yang diunggah, ditandatangani dengan Apple ID, atau di-submit.** Archive
  dibangun dan diperiksa secara lokal; sisanya milik pemilik produk (spec §2 #3).
- **Jangan mengubah pengaturan sistem macOS** dan jangan menekan dialog izin atas nama
  pengguna.
- **Screenshot tidak boleh memuat app pihak ketiga** (spec §2 #5).
- **Percakapan pengguna tidak dihapus** demi merapikan gambar (spec §5).
- `Legacy/` dan `ContentView*.swift` **tidak** disentuh (spec §2 #6).
- Setiap commit diakhiri `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.

## File Structure

**Diubah:** `project.yml` (kategori, deployment target, excludes), `scripts/verify-release.sh`
(tiga pemeriksaan baru), `README.md`.

**Dihapus:** `JarvisWidget/`, `JarvisUITests/`, `JarvisIOS.entitlements`,
`DinoPocketMac/DinoPocket.entitlements`.

**Dibuat:** `docs/appstore/2026-09-20-listing.md`,
`docs/appstore/screenshots/01-conversation.png` … `04-settings.png`.

---

### Task 1: Pemeriksa dulu, konfigurasi kemudian

**Files:**
- Modify: `scripts/verify-release.sh`, `project.yml`

**Interfaces:**
- Produces: tiga pemeriksaan baru di `verify-release.sh`; `project.yml` dengan kategori
  `productivity` dan `deploymentTarget.macOS: "26.0"`.

- [ ] **Step 1: Perketat pemeriksanya lebih dulu**

Di `scripts/verify-release.sh`, ganti baris kategori yang longgar:

```bash
check Release INFOPLIST_KEY_LSApplicationCategoryType "public.app-category.*" "App Store butuh kategori"
```

menjadi dua pemeriksaan yang mengikat:

```bash
# Kategori PERSIS, bukan sekadar "ada kategori apa pun": healthcare-fitness
# adalah peninggalan wellness tracker yang dibuang di sub-project A, dan ia
# lolos pola longgar tanpa suara (spec D §3).
check Release INFOPLIST_KEY_LSApplicationCategoryType "public.app-category.productivity" "kategori salah rak"
# Batas OS yang naik diam-diam mengusir pemasang, termasuk App Review.
check Release MACOSX_DEPLOYMENT_TARGET "26.0" "lebih tinggi dari API tertinggi yang dipakai"
```

Lalu tambahkan pemeriksaan berkas entitlements yang tergeletak, setelah blok "Tanpa akun":

```bash
echo "Tanpa entitlements yatim:"
orphans=""
while IFS= read -r file; do
  [ -z "$file" ] && continue
  if ! grep -q "$(basename "$file")" project.yml 2>/dev/null; then
    orphans="$orphans $file"
  fi
done <<< "$(find . -name '*.entitlements' -not -path './.git/*' 2>/dev/null)"
if [ -z "$orphans" ]; then
  echo "  ✅ tidak ada .entitlements yang tidak dirujuk"
else
  echo "  ❌ .entitlements tidak dirujuk siapa pun:$orphans"
  echo "     berkas mati semacam ini menunggu suatu hari tersambung dan meminta"
  echo "     capability yang tidak pernah dipakai app ini"
  fail=1
fi
```

- [ ] **Step 2: Jalankan dan pastikan MERAH**

Run: `./scripts/verify-release.sh; echo "exit=$?"`
Expected: gagal pada tiga hal — kategori `healthcare-fitness`, deployment target `26.2`,
dan dua berkas `.entitlements` yatim.

- [ ] **Step 3: Perbaiki konfigurasinya**

Di `project.yml`:

```yaml
  deploymentTarget:
    macOS: "26.0"
```

```yaml
        # Kategori App Store. Productivity: app ini menjawab dan mengingatkan.
        # Sebelumnya healthcare-fitness, peninggalan wellness tracker yang
        # dibuang di sub-project A (spec D §2 #1).
        INFOPLIST_KEY_LSApplicationCategoryType: public.app-category.productivity
```

- [ ] **Step 4: Jalankan lagi**

Run: `xcodegen generate && ./scripts/verify-release.sh; echo "exit=$?"`
Expected: kategori dan deployment target hijau; entitlements yatim **masih merah** —
dibereskan Task 2.

- [ ] **Step 5: Commit**

```bash
git add project.yml scripts/verify-release.sh
git commit -m "$(cat <<'EOF'
fix(d): kategori Productivity dan batas OS 26.0, dijaga pemeriksa

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Membuang yang mati

**Files:**
- Delete: `JarvisWidget/`, `JarvisUITests/`, `JarvisIOS.entitlements`,
  `DinoPocketMac/DinoPocket.entitlements`
- Modify: `project.yml` (hapus baris `excludes` untuk entitlements)

- [ ] **Step 1: Pastikan tidak ada yang merujuknya**

Run: `grep -rn "JarvisWidget\|JarvisUITests\|JarvisIOS\|DinoPocket.entitlements" project.yml scripts README.md 2>/dev/null`
Expected: hanya baris `excludes` di `project.yml` untuk `DinoPocket.entitlements`.

- [ ] **Step 2: Hapus**

```bash
git rm -r --quiet JarvisWidget JarvisUITests JarvisIOS.entitlements DinoPocketMac/DinoPocket.entitlements
```

Lalu hapus baris ini dari `project.yml`:

```yaml
          - "DinoPocket.entitlements"
```

- [ ] **Step 3: Build, suite, dan pemeriksa**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' 2>&1 | grep -E "error:|Test run with|TEST"`
Expected: 225 test lulus.

Run: `./scripts/verify-boundaries.sh && ./scripts/verify-release.sh; echo "exit=$?"`
Expected: keduanya hijau, termasuk pemeriksaan entitlements yatim.

- [ ] **Step 4: Commit**

```bash
git add -A project.yml
git commit -m "$(cat <<'EOF'
chore(d): buang target dan entitlements yang tidak dirujuk siapa pun

DinoPocket.entitlements tidak pernah menandatangani apa pun — sandbox
datang dari ENABLE_APP_SANDBOX — jadi app group dan iCloud KV di dalamnya
tidak pernah berlaku. Berkas semacam itu menunggu suatu hari tersambung.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: README berhenti menjanjikan wellness

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Ganti paragraf pembuka**

```markdown
# Apl

Asisten desktop on-device untuk Mac: karakter 3D yang hidup di desktop, chat yang berjalan
di Mac sendiri lewat Apple Intelligence, dan pengingat yang dibuat dengan kalimat biasa.
Satu tombol memanggilnya dari app mana pun, dan sesekali ia menyapa lebih dulu — dengan
kuota, dan hanya soal hal yang memang sedang terjadi.

Seluruhnya lokal: tidak ada akun, tidak ada server, tidak ada data yang keluar dari Mac.
```

Hapus frasa "pengingat kebiasaan sehat" di mana pun ia muncul; pelacakan kebiasaan sudah
dibuang di sub-project A.

- [ ] **Step 2: Periksa tidak ada sisa janji lama**

Run: `grep -rniE "wellness|kebiasaan sehat|habit" README.md`
Expected: tidak ada hasil.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "$(cat <<'EOF'
docs(d): README menjanjikan yang app-nya lakukan hari ini

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Materi listing

**Files:**
- Create: `docs/appstore/2026-09-20-listing.md`

- [ ] **Step 1: Tulis berkasnya**

````markdown
# Apl — Materi App Store Connect

Tanggal: 2026-09-20 · Versi 1.0 (1) · Spec: `docs/superpowers/specs/2026-09-20-apl-release-design.md`

## Harus datang dari pemilik produk

Tidak bisa dikarang, dan App Store Connect mewajibkannya:

| Bidang | Catatan |
|---|---|
| Privacy Policy URL | Wajib untuk SEMUA app, termasuk yang tidak mengumpulkan apa pun |
| Support URL | Wajib; halaman GitHub sudah cukup |
| Ketersediaan nama "Apl" | Hanya App Store Connect yang tahu apakah sudah dipakai |
| Harga | Gratis atau berbayar |

## Bidang toko

- **Name:** Apl
- **Subtitle:** On-device desktop companion
- **Category:** Productivity
- **Age rating:** 4+
- **App Privacy:** Data Not Collected
- **Keywords:** assistant,reminder,desktop,companion,on-device,apple intelligence,chat,robot
- **Copyright:** © 2026 Muhamad Ega Nugraha

## Description

Apl is a small companion that lives on your desktop. Ask it something and it answers right
there, beside the character — no window to hunt for, no account to create, and nothing
leaving your Mac.

**Ask from anywhere.** Press ⌥Space in any app and a bubble opens next to the character,
ready to type. Answers appear in the same conversation you see in the main window.

**Reminders in plain words.** "Remind me to stretch at 3 PM" is all it takes. Apl schedules
it, shows it in Up next, and lets you undo it with one click.

**A character, not a chat box.** The robot stands on your desktop, changes expression while
it thinks, and steps aside when you work. Click it to talk.

**It speaks up rarely, and only about what is happening.** Five minutes before a reminder,
or when this Mac runs hot or the battery gets low. Nothing else, with a daily limit — and
you can switch the voice on if you want it read aloud.

**Everything stays here.** Chat runs on Apple Intelligence, on this Mac. No account, no
server, no analytics.

Chat requires Apple Intelligence, which needs an Apple silicon Mac with the feature turned
on in System Settings. Reminders and the character work without it.

## Promotional text

Ask from any app with one key. Answers, reminders, and a character that lives on your
desktop — all on this Mac.

## Review notes

Thank you for reviewing Apl.

1. **Chat requires Apple Intelligence, and it is likely off on the review Mac.** The app
   says so on screen, with a link to System Settings, and keeps working: reminders are
   created and scheduled without any model. Nothing is broken if the banner appears — that
   is the designed state for a Mac without Apple Intelligence.
2. **There is no account and no server.** No sign-in exists, so there are no test
   credentials to provide. All data stays in local storage on the device.
3. **Two behaviors worth explaining.** The character floats above other windows in an
   `NSPanel`; the global shortcut (⌥Space, configurable, can be turned off) is registered
   with `RegisterEventHotKey`. Neither uses Accessibility permission nor screen recording,
   and the app asks for no permission beyond notifications.

To try the core flow without Apple Intelligence: type "remind me to stretch in 2 minutes"
and the reminder appears in Up next with an Undo link.

## App Privacy — jawaban

- Does this app collect data? **No.**
- `PrivacyInfo.xcprivacy` menyatakan `NSPrivacyTracking: false`, tanpa domain pelacakan,
  tanpa tipe data yang dikumpulkan, dan satu alasan akses API: `UserDefaults` (CA92.1).
````

- [ ] **Step 2: Commit**

```bash
git add docs/appstore/2026-09-20-listing.md
git commit -m "$(cat <<'EOF'
docs(d): materi App Store Connect siap tempel

Review notes menjelaskan tiga hal yang akan membingungkan reviewer bila
didiamkan — terutama bahwa banner "butuh Apple Intelligence" adalah
keadaan yang dirancang, bukan app yang rusak.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Alat penyusun screenshot

**Files:**
- Create: alat `compose` di scratchpad (bukan di repo — ia alat, bukan produk)

**Interfaces:**
- Produces: `compose <out.png> <W> <H> <#hex> [<layer.png> <x> <y>]...`

- [ ] **Step 1: Tulis alatnya**

```swift
import AppKit
// usage: compose out.png W H #rrggbb [layer.png x y]...
let args = CommandLine.arguments
let out = args[1]
let w = Int(args[2])!, h = Int(args[3])!
let hex = args[4].dropFirst()
let n = Int(hex, radix: 16)!
let bg = NSColor(red: CGFloat((n >> 16) & 255) / 255, green: CGFloat((n >> 8) & 255) / 255,
                 blue: CGFloat(n & 255) / 255, alpha: 1)

let image = NSImage(size: NSSize(width: w, height: h))
image.lockFocus()
bg.setFill()
NSRect(x: 0, y: 0, width: w, height: h).fill()
var i = 5
while i + 2 < args.count {
    guard let layer = NSImage(contentsOfFile: args[i]) else { i += 3; continue }
    let x = Double(args[i + 1])!, y = Double(args[i + 2])!
    // y dihitung dari ATAS supaya cocok dengan koordinat screencapture.
    let size = layer.size
    layer.draw(at: NSPoint(x: x, y: Double(h) - y - size.height),
               from: .zero, operation: .sourceOver, fraction: 1)
    i += 3
}
image.unlockFocus()

let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("\(out) \(w)x\(h)")
```

- [ ] **Step 2: Bangun dan uji dengan satu lapisan**

Run: `swiftc -O compose.swift -o compose && ./compose /tmp/test.png 1280 800 "#1c1c1e"`
Expected: berkas 1280×800 berwarna polos.

---

### Task 6: Empat screenshot

**Files:**
- Create: `docs/appstore/screenshots/01-conversation.png`, `02-quick-ask.png`,
  `03-greeting.png`, `04-settings.png`

- [ ] **Step 1: Siapkan isi yang pantas dipotret**

Jalankan app, lalu lewat composer kirim dua pesan yang menunjukkan kegunaannya (misalnya
satu pertanyaan singkat dan satu "remind me to stretch at …" agar chip reminder muncul).
**Jangan** menghapus percakapan yang sudah ada.

- [ ] **Step 2: Potret tiap jendela**

```bash
./winid Apl                                   # cari id jendela
screencapture -x -o -l <id-jendela-utama> main.png
screencapture -x -o -l <id-bubble> bubble.png
screencapture -x -o -l <id-overlay> robot.png   # latar transparan
screencapture -x -o -l <id-settings> settings.png
```

Untuk balon sapaan: buat satu reminder ~6 menit ke depan, lalu tunggu balon muncul dengan
loop yang mendeteksi panel bertinggi 20–60pt dan memotretnya seketika (umurnya 8 detik).

- [ ] **Step 3: Susun di atas latar polos**

```bash
./compose 01-conversation.png 1280 800 "#1c1c1e" main.png 140 60
./compose 02-quick-ask.png    1280 800 "#1c1c1e" robot-crop.png 380 380 bubble.png 640 330
./compose 03-greeting.png     1280 800 "#1c1c1e" robot-crop.png 380 380 balloon.png 640 380
./compose 04-settings.png     1280 800 "#1c1c1e" settings.png 400 175
```

Potong `robot.png` (selebar layar, sebagian besar transparan) ke kotak karakter dengan
`sips --cropToHeightWidth` sebelum disusun.

- [ ] **Step 4: Periksa tiap gambar**

Buka keempatnya dan pastikan: ukurannya 1280×800, **tidak ada jendela app lain**, tidak ada
nama orang atau isi pribadi, dan teksnya terbaca pada ukuran itu.

Run: `sips -g pixelWidth -g pixelHeight docs/appstore/screenshots/*.png`
Expected: keempatnya 1280×800.

- [ ] **Step 5: Commit**

```bash
git add docs/appstore/screenshots
git commit -m "$(cat <<'EOF'
docs(d): empat screenshot 1280x800, tanpa app pihak ketiga

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Archive dan pemeriksaan Info.plist

**Files:**
- Tidak ada berkas repo yang berubah; hasilnya dicatat di plan ini.

- [ ] **Step 1: Bangun archive Release**

Run:
```bash
xcodebuild archive -project DinoPocket.xcodeproj -scheme DinoPocketMac \
  -configuration Release -archivePath build/Apl.xcarchive 2>&1 | tail -5
```
Expected: `ARCHIVE SUCCEEDED`.

- [ ] **Step 2: Periksa Info.plist di dalam archive**

Run:
```bash
P=build/Apl.xcarchive/Products/Applications/Apl.app/Contents/Info.plist
for k in CFBundleIdentifier CFBundleName CFBundleDisplayName CFBundleShortVersionString \
         CFBundleVersion LSApplicationCategoryType LSMinimumSystemVersion \
         NSHumanReadableCopyright ITSAppUsesNonExemptEncryption CFBundleIconName; do
  printf "%-32s %s\n" "$k" "$(plutil -extract "$k" raw -o - "$P" 2>/dev/null || echo '❌ TIDAK ADA')"
done
```
Expected: `com.ega.apl`, `Apl`, `Apl`, `1.0`, `1`, `public.app-category.productivity`,
`26.0`, hak cipta terisi, `false`, dan nama ikon terisi.

- [ ] **Step 3: Pastikan ikon benar-benar terbundel**

Run: `ls build/Apl.xcarchive/Products/Applications/Apl.app/Contents/Resources/*.icns`
Expected: satu berkas `.icns`.

- [ ] **Step 4: Catat hasilnya**

Tambahkan "Catatan eksekusi" di plan ini berisi keluaran Step 2 apa adanya, lalu tandai
DoD di spec §7.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/plans/2026-09-20-apl-release.md docs/superpowers/specs/2026-09-20-apl-release-design.md
git commit -m "$(cat <<'EOF'
docs(d): catat hasil archive dan pemeriksaan Info.plist

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Catatan eksekusi

Dijalankan inline, 2026-09-20. Tujuh tugas selesai, **225 test di 43 suite** hijau,
`verify-boundaries` dan `verify-release` hijau dengan tiga aturan baru.

### Archive dan Info.plist

`xcodebuild archive` → **ARCHIVE SUCCEEDED**. Isi `Info.plist` di dalam archive:

| Kunci | Nilai |
|---|---|
| `CFBundleIdentifier` | `com.ega.apl` |
| `CFBundleName` / `CFBundleDisplayName` | `Apl` / `Apl` |
| `CFBundleShortVersionString` / `CFBundleVersion` | `1.0` / `1` |
| `LSApplicationCategoryType` | `public.app-category.productivity` |
| `LSMinimumSystemVersion` | `26.0` |
| `NSHumanReadableCopyright` | `Copyright © 2026 Muhamad Ega Nugraha. All rights reserved.` |
| `ITSAppUsesNonExemptEncryption` | `false` |
| `CFBundleIconName` | `AppIcon`, dan `AppIcon.icns` benar-benar terbundel |

### Temuan saat pelaksanaan

| # | Temuan | Tindakan |
|---|---|---|
| 1 | Pemeriksaan "entitlements yatim" versi pertama meloloskan `DinoPocket.entitlements`, karena namanya disebut `project.yml` sebagai `excludes`. **Disebut bukan berarti dipakai** | Pemeriksa memakai `CODE_SIGN_ENTITLEMENTS`, bukan sekadar nama yang muncul |
| 2 | Screenshot Settings memuat **tab Debug**, yang hanya ada di build DEBUG dan tidak akan pernah ada di app yang dikirim | Diambil ulang dari build Release; shot utama ikut diambil ulang dari sana |

Satu-satunya perbedaan UI antara Debug dan Release adalah tab itu
(`SettingsWindow.swift:32` dan `DebugSettingsTab.swift`) — diperiksa dengan menyisir
seluruh `#if DEBUG` di kode yang di-build.

### Tentang screenshot

Shot 1 dan 4 dari build **Release**; shot 2 dan 3 dari build Debug, yang untuk layar-layar
itu identik piksel demi piksel. Jendela dipotret sendiri lalu disusun di atas latar polos
oleh `compose` (alat kecil yang menggambar ke bitmap berukuran piksel eksplisit — `NSImage.lockFocus`
memakai skala layar Retina dan akan memperbesar potret 1× jadi buram).

Percakapan pemilik produk **tidak dihapus**; isi yang pantas dipotret dibuat dengan
menambah giliran baru sampai sampah uji terdorong keluar dari layar. Empat reminder yang
dibuat demi gambar dihapus setelah selesai, supaya tidak ada notifikasi yang berbunyi
tanpa diminta.

### Yang tersisa untuk pemilik produk

URL kebijakan privasi, URL dukungan, ketersediaan nama "Apl", dan harga — semuanya
tercatat di `docs/appstore/2026-09-20-listing.md`. Unggah dan Submit for Review tidak
dilakukan; itu tindakan Anda ke pihak luar.

## Self-review

**Cakupan spec:** §2 #1 dan #2 → Task 1 (pemeriksa lebih dulu, konfigurasi kemudian);
#3 → tidak ada langkah unggah di seluruh plan, dan Task 7 berhenti di archive lokal;
#4 → Task 4 (deskripsi hanya menyebut yang ada); #5 → Task 6 Step 4; #6 → Task 2 (hanya
empat berkas yang dihapus); #7 → tidak ada langkah yang menyentuh kunci chat. §3 → Task 1–3.
§4 → Task 4. §5 → Task 5–6. §6 → Task 7. §7 DoD → Task 7 Step 4.

**Placeholder:** tidak ada; setiap langkah membawa perintah atau teks yang bisa dipakai apa
adanya.

**Konsistensi:** kategori `public.app-category.productivity` dan target `26.0` ditulis sama
persis di `project.yml`, `verify-release.sh`, dan pemeriksaan Info.plist. Nama berkas
screenshot di Task 6 sama dengan yang disebut spec §5.

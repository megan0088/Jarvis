# Jarvis — Fase A: Companion Core, siap Mac App Store

- Tanggal: 2026-08-21
- Status: Draft (menunggu review)
- Target: **macOS** (Apple Silicon, macOS 26 Tahoe+), distribusi **Mac App Store**
- Basis kode: branch `main` @ `f1955df` (arsitektur Taggo, 28/28 test hijau)

## 1. Konteks & tujuan

Jarvis adalah AI companion desktop untuk Mac: karakter 3D yang hidup di layar, bisa diajak ngobrol, dan menjaga ritme sehat penggunanya (minum, stretch, makan, waktu layar). Modelnya mengikuti **ROG OMNI (ASUS)**, tetapi seluruh kemampuan AI dibangun di atas **ekosistem Apple**.

Fase A menghasilkan **rilis v1 yang benar-benar bisa disubmit ke Mac App Store**. Fase B–D (Librarian, suara, games, HealthKit/Siri) menyusul sebagai update.

### Keputusan yang mengikat

1. **All-Apple stack.** Otak AI = **Foundation Models** (Apple Intelligence, on-device). Ollama **keluar dari jalur rilis**: kodenya tetap ada tapi hanya di-wire pada build `DEBUG`. Alasan: sandbox App Store memblokir localhost tanpa entitlement, dan app yang bergantung pada software eksternal berisiko ditolak review.
2. **AniMe Matrix di-drop** (hardware ASUS, tidak relevan di Mac).
3. **Buddy Mode bersih** — hanya virtual pet yang hidup. Tanpa panel statistik, tanpa tombol demo.
4. **Copy UI: English.**
5. **Sandbox tetap ON** (konsekuensi: app-launching terbatas — lihat §7).

### Non-tujuan (fase lain)

Librarian/dokumen Q&A, transkripsi & ringkas audio, Writing Tools, mini-games, achievement/gallery, kustomisasi karakter (Genmoji), HealthKit, Siri/App Intents, Widget/Live Activity, iCloud sync, MenuBarExtra, TipKit. Juga: app iOS (tetap ada di target multiplatform, tapi **bukan** bagian rilis ini).

## 2. Arsitektur

Mengikuti bentuk **Taggo** yang sudah diadopsi (`App/`, `Infrastructure/{Persistence,Services}`, `Presentation/{ViewModels,Views}`, `Resources/`).

Yang dilengkapi di fase ini: **composition root** ala Taggo.

```swift
// Jarvis/App/AppDependencies.swift
struct AppDependencies {
    let brain: Brain
    let systemStatus: SystemStatusProviding
    let appLauncher: AppLaunching
    let launchAtLogin: LaunchAtLoginManaging
    let buddySettings: BuddySettingsStore

    static let live = AppDependencies(
        brain: AppleBrain(),                  // Ollama TIDAK di-wire di release
        systemStatus: SystemStatusService(),
        appLauncher: AppLauncherService(),
        launchAtLogin: LaunchAtLoginService(),
        buddySettings: BuddySettingsStore()
    )

    func makeChatViewModel() -> ChatStore {
        ChatStore(brains: [.apple: brain])
    }
}
```

`OllamaBrain` tetap di `Infrastructure/Services` dan tetap diuji; hanya penyusunannya yang dibatasi:

```swift
#if DEBUG
static let debug = AppDependencies(brain: OllamaBrain(), ...)
#endif
```

Aturan layer tidak berubah: Views → ViewModels → Services/Persistence. Semua file UI macOS-only tetap `#if os(macOS)`.

## 3. Komponen baru

| File | Tanggung jawab |
|---|---|
| `App/AppDependencies.swift` | Composition root (pola Taggo). |
| `Infrastructure/Services/SystemStatusService.swift` | Baca thermal state (`ProcessInfo.thermalState`), status baterai/daya, dan tekanan memori. Memetakan ke `SystemMood` (`.normal`, `.busy`, `.hot`, `.lowBattery`) yang dipakai karakter untuk bereaksi. |
| `Infrastructure/Services/AppLauncherService.swift` | Membuka **System Settings pane** (`x-apple.systempreferences:…`) dan URL scheme umum (`mailto:`, `https:`) lewat `NSWorkspace.open(_:)`. Tidak melakukan peluncuran aplikasi arbitrer (lihat §7). |
| `Infrastructure/Services/LaunchAtLoginService.swift` | Bungkus `SMAppService.mainApp` (`register()`/`unregister()`/`status`). |
| `Infrastructure/Persistence/BuddySettingsStore.swift` | `@Observable`, persist ke `UserDefaults`: `size` (120–400pt), `opacity` (0.3–1.0), `keepOnTop` (Bool), `strolling` (Bool). |
| `Presentation/Views/HistoryPage.swift` | Riwayat nyata: reminder (`PetStore.recentReminderHistory`) + pesan chat terakhir. Menggantikan placeholder. |
| `Presentation/Views/AIUnavailableCard.swift` | Kartu penjelasan + tombol buka pane Apple Intelligence saat AI tidak tersedia. |
| `Resources/PrivacyInfo.xcprivacy` | Privacy manifest. |

## 4. Komponen yang diubah

### 4.1 `JarvisBuddyWindowController` — dibersihkan

Hapus seluruh kontrol demo: `smallButton`, `waterButton`, `stretchButton`, `mealButton`, `resetWaterButton`, `resetStretchButton`, `resetMealButton`, `stopButton`, `controlStack`, beserta selector-nya (`makeCharacterSmall`, `triggerWaterReminder`, `triggerStretchReminder`, `triggerMealReminder`, `resetWaterGoal`, `resetStretchGoal`, `resetMealGoal`). Ini juga membuang sisa teks Indonesia ("Minum", "Makan") yang lolos dari sweep l10n.

Yang tersisa hanya karakter:

- **Keluar**: tombol **Esc** (monitor `NSEvent` lokal saat buddy aktif). Tidak ada tombol di layar.
- **Strolling**: bila aktif, karakter berpindah perlahan ke posisi acak di layar dengan animasi ease-in-out; jeda acak 20–60 detik antar-perpindahan. Bila non-aktif, diam di sudut kanan-bawah.
- **Interaksi**: klik pada karakter memicu reaksi (animasi + balon sapaan singkat). Seluruh area lain **click-through** (`ignoresMouseEvents` mengikuti hit-test karakter, mekanisme hover-monitor yang sudah ada dipertahankan).
- **Pengaturan** dari `BuddySettingsStore`: ukuran, opacity (`window.alphaValue`), keep-on-top (`window.level = .floating` vs `.normal`).
- **Reaksi ke sistem**: `SystemMood` mengubah animasi/ekspresi (mis. `.hot` → karakter lesu). Polling ringan tiap 30 detik.

Buddy Mode **berhenti** saat: Esc, menu app, atau app quit. Ketika berhenti, animasi dihentikan dan window di-order out (pola `stopBuddyMode()` yang sudah ada).

### 4.2 `SettingsPage` — diperluas

Form dengan tiga section:

- **Assistant** — Persona picker (Standard/Jarvis). **Picker "Brain" dihapus** dari rilis (hanya satu otak); diganti baris **status AI**: "Apple Intelligence — Ready / Not enabled" + tombol buka System Settings bila belum aktif.
- **Buddy** — ukuran (Slider), opacity (Slider), keep-on-top (Toggle), strolling (Toggle).
- **General** — Launch at login (Toggle → `LaunchAtLoginService`), dan **About**: versi + **atribusi aset**: "3D character by badd (@l0wpoly), Sketchfab — Free Standard License".

### 4.3 `DashboardTemplate` / `HomePage` — responsive & tanpa placeholder

- `.history` → `HistoryPage` (bukan lagi `Text("History coming soon.")`).
- Window: `.defaultSize(width: 1000, height: 680)`, `minWidth: 720`, `minHeight: 520`.
- Grid kartu sudah `LazyVGrid(.adaptive(minimum: 260))` — dipertahankan; tambahkan pengecekan pada lebar minimum agar kartu tidak terpotong.
- Sidebar memakai perilaku bawaan `NavigationSplitView` (auto-collapse pada window sempit).
- Dynamic Type: hindari `.frame(height:)` tetap pada teks; gunakan `.lineLimit` + `minimumScaleFactor` seperlunya.
- Quick action "Summarize my day" dan "Set a reminder" **harus benar-benar berfungsi**: keduanya membuka chat **dengan prompt terisi** (bukan sekadar membuka panel kosong).

### 4.4 `ChatStore` / `ChatPage` — degradasi

`ChatStore.resolveBrain()` sudah menangani ketidaktersediaan otak. Yang ditambah: ketika satu-satunya otak `.unavailable`, `ChatPage` menampilkan `AIUnavailableCard` (bukan hanya banner teks), dan input dinonaktifkan dengan penjelasan. Sisa app tetap berfungsi.

## 5. Alur data

```
AppDependencies.live
   ├── AppleBrain ─────────► ChatStore ──► ChatPage (streaming kumulatif)
   │                              └─► ReminderIntent ─► PetStore.addCustomSchedule
   ├── SystemStatusService ─► SystemMood ─► BuddyWindowController (reaksi karakter)
   ├── BuddySettingsStore ──► BuddyWindowController (size/opacity/onTop/strolling)
   ├── AppLauncherService ──► SettingsPage / AIUnavailableCard (buka pane)
   └── LaunchAtLoginService ► SettingsPage
PetStore ──► WellnessCard / RemindersCard / ScreenTimeCard / HistoryPage
```

`PetStore` tetap sumber kebenaran wellness; `ChatStore` tetap ViewModel chat. Tidak ada state baru yang menduplikasi keduanya.

## 6. Penanganan kesalahan

| Situasi | Perilaku |
|---|---|
| Apple Intelligence tidak aktif / perangkat tidak memenuhi | `AIUnavailableCard` + tombol buka System Settings. Chat non-aktif; fitur lain jalan penuh. |
| Model sedang diunduh (`.needsSetup`) | Pesan "Model is downloading — try again shortly", input tetap non-aktif. |
| Stream gagal di tengah | Pesan asisten ditandai "⚠️ Connection lost." (sudah ada), tombol coba lagi. |
| `SMAppService.register()` gagal | Toggle kembali ke posisi semula + pesan singkat; tidak crash. |
| `NSWorkspace.open` ditolak sandbox | Pesan "macOS blocked that action"; tidak crash. |
| Model `Robot.usdz` gagal dimuat | Buddy Mode menampilkan fallback (lingkaran + simbol) dan tetap bisa ditutup; dicatat ke log. |

## 7. Kepatuhan App Store

**Sudah terpenuhi:** `ENABLE_APP_SANDBOX = YES`, `ENABLE_HARDENED_RUNTIME = YES`, seluruh pemrosesan AI on-device (tidak ada pengumpulan data).

**Harus dikerjakan di fase ini:**

1. **`PrivacyInfo.xcprivacy`** — `NSPrivacyTracking = false`, `NSPrivacyCollectedDataTypes = []`, `NSPrivacyAccessedAPITypes` untuk `UserDefaults` (alasan: `CA92.1`).
2. **`INFOPLIST_KEY_LSApplicationCategoryType`** → `public.app-category.healthcare-fitness`.
3. **Nol placeholder** — "History coming soon" dihapus; quick action tidak boleh no-op.
4. **Atribusi aset** di Settings › About (lisensi Sketchfab Free Standard mewajibkan kredit).
5. **Tidak ada klaim medis** — audit copy reminder/persona; posisikan sebagai kebiasaan sehat, bukan saran medis.
6. **Ollama tidak di-wire di release** — tidak ada entitlement `network.client`, tidak ada ketergantungan eksternal.
7. **App icon** lengkap untuk semua ukuran macOS.
8. **Bundle identifier** ditinjau (`com.Jarvis.Ega` → disarankan reverse-DNS milik developer, mis. `com.eganugraha.jarvis`) — mengubah ini sebelum rilis pertama tidak berbiaya.

**Batasan yang diterima (konsekuensi sandbox):** peluncuran aplikasi arbitrer tidak didukung. `AppLauncherService` hanya membuka System Settings pane, URL scheme, dan dokumen yang dipilih pengguna. Jika kelak diinginkan peluncuran penuh, app harus keluar dari sandbox dan didistribusikan langsung (notarized) — di luar rilis ini.

**Di luar kode (disiapkan pengguna):** Apple Developer Program, signing/provisioning, screenshot, deskripsi, age rating, dan **URL kebijakan privasi**.

## 8. Pengujian

Unit (Swift Testing, target `JarvisTests`):

- `SystemStatusService`: pemetaan thermal/baterai → `SystemMood` (fungsi murni yang menerima nilai input, bukan membaca sistem langsung).
- `AppLauncherService`: pembentukan URL pane System Settings (fungsi murni), termasuk penolakan input tidak dikenal.
- `BuddySettingsStore`: default, clamping (size 120–400, opacity 0.3–1.0), round-trip `UserDefaults` dengan suite terisolasi.
- `ReminderIntent`, `OllamaWire`, `ChatStore`, `AppleBrain.buildPrompt`: **tetap hijau** (28 test yang ada tidak boleh regresi).

Manual/preview: setiap View punya `#Preview`; verifikasi manual mencakup light/dark, resize window ke ukuran minimum, dan Buddy Mode (strolling, opacity, Esc).

Verifikasi rilis: `xcodebuild archive` berhasil; jalankan sekali lewat **TestFlight** sebelum submit.

## 9. Definition of Done

- [ ] `AppDependencies` dipakai; `AppleBrain` satu-satunya otak di release.
- [ ] Buddy Mode bersih: tanpa tombol, Esc keluar, strolling/opacity/on-top/size berfungsi.
- [ ] `HistoryPage` menampilkan data nyata; tidak ada placeholder di seluruh UI.
- [ ] Quick action Home benar-benar bekerja (prompt terisi).
- [ ] Degradasi tanpa Apple Intelligence diverifikasi.
- [ ] `PrivacyInfo.xcprivacy`, kategori app, ikon, atribusi aset tersedia.
- [ ] Copy 100% English; audit klaim medis lolos.
- [ ] Suite hijau (28 + test baru); `xcodebuild archive` sukses; satu putaran TestFlight.

## 10. Risiko

| Risiko | Mitigasi |
|---|---|
| Reviewer memakai Mac tanpa Apple Intelligence → mengira app rusak | Degradasi eksplisit + catatan pada App Review Notes bahwa fitur AI memerlukan Apple Intelligence |
| Perilaku strolling dianggap mengganggu | Default **non-aktif**; pengguna mengaktifkan sendiri |
| Buddy window mengganggu Mission Control/fullscreen | `collectionBehavior` yang sudah ada dipertahankan; uji pada multi-display |
| Kualitas aset 3D (1 material, wajah menyatu) membatasi ekspresi | Fase A memakai animasi bawaan + gerak/skala; ekspresi wajah menjadi lingkup Fase C |
| Beban baterai dari render RealityKit terus-menerus | Buddy Mode opt-in; hentikan animasi saat window tersembunyi |

## 11. Pertanyaan terbuka

- Bundle identifier final yang diinginkan.
- Nama tampilan di App Store ("Jarvis" kemungkinan bentrok; perlu alternatif).
- Kategori: Health & Fitness (asumsi saat ini) atau Productivity.

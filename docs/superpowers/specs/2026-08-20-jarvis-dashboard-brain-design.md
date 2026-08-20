# Jarvis — Fase 1: Re-create Dashboard (HIG) + Dua Otak

- Tanggal: 2026-08-20
- Status: Draft (menunggu review)
- Platform target: macOS (Apple Silicon, macOS 26 Tahoe+). iOS di luar scope fase ini.
- Prasyarat sudah terverifikasi di mesin dev: Apple M5, macOS 26.6, Ollama hidup di `localhost:11434` dengan model `llama3.1:8b` & `qwen3-coder:30b`, app **tidak** sandboxed.

## 1. Konteks & tujuan

Jarvis (folder `DinoPocket`) saat ini adalah pet-companion wellness: karakter SpriteKit + Buddy Mode (window transparan macOS) + reminder Minum/Stretch/Makan, semua di atas `PetStore` (`@Observable`). Belum ada "otak" — interaksinya rule-based.

Fase ini mengarahkan Jarvis ke pola **OMNI (ASUS)**: companion yang bisa **diajak ngobrol** oleh LLM lokal, dengan **dashboard macOS yang di-recreate** bergaya referensi "Prodify" namun memakai **palet & komponen Apple HIG**.

### Tujuan (in-scope)

1. **Recreate dashboard macOS** jadi native SwiftUI (`NavigationSplitView`), menggantikan `ContentView` versi macOS. Layout: sidebar + greeting AI + grid kartu + FAB.
2. **Seam dua-otak**: satu protocol `Brain`, dua implementasi — `OllamaBrain` (HTTP lokal) dan `AppleBrain` (Foundation Models / Apple Intelligence). User bisa toggle.
3. **Chat**: ngobrol dengan Jarvis lewat FAB / halaman "Jarvis AI", streaming, dengan persona.
4. **AI bikin pengingat** (fitur signature dari referensi): perintah natural → membuat `ReminderSchedule` di `PetStore`.

### Non-tujuan (ditunda ke fase lain)

- Redesign/generate karakter baru (Fase 2 — Image Playground/Genmoji).
- Voice input & Translation & Writing Tools (Fase 3).
- HealthKit, App Intents/Siri, Screen Time API resmi, TipKit (Fase 4).
- Redesign dashboard iOS (tetap pakai `ContentView` lama untuk sekarang).
- Riwayat multi-percakapan, sinkron chat lintas device.

### Prinsip

Pakai ulang logika yang sudah ada (`PetStore`, Buddy Mode, `WellnessNotificationCenter`). Yang diganti hanya **lapisan UI macOS** dan penambahan **subsystem Brain/Chat**. Injeksi dependency tetap **eksplisit** (pola `PetStore` sekarang), bukan `@Environment`.

## 2. Arsitektur

### 2.1 Seam otak

```swift
enum BrainKind: String, CaseIterable, Identifiable { case ollama, apple; var id: String { rawValue } }

enum BrainAvailability: Equatable {
    case ready
    case needsSetup(String)     // mis. "Ollama tidak berjalan di localhost:11434"
    case unavailable(String)    // mis. "Apple Intelligence belum diaktifkan"
}

enum Persona: String, CaseIterable { case standard, jarvis }   // → system prompt berbeda

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    enum Role: String, Codable { case user, assistant }
    let role: Role
    var text: String
    let date: Date
}

protocol Brain {
    var kind: BrainKind { get }
    var displayName: String { get }
    func availability() async -> BrainAvailability
    /// Streaming balasan. KONTRAK: tiap nilai yang di-yield adalah teks balasan
    /// **kumulatif** (seluruh teks sejauh ini), bukan delta. Menyeragamkan Ollama & Apple.
    func reply(to history: [ChatMessage], persona: Persona) -> AsyncThrowingStream<String, Error>
}
```

Alasan kontrak "kumulatif": Ollama `/api/chat` meng-stream **delta** token, sedangkan Foundation Models `streamResponse` meng-emit **snapshot kumulatif**. Menstandarkan ke kumulatif membuat `AppleBrain` langsung passthrough dan `OllamaBrain` cukup mengakumulasi; UI hanya meng-set `text` pesan asisten ke nilai terakhir.

### 2.2 `OllamaBrain`

- Endpoint: `POST http://localhost:11434/api/chat`
- Body: `{"model":"llama3.1:8b","messages":[{role,content}...],"stream":true}` (system prompt persona di-prepend).
- Streaming: `URLSession.bytes(for:)` → `for try await line in bytes.lines` → decode tiap baris NDJSON `{"message":{"content":"..."},"done":bool}` → akumulasi `content`, yield total.
- Availability: `GET /api/tags` dengan timeout ~2s. Gagal koneksi → `.needsSetup("Ollama tidak berjalan…")`.
- Model default `llama3.1:8b`, disimpan di `@AppStorage` (bisa diganti nanti).

### 2.3 `AppleBrain` (Foundation Models)

- `import FoundationModels`
- Availability: `SystemLanguageModel.default.availability` → map ke `BrainAvailability` (mis. `.unavailable(.appleIntelligenceNotEnabled)` → `.unavailable("Aktifkan Apple Intelligence di System Settings")`, `.modelNotReady` → `.needsSetup("Model sedang diunduh")`).
- Session: `LanguageModelSession(instructions: persona.systemPrompt)`.
- Streaming: `session.streamResponse(to: userText)` → tiap partial adalah snapshot kumulatif → yield langsung.
- Catatan: API Foundation Models bisa sedikit berbeda antar rilis OS; final by-compile di mesin dev (M5/Tahoe sudah mendukung).

### 2.4 `ChatStore` (@MainActor @Observable)

- State: `messages: [ChatMessage]`, `isStreaming: Bool`, `activeBrain: BrainKind` (backed `@AppStorage`), `persona: Persona`, `lastError: String?`.
- Dependency: `brains: [BrainKind: Brain]` (di-inject dari `JarvisApp`).
- `func send(_ text:)`:
  1. Append `ChatMessage(role:.user)`.
  2. Cek `availability()` otak aktif; kalau bukan `.ready`, tawarkan fallback ke otak lain (lihat §5).
  3. Append pesan asisten kosong, set `isStreaming = true`.
  4. Konsumsi stream, set `messages.last.text` ke tiap nilai kumulatif.
  5. Selesai/gagal → `isStreaming = false`; simpan N pesan terakhir ke `UserDefaults`.
- Cancellation: simpan `Task`; batalkan saat kirim pesan baru / chat ditutup.

### 2.5 "AI bikin pengingat" (tool/intent ringan)

Fitur signature. Implementasi Fase 1 (minimal, tanpa framework tool-calling penuh):

- Setelah balasan otak selesai, jalankan **parser intent ringan** pada input user (atau minta model mengembalikan blok terstruktur bila persona=jarvis). MVP: deteksi kata kunci + waktu ("ingatkan minum tiap 2 jam", "stretch jam 3 sore") → buat `PetStore.ReminderSchedule`.
- Konfirmasi ke user via kartu di chat ("Pengingat dibuat: Minum, tiap 2 jam") sebelum commit.
- Batas: bukan NLU penuh; hanya pola umum. Tool-calling sebenarnya (function calling) → Fase 4.

## 3. UI Dashboard (recreate, HIG)

Ganti cabang macOS di `JarvisApp` dari `ContentView` ke `DashboardView`. Struktur:

```
DashboardView  (NavigationSplitView)
├── Sidebar (List .listStyle(.sidebar))
│   ├── Nav: Beranda / Jarvis AI / Wellness / Riwayat / Setelan  (selection → accentColor)
│   ├── Avatar + status "online"
│   └── BrainCard  (Otak aktif + segmented Ollama/Apple → ChatStore.activeBrain)
└── Detail (switch selection)
    ├── HomePane
    │   ├── Greeting: "Halo, {nama}" + subjudul + pill aksi cepat
    │   ├── Grid kartu (LazyVGrid 2 kolom, adaptif):
    │   │   ├── WellnessCard   ← PetStore goals (Minum/Stretch/Makan) via ProgressView/Gauge
    │   │   ├── CharacterCard  ← SpriteView(scene lama) + mood/energy PetStore
    │   │   ├── RemindersCard  ← PetStore ReminderSchedule (upcoming) + aksi selesai/lewati
    │   │   └── ScreenTimeCard ← PetStore screen time + Swift Charts mini
    │   └── FAB (overlay) → sheet ChatView
    ├── ChatPane / ChatView  (messages + input + persona Picker)
    ├── WellnessPane (detail — reuse komponen)
    └── SettingsPane (pilih otak, model Ollama, persona default)
```

### Pemetaan warna (HIG semantic → dark mode gratis)

- Accent: `Color.accentColor` (default systemBlue).
- Latar: `Color(.windowBackgroundColor)` / kartu `Color(.controlBackgroundColor)` atau `Color(.systemGray6)` (iOS-equiv).
- Ring/goal: `.teal` (Minum), `.green` (Stretch), `.orange` (Makan) — semantik sistem.
- Teks: `.primary` / `.secondary`. Ikon: **SF Symbols** (bukan aset).

## 4. Injeksi & file baru

`JarvisApp` (macOS) membuat sekali: `PetStore`, dan `ChatStore(brains: [.ollama: OllamaBrain(), .apple: AppleBrain()])`. Keduanya dioper **eksplisit** ke `DashboardView`.

```
Jarvis/Shared/
├── Brain/
│   ├── Brain.swift           # protocol + BrainKind + ChatMessage + Persona + Availability
│   ├── OllamaBrain.swift
│   ├── AppleBrain.swift
│   └── ChatStore.swift
└── Features/
    ├── Dashboard/
    │   ├── DashboardView.swift      # NavigationSplitView root (macOS)
    │   ├── SidebarView.swift
    │   ├── HomePane.swift
    │   ├── WellnessCard.swift
    │   ├── CharacterCard.swift
    │   ├── RemindersCard.swift
    │   └── ScreenTimeCard.swift
    ├── Chat/
    │   └── ChatView.swift
    └── Settings/
        └── SettingsPane.swift
```

Setiap file View wajib punya `#Preview` (konvensi proyek).

## 5. Error handling & fallback

- **Ollama mati**: `availability()` → `.needsSetup`. UI menampilkan banner non-blok "Ollama lagi off" + tombol "Pakai Apple Intelligence" (switch `activeBrain`). Tidak melempar error mentah ke chat.
- **Apple Intelligence belum siap**: `.unavailable`/`.needsSetup` dengan instruksi jelas + fallback ke Ollama bila tersedia.
- **Dua-duanya tidak siap**: pesan tenang + link ke Setelan. Tidak crash.
- **Streaming putus**: tandai pesan asisten "terputus", tombol coba lagi.
- **Cancel**: kirim baru / tutup chat membatalkan stream berjalan.

## 6. Urutan bangun (tiap step menghasilkan sesuatu yang jalan)

| Step | Deliverable | Verifikasi |
|---|---|---|
| **A** | Shell HIG: `NavigationSplitView` + sidebar + HomePane kartu terbaca dari `PetStore` + FAB. Chat = stub echo. | Build jalan, dashboard tampil, data wellness/screen time benar, Buddy Mode masih jalan. |
| **B** | `Brain` + `OllamaBrain` + `ChatStore`; FAB/ChatView ngobrol beneran (llama3.1). | Kirim "halo" → balasan streaming dari Ollama. |
| **C** | `AppleBrain` (Foundation Models) + toggle otak + persona + fallback error. | Toggle ke Apple → balasan on-device; matikan Ollama → fallback jalan. |
| **D** | "Jarvis bikin pengingat" (parser intent ringan → `ReminderSchedule`). | "ingatkan minum tiap 2 jam" → schedule dibuat + notifikasi terpasang. |

## 7. Testing

- `OllamaBrain`: unit test parsing NDJSON via `URLProtocol` mock; verifikasi kontrak yield kumulatif.
- `ChatStore`: inject `StubBrain` → test `send()` menambah user+assistant msg, update teks, dan fallback saat availability bukan `.ready`.
- `AppleBrain`: sulit di-unit-test (butuh model) → tes manual + guard availability; minimal test mapping availability.
- Intent pengingat (Step D): unit test parser (input → `ReminderSchedule` yang benar / nil).
- Views: `#Preview` + cek manual light/dark & Dynamic Type.

## 8. Requirement & risiko

- **Entitlements**: app tidak sandboxed → `localhost` OK tanpa perubahan. Jika sandbox diaktifkan nanti: tambah `com.apple.security.network.client`.
- **Foundation Models**: butuh Apple Silicon + macOS 26 + Apple Intelligence aktif (mesin dev memenuhi). Di perangkat tak memenuhi → `AppleBrain` `.unavailable`, app tetap jalan via Ollama.
- **Risiko**: (a) permukaan API Foundation Models bisa berbeda antar rilis → final by-compile; (b) latensi model besar (default ke `8b`, bukan `30b`); (c) parser intent Step D sengaja terbatas — jangan over-promise sebagai NLU penuh.

## 9. Pertanyaan terbuka

- Nama & sapaan user diambil dari mana (hardcode "Ega" dulu, atau input di Setelan)?
- Persona "Jarvis" — seberapa berkarakter? (perlu contoh gaya bicara sebelum Fase 2 karakter).
- Isi menu sidebar final (apakah "Riwayat" & "Kalender" masuk Fase 1 atau placeholder).

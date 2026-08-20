# Jarvis Fase 1 — Dashboard HIG + Dua Otak — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Recreate dashboard macOS Jarvis menjadi native HIG (NavigationSplitView, layout ala Prodify) dan menambah "otak" chat LLM lokal dengan dua backend (Ollama & Apple Foundation Models) plus intent "AI bikin pengingat".

**Architecture:** Subsystem baru `Brain` (protocol + `OllamaBrain`/`AppleBrain` + `ChatStore`) berdiri sendiri dan fully unit-tested lebih dulu. Lalu UI dashboard HIG dirakit di atas `PetStore` yang sudah ada, dengan chat yang di-inject `ChatStore`. Injeksi dependency eksplisit (pola `PetStore` sekarang), bukan `@Environment`.

**Tech Stack:** Swift, SwiftUI, SpriteKit (reuse), FoundationModels, URLSession streaming, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-08-20-jarvis-dashboard-brain-design.md`

## Global Constraints

- Platform: macOS 26 (Tahoe)+, Apple Silicon. iOS di luar scope — jangan sentuh `ContentView` iOS.
- Bahasa string UI: **Bahasa Indonesia**.
- Test framework: **Swift Testing** (`import Testing`, `@Test`, `#expect`). Module: `Jarvis`. Scheme: `Jarvis`.
- Perintah test: `xcodebuild test -scheme Jarvis -destination 'platform=macOS' -only-testing:JarvisTests`
- Perintah build: `xcodebuild build -scheme Jarvis -destination 'platform=macOS'`
- **Setiap file .swift baru WAJIB ditambahkan ke Target Membership** — file sumber ke target `Jarvis`, file test ke target `JarvisTests` (via Xcode File Inspector, atau edit `project.pbxproj`). Tanpa ini file tidak ikut dikompilasi dan test/impl gagal dengan symbol not found.
- Setiap file View wajib punya `#Preview`.
- Warna: semantik sistem — `Color.accentColor`, `Color(.windowBackgroundColor)`, `Color(nsColor:.controlBackgroundColor)`, `.teal/.green/.orange`. Jangan hardcode hex.
- No Combine — `async/await`.
- **Kontrak `Brain.reply`:** tiap nilai yang di-yield adalah teks balasan **kumulatif** (bukan delta).
- Ollama: endpoint `http://localhost:11434`, model default `llama3.1:8b`.
- Nilai goal wellness dari `PetStore`: air 6, stretch 6, makan 3 (lihat `goalSummary`).

---

## File Structure

```
Jarvis/Shared/
├── Brain/
│   ├── Brain.swift          # protocol + BrainKind + BrainAvailability + Persona + ChatMessage
│   ├── OllamaBrain.swift     # HTTP streaming ke localhost, + OllamaWire (parsing murni)
│   ├── AppleBrain.swift      # FoundationModels
│   ├── ChatStore.swift       # @Observable @MainActor state chat + fallback
│   └── ReminderIntent.swift  # parser murni teks → ReminderSchedule?
└── Features/
    ├── Dashboard/
    │   ├── DashboardView.swift   # NavigationSplitView root (macOS)
    │   ├── SidebarView.swift     # nav + BrainCard
    │   ├── HomePane.swift        # greeting + pills + grid
    │   ├── WellnessCard.swift
    │   ├── CharacterCard.swift
    │   ├── RemindersCard.swift
    │   └── ScreenTimeCard.swift
    ├── Chat/
    │   └── ChatView.swift
    └── Settings/
        └── SettingsPane.swift
JarvisTests/
├── BrainTypesTests.swift
├── OllamaBrainTests.swift
├── ChatStoreTests.swift
└── ReminderIntentTests.swift
```

Modifikasi: `Jarvis/Shared/JarvisApp.swift` (cabang macOS → `DashboardView`); `Jarvis/Shared/PetStore.swift` (tambah `customSchedules`).

---

## Task 1: Brain core types

**Files:**
- Create: `Jarvis/Shared/Brain/Brain.swift`
- Test: `JarvisTests/BrainTypesTests.swift`

**Interfaces:**
- Produces: `enum BrainKind`, `enum BrainAvailability`, `enum Persona { var systemPrompt: String }`, `struct ChatMessage`, `protocol Brain`.

- [ ] **Step 1: Tulis test yang gagal** — `JarvisTests/BrainTypesTests.swift`

```swift
import Foundation
import Testing
@testable import Jarvis

struct BrainTypesTests {
    @Test func brainKindHasBothBackends() {
        #expect(BrainKind.allCases == [.ollama, .apple])
    }

    @Test func personasHaveNonEmptyDistinctPrompts() {
        #expect(!Persona.standard.systemPrompt.isEmpty)
        #expect(!Persona.jarvis.systemPrompt.isEmpty)
        #expect(Persona.standard.systemPrompt != Persona.jarvis.systemPrompt)
    }

    @Test func chatMessageRoundTripsThroughCodable() throws {
        let msg = ChatMessage(id: UUID(), role: .user, text: "halo", date: Date(timeIntervalSince1970: 0))
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)
        #expect(decoded == msg)
    }
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `xcodebuild test -scheme Jarvis -destination 'platform=macOS' -only-testing:JarvisTests/BrainTypesTests`
Expected: BUILD FAILED — `cannot find 'BrainKind' in scope`.

- [ ] **Step 3: Implementasi minimal** — `Jarvis/Shared/Brain/Brain.swift` (tambahkan ke target `Jarvis`)

```swift
import Foundation

enum BrainKind: String, CaseIterable, Identifiable, Codable {
    case ollama, apple
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .ollama: "Ollama"
        case .apple: "Apple Intelligence"
        }
    }
}

enum BrainAvailability: Equatable {
    case ready
    case needsSetup(String)
    case unavailable(String)
}

enum Persona: String, CaseIterable, Codable {
    case standard, jarvis
    var label: String { self == .standard ? "Standard" : "Jarvis" }
    var systemPrompt: String {
        switch self {
        case .standard:
            return "Kamu asisten yang ringkas, jujur, dan membantu. Jawab dalam bahasa yang dipakai user (default Bahasa Indonesia)."
        case .jarvis:
            return """
            Kamu Jarvis, teman wellness yang hangat dan suportif di dalam aplikasi milik Ega. \
            Kamu peduli pada ritme sehat: minum air, stretch, makan teratur, dan waktu layar. \
            Bicara santai, singkat, memberi semangat tanpa menggurui, dalam Bahasa Indonesia. \
            Kalau user minta mengatur pengingat, konfirmasi jenis dan waktunya.
            """
        }
    }
}

struct ChatMessage: Identifiable, Codable, Equatable {
    enum Role: String, Codable { case user, assistant }
    let id: UUID
    let role: Role
    var text: String
    let date: Date
}

protocol Brain {
    var kind: BrainKind { get }
    var displayName: String { get }
    func availability() async -> BrainAvailability
    /// Streaming balasan. Tiap nilai yang di-yield adalah teks balasan KUMULATIF.
    func reply(to history: [ChatMessage], persona: Persona) -> AsyncThrowingStream<String, Error>
}

extension Brain { var displayName: String { kind.displayName } }
```

- [ ] **Step 4: Jalankan test, pastikan lulus**

Run: `xcodebuild test -scheme Jarvis -destination 'platform=macOS' -only-testing:JarvisTests/BrainTypesTests`
Expected: TEST SUCCEEDED (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Jarvis/Shared/Brain/Brain.swift JarvisTests/BrainTypesTests.swift Jarvis.xcodeproj/project.pbxproj
git commit -m "feat(brain): core types — BrainKind, Persona, ChatMessage, Brain protocol"
```

---

## Task 2: OllamaBrain (parsing murni + streaming)

**Files:**
- Create: `Jarvis/Shared/Brain/OllamaBrain.swift`
- Test: `JarvisTests/OllamaBrainTests.swift`

**Interfaces:**
- Consumes: `Brain`, `ChatMessage`, `Persona`, `BrainAvailability` (Task 1).
- Produces: `enum OllamaWire { static func delta(from:) -> String?; static func cumulative(from lines:) -> [String] }`, `struct OllamaBrain: Brain`.

- [ ] **Step 1: Tulis test yang gagal** — `JarvisTests/OllamaBrainTests.swift`

```swift
import Foundation
import Testing
@testable import Jarvis

struct OllamaBrainTests {
    @Test func deltaExtractsContentFromChunk() {
        let line = #"{"model":"llama3.1:8b","message":{"role":"assistant","content":"Hal"},"done":false}"#
        #expect(OllamaWire.delta(from: line) == "Hal")
    }

    @Test func deltaReturnsNilForDoneOrGarbage() {
        #expect(OllamaWire.delta(from: #"{"done":true}"#) == nil)
        #expect(OllamaWire.delta(from: "bukan json") == nil)
        #expect(OllamaWire.delta(from: "") == nil)
    }

    @Test func cumulativeAccumulatesDeltas() {
        let lines = [
            #"{"message":{"content":"Hal"},"done":false}"#,
            #"{"message":{"content":"o "},"done":false}"#,
            #"{"message":{"content":"Ega"},"done":false}"#,
            #"{"done":true}"#
        ]
        #expect(OllamaWire.cumulative(from: lines) == ["Hal", "Halo ", "Halo Ega"])
    }

    @Test func kindIsOllama() {
        #expect(OllamaBrain().kind == .ollama)
    }
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `xcodebuild test -scheme Jarvis -destination 'platform=macOS' -only-testing:JarvisTests/OllamaBrainTests`
Expected: BUILD FAILED — `cannot find 'OllamaWire'`.

- [ ] **Step 3: Implementasi** — `Jarvis/Shared/Brain/OllamaBrain.swift` (target `Jarvis`)

```swift
import Foundation

enum OllamaWire {
    private struct Chunk: Decodable {
        struct Message: Decodable { let content: String }
        let message: Message?
        let done: Bool
    }

    /// Delta konten dari satu baris NDJSON, atau nil kalau baris kontrol/rusak.
    static func delta(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8),
              let chunk = try? JSONDecoder().decode(Chunk.self, from: data),
              let content = chunk.message?.content, !content.isEmpty
        else { return nil }
        return content
    }

    /// Peta baris-baris NDJSON menjadi daftar teks KUMULATIF.
    static func cumulative(from lines: [String]) -> [String] {
        var acc = ""
        var out: [String] = []
        for line in lines {
            guard let d = delta(from: line) else { continue }
            acc += d
            out.append(acc)
        }
        return out
    }
}

struct OllamaBrain: Brain {
    var kind: BrainKind { .ollama }
    var host = URL(string: "http://localhost:11434")!
    var model = "llama3.1:8b"

    func availability() async -> BrainAvailability {
        var req = URLRequest(url: host.appendingPathComponent("api/tags"))
        req.timeoutInterval = 2
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode == 200 { return .ready }
            return .needsSetup("Ollama tidak merespons di \(host.host ?? "localhost").")
        } catch {
            return .needsSetup("Ollama tidak berjalan. Jalankan `ollama serve` lalu coba lagi.")
        }
    }

    func reply(to history: [ChatMessage], persona: Persona) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var messages: [[String: String]] = [["role": "system", "content": persona.systemPrompt]]
                    messages += history.map { ["role": $0.role.rawValue, "content": $0.text] }
                    let body: [String: Any] = ["model": model, "messages": messages, "stream": true]

                    var req = URLRequest(url: host.appendingPathComponent("api/chat"))
                    req.httpMethod = "POST"
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    req.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, _) = try await URLSession.shared.bytes(for: req)
                    var acc = ""
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        if let d = OllamaWire.delta(from: line) {
                            acc += d
                            continuation.yield(acc)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
```

- [ ] **Step 4: Jalankan test, pastikan lulus**

Run: `xcodebuild test -scheme Jarvis -destination 'platform=macOS' -only-testing:JarvisTests/OllamaBrainTests`
Expected: TEST SUCCEEDED (4 tests).

- [ ] **Step 5: Commit**

```bash
git add Jarvis/Shared/Brain/OllamaBrain.swift JarvisTests/OllamaBrainTests.swift Jarvis.xcodeproj/project.pbxproj
git commit -m "feat(brain): OllamaBrain — NDJSON parsing + cumulative streaming"
```

---

## Task 3: ChatStore (state + fallback)

**Files:**
- Create: `Jarvis/Shared/Brain/ChatStore.swift`
- Test: `JarvisTests/ChatStoreTests.swift`

**Interfaces:**
- Consumes: `Brain`, `BrainKind`, `ChatMessage`, `Persona`, `BrainAvailability` (Task 1).
- Produces: `@MainActor @Observable final class ChatStore` dengan `init(brains:)`, `var messages`, `var isStreaming`, `var activeBrain`, `var persona`, `var noticeMessage`, `func send(_:) async`, `func resolveBrain() async -> Brain?`.

- [ ] **Step 1: Tulis test yang gagal** — `JarvisTests/ChatStoreTests.swift`

```swift
import Foundation
import Testing
@testable import Jarvis

private struct StubBrain: Brain {
    let kind: BrainKind
    var chunks: [String]
    var available: BrainAvailability = .ready
    func availability() async -> BrainAvailability { available }
    func reply(to history: [ChatMessage], persona: Persona) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { c in
            for chunk in chunks { c.yield(chunk) }
            c.finish()
        }
    }
}

struct ChatStoreTests {
    @MainActor @Test func sendAppendsUserAndStreamedAssistantMessage() async {
        let store = ChatStore(brains: [.ollama: StubBrain(kind: .ollama, chunks: ["A", "AB", "ABC"])])
        store.activeBrain = .ollama
        await store.send("halo")
        #expect(store.messages.count == 2)
        #expect(store.messages[0].role == .user)
        #expect(store.messages[1].role == .assistant)
        #expect(store.messages[1].text == "ABC")
        #expect(store.isStreaming == false)
    }

    @MainActor @Test func fallsBackWhenActiveBrainUnavailable() async {
        let apple = StubBrain(kind: .apple, chunks: ["X"], available: .unavailable("nope"))
        let ollama = StubBrain(kind: .ollama, chunks: ["dari ollama"], available: .ready)
        let store = ChatStore(brains: [.apple: apple, .ollama: ollama])
        store.activeBrain = .apple
        await store.send("tes")
        #expect(store.messages.last?.text == "dari ollama")
        #expect(store.noticeMessage != nil)
    }
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `xcodebuild test -scheme Jarvis -destination 'platform=macOS' -only-testing:JarvisTests/ChatStoreTests`
Expected: BUILD FAILED — `cannot find 'ChatStore'`.

- [ ] **Step 3: Implementasi** — `Jarvis/Shared/Brain/ChatStore.swift` (target `Jarvis`)

```swift
import Foundation
import Observation

@MainActor
@Observable
final class ChatStore {
    var messages: [ChatMessage] = []
    var isStreaming = false
    var persona: Persona = .jarvis
    var noticeMessage: String?

    var activeBrain: BrainKind {
        didSet { UserDefaults.standard.set(activeBrain.rawValue, forKey: "jarvis.activeBrain") }
    }

    private let brains: [BrainKind: Brain]
    private var streamTask: Task<Void, Never>?

    init(brains: [BrainKind: Brain]) {
        self.brains = brains
        let saved = UserDefaults.standard.string(forKey: "jarvis.activeBrain")
        self.activeBrain = saved.flatMap(BrainKind.init(rawValue:)) ?? .ollama
    }

    /// Pilih otak aktif kalau siap, jika tidak fallback ke otak lain yang siap.
    func resolveBrain() async -> Brain? {
        noticeMessage = nil
        if let active = brains[activeBrain], await active.availability() == .ready {
            return active
        }
        for (kind, brain) in brains where kind != activeBrain {
            if await brain.availability() == .ready {
                noticeMessage = "\(activeBrain.displayName) belum siap — memakai \(brain.displayName)."
                return brain
            }
        }
        noticeMessage = "Belum ada otak yang siap. Cek Ollama atau Apple Intelligence di Setelan."
        return nil
    }

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        streamTask?.cancel()
        messages.append(ChatMessage(id: UUID(), role: .user, text: trimmed, date: .now))

        guard let brain = await resolveBrain() else { return }

        let history = messages
        var assistant = ChatMessage(id: UUID(), role: .assistant, text: "", date: .now)
        messages.append(assistant)
        let index = messages.count - 1
        isStreaming = true

        let task = Task { @MainActor in
            do {
                for try await cumulative in brain.reply(to: history, persona: persona) {
                    if Task.isCancelled { break }
                    assistant.text = cumulative
                    if messages.indices.contains(index) { messages[index] = assistant }
                }
            } catch {
                if messages.indices.contains(index) {
                    messages[index].text += (messages[index].text.isEmpty ? "" : "\n\n") + "⚠️ Koneksi terputus."
                }
            }
            isStreaming = false
            persistRecent()
        }
        streamTask = task
        await task.value
    }

    private func persistRecent() {
        let recent = Array(messages.suffix(20))
        if let data = try? JSONEncoder().encode(recent) {
            UserDefaults.standard.set(data, forKey: "jarvis.chat.recent")
        }
    }
}
```

- [ ] **Step 4: Jalankan test, pastikan lulus**

Run: `xcodebuild test -scheme Jarvis -destination 'platform=macOS' -only-testing:JarvisTests/ChatStoreTests`
Expected: TEST SUCCEEDED (2 tests).

- [ ] **Step 5: Commit**

```bash
git add Jarvis/Shared/Brain/ChatStore.swift JarvisTests/ChatStoreTests.swift Jarvis.xcodeproj/project.pbxproj
git commit -m "feat(brain): ChatStore — streaming state + brain fallback"
```

---

## Task 4: AppleBrain (Foundation Models)

**Files:**
- Create: `Jarvis/Shared/Brain/AppleBrain.swift`

**Interfaces:**
- Consumes: `Brain`, `ChatMessage`, `Persona`, `BrainAvailability` (Task 1).
- Produces: `struct AppleBrain: Brain`.

> Catatan: API `FoundationModels` bisa berbeda tipis antar rilis. Kode di bawah adalah bentuk yang diharapkan; **finalisasi lewat kompilasi** di mesin dev (M5/Tahoe). Bila nama simbol berbeda, sesuaikan sambil menjaga kontrak (`availability()` + `reply` kumulatif). Tidak ada unit test perilaku model (butuh perangkat & AI aktif); verifikasi manual.

- [ ] **Step 1: Implementasi** — `Jarvis/Shared/Brain/AppleBrain.swift` (target `Jarvis`)

```swift
import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct AppleBrain: Brain {
    var kind: BrainKind { .apple }

    func availability() async -> BrainAvailability {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .ready
            case .unavailable(.appleIntelligenceNotEnabled):
                return .unavailable("Aktifkan Apple Intelligence di System Settings.")
            case .unavailable(.modelNotReady):
                return .needsSetup("Model on-device sedang diunduh. Coba lagi nanti.")
            case .unavailable:
                return .unavailable("Apple Intelligence tidak tersedia di perangkat ini.")
            }
        } else {
            return .unavailable("Butuh macOS 26 atau lebih baru.")
        }
        #else
        return .unavailable("FoundationModels tidak tersedia di build ini.")
        #endif
    }

    func reply(to history: [ChatMessage], persona: Persona) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            #if canImport(FoundationModels)
            if #available(macOS 26.0, *) {
                let task = Task {
                    do {
                        let session = LanguageModelSession(instructions: persona.systemPrompt)
                        let prompt = history.last(where: { $0.role == .user })?.text ?? ""
                        for try await partial in session.streamResponse(to: prompt) {
                            if Task.isCancelled { break }
                            continuation.yield(partial.content) // snapshot kumulatif
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
                return
            }
            #endif
            continuation.finish(throwing: NSError(domain: "AppleBrain", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Apple Intelligence tidak tersedia."]))
        }
    }
}
```

- [ ] **Step 2: Verifikasi build**

Run: `xcodebuild build -scheme Jarvis -destination 'platform=macOS'`
Expected: BUILD SUCCEEDED. Jika simbol `FoundationModels` berbeda, sesuaikan nama (mis. `partial.content`) hingga compile, jaga kontrak kumulatif.

- [ ] **Step 3: Verifikasi manual (opsional, butuh AI aktif)**

Tambah sementara di sebuah `#Preview` atau scratch: panggil `await AppleBrain().availability()` → harus `.ready` di mesin dev.

- [ ] **Step 4: Commit**

```bash
git add Jarvis/Shared/Brain/AppleBrain.swift Jarvis.xcodeproj/project.pbxproj
git commit -m "feat(brain): AppleBrain — Foundation Models streaming"
```

---

## Task 5: Dashboard HIG shell + wire ke JarvisApp

**Files:**
- Create: `Jarvis/Shared/Features/Dashboard/DashboardView.swift`, `SidebarView.swift`, `HomePane.swift`, `WellnessCard.swift`, `CharacterCard.swift`, `RemindersCard.swift`, `ScreenTimeCard.swift`, `Jarvis/Shared/Features/Settings/SettingsPane.swift`, `Jarvis/Shared/Features/Chat/ChatView.swift`
- Modify: `Jarvis/Shared/JarvisApp.swift` (cabang macOS)

**Interfaces:**
- Consumes: `PetStore` (existing: `mood`, `energy`, `statusMessage`, `goalProgress`, `goalSummary`, `reminderSchedules`, `screenTimeHistory`, `completeReminder`, `buddyReminder`), `ChatStore` (Task 3), `WalkingJarvisScene`/existing Buddy toggle.
- Produces: `struct DashboardView` (init `store:chat:onBuddyMode:isBuddyModeActive:`), `enum DashboardSection`, `struct ChatView` (init `chat:`).

> Ini task UI: "test" = build sukses + `#Preview` render + verifikasi manual. Chat masih placeholder (Task 6 menyambungkan streaming ke tampilan penuh).

- [ ] **Step 1: `ChatView.swift` (versi awal, target `Jarvis`)**

```swift
import SwiftUI

struct ChatView: View {
    @Bindable var chat: ChatStore
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            if let notice = chat.noticeMessage {
                Text(notice).font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8).background(Color(nsColor: .controlBackgroundColor))
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(chat.messages) { msg in
                        Text(msg.text)
                            .padding(8)
                            .background(msg.role == .user ? Color.accentColor.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .frame(maxWidth: .infinity, alignment: msg.role == .user ? .trailing : .leading)
                    }
                }.padding()
            }
            HStack(spacing: 8) {
                TextField("Tulis pesan ke Jarvis…", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(send)
                Button(action: send) { Image(systemName: "arrow.up.circle.fill").font(.title2) }
                    .buttonStyle(.plain).disabled(chat.isStreaming)
            }.padding()
        }
        .navigationTitle("Chat")
    }

    private func send() {
        let text = draft; draft = ""
        Task { await chat.send(text) }
    }
}

#Preview {
    ChatView(chat: ChatStore(brains: [:]))
}
```

- [ ] **Step 2: Kartu-kartu (target `Jarvis`)** — `WellnessCard.swift`

```swift
import SwiftUI

struct WellnessCard: View {
    @Bindable var store: PetStore

    private struct Row: Identifiable { let id = UUID(); let label: String; let value: Int; let goal: Int; let color: Color }
    private var rows: [Row] {
        [ Row(label: "Minum air", value: store.goalProgress.water, goal: 6, color: .teal),
          Row(label: "Stretch", value: store.goalProgress.stretch, goal: 6, color: .green),
          Row(label: "Makan", value: store.goalProgress.meal, goal: 3, color: .orange) ]
    }

    var body: some View {
        DashCard(title: "Wellness hari ini", systemImage: "target") {
            VStack(spacing: 10) {
                ForEach(rows) { r in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(r.label).font(.subheadline)
                            Spacer()
                            Text("\(r.value)/\(r.goal)").font(.subheadline).foregroundStyle(.secondary)
                        }
                        ProgressView(value: Double(r.value), total: Double(r.goal)).tint(r.color)
                    }
                }
            }
        }
    }
}

#Preview { WellnessCard(store: PetStore()).frame(width: 300).padding() }
```

`CharacterCard.swift`

```swift
import SwiftUI
import SpriteKit

struct CharacterCard: View {
    @Bindable var store: PetStore
    var body: some View {
        DashCard(title: "Jarvis", systemImage: "face.smiling") {
            HStack(spacing: 12) {
                Image(systemName: "sparkles").font(.system(size: 42)).foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.statusMessage).font(.subheadline).foregroundStyle(.secondary)
                    ProgressView(value: Double(store.energy), total: 100) { Text("Energy").font(.caption) }
                        .tint(Color.accentColor)
                }
            }
        }
    }
}

#Preview { CharacterCard(store: PetStore()).frame(width: 300).padding() }
```

`RemindersCard.swift`

```swift
import SwiftUI

struct RemindersCard: View {
    @Bindable var store: PetStore
    private var upcoming: [PetStore.ReminderSchedule] {
        let now = Calendar.current.dateComponents([.hour, .minute], from: .now)
        let minutesNow = (now.hour ?? 0) * 60 + (now.minute ?? 0)
        return store.reminderSchedules
            .filter { ($0.hour * 60 + $0.minute) >= minutesNow }
            .sorted { ($0.hour * 60 + $0.minute) < ($1.hour * 60 + $1.minute) }
            .prefix(3).map { $0 }
    }
    var body: some View {
        DashCard(title: "Pengingat", systemImage: "bell") {
            VStack(spacing: 8) {
                ForEach(upcoming) { s in
                    HStack {
                        Image(systemName: s.kind.icon).foregroundStyle(Color.accentColor).frame(width: 22)
                        VStack(alignment: .leading) {
                            Text(s.title).font(.subheadline)
                            Text(s.timeLabel).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                if upcoming.isEmpty { Text("Tidak ada pengingat lagi hari ini.").font(.caption).foregroundStyle(.secondary) }
            }
        }
    }
}

#Preview { RemindersCard(store: PetStore()).frame(width: 300).padding() }
```

`ScreenTimeCard.swift`

```swift
import SwiftUI

struct ScreenTimeCard: View {
    @Bindable var store: PetStore
    private var todayLabel: String {
        let secs = store.screenTimeHistory.first(where: { Calendar.current.isDateInToday($0.date) })?.duration ?? 0
        let h = Int(secs) / 3600, m = (Int(secs) % 3600) / 60
        return "\(h)j \(m)m"
    }
    var body: some View {
        DashCard(title: "Screen time", systemImage: "desktopcomputer") {
            Text(todayLabel).font(.system(size: 26, weight: .medium))
        }
    }
}

#Preview { ScreenTimeCard(store: PetStore()).frame(width: 300).padding() }
```

Helper bersama `DashCard` (taruh di `WellnessCard.swift` atau file kecil sendiri):

```swift
import SwiftUI

struct DashCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage).font(.subheadline.weight(.medium))
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
    }
}
```

- [ ] **Step 3: `HomePane.swift`, `SidebarView.swift`, `SettingsPane.swift`, `DashboardView.swift` (target `Jarvis`)**

```swift
// HomePane.swift
import SwiftUI

struct HomePane: View {
    @Bindable var store: PetStore
    @Bindable var chat: ChatStore
    var onBuddyMode: (() -> Void)?
    @Binding var showChat: Bool

    private let cols = [GridItem(.adaptive(minimum: 260), spacing: 12)]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Halo, Ega").font(.largeTitle.weight(.medium))
                Text("Ada yang bisa aku bantu hari ini?").font(.title3).foregroundStyle(Color.accentColor)
                HStack(spacing: 8) {
                    Button { showChat = true } label: { Label("Tanya Jarvis", systemImage: "sparkles") }
                        .buttonStyle(.borderedProminent)
                    Button { onBuddyMode?() } label: { Label("Buddy Mode", systemImage: "figure.walk") }
                        .buttonStyle(.bordered)
                }
                LazyVGrid(columns: cols, spacing: 12) {
                    WellnessCard(store: store)
                    CharacterCard(store: store)
                    RemindersCard(store: store)
                    ScreenTimeCard(store: store)
                }
            }.padding()
        }
        .overlay(alignment: .bottomTrailing) {
            Button { showChat = true } label: {
                Image(systemName: "sparkles").font(.title2).padding(14)
                    .background(Color.accentColor, in: Circle()).foregroundStyle(.white)
            }.buttonStyle(.plain).padding(20)
        }
        .navigationTitle("Beranda")
    }
}
```

```swift
// SidebarView.swift
import SwiftUI

enum DashboardSection: String, CaseIterable, Identifiable {
    case home = "Beranda", chat = "Jarvis AI", wellness = "Wellness", history = "Riwayat", settings = "Setelan"
    var id: String { rawValue }
    var icon: String {
        switch self { case .home: "house"; case .chat: "sparkles"; case .wellness: "heart"; case .history: "clock.arrow.circlepath"; case .settings: "gearshape" }
    }
}

struct SidebarView: View {
    @Binding var selection: DashboardSection
    @Bindable var chat: ChatStore
    var body: some View {
        List(selection: $selection) {
            ForEach(DashboardSection.allCases) { s in
                Label(s.rawValue, systemImage: s.icon).tag(s)
            }
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Otak aktif", systemImage: "bolt").font(.caption)
                    Picker("", selection: $chat.activeBrain) {
                        ForEach(BrainKind.allCases) { Text($0.displayName).tag($0) }
                    }.pickerStyle(.segmented).labelsHidden()
                }
            }
        }
        .listStyle(.sidebar)
    }
}
```

```swift
// SettingsPane.swift
import SwiftUI

struct SettingsPane: View {
    @Bindable var chat: ChatStore
    var body: some View {
        Form {
            Picker("Otak", selection: $chat.activeBrain) {
                ForEach(BrainKind.allCases) { Text($0.displayName).tag($0) }
            }
            Picker("Persona", selection: $chat.persona) {
                ForEach(Persona.allCases, id: \.self) { Text($0.label).tag($0) }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Setelan")
    }
}

#Preview { SettingsPane(chat: ChatStore(brains: [:])) }
```

```swift
// DashboardView.swift
import SwiftUI

struct DashboardView: View {
    @Bindable var store: PetStore
    @Bindable var chat: ChatStore
    var onBuddyMode: (() -> Void)? = nil
    var isBuddyModeActive: Bool = false

    @State private var selection: DashboardSection = .home
    @State private var showChat = false

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection, chat: chat)
                .frame(minWidth: 180)
        } detail: {
            switch selection {
            case .home: HomePane(store: store, chat: chat, onBuddyMode: onBuddyMode, showChat: $showChat)
            case .chat: ChatView(chat: chat)
            case .wellness: WellnessCard(store: store).padding().navigationTitle("Wellness")
            case .history: Text("Riwayat (segera).").foregroundStyle(.secondary).navigationTitle("Riwayat")
            case .settings: SettingsPane(chat: chat)
            }
        }
        .sheet(isPresented: $showChat) {
            NavigationStack { ChatView(chat: chat) }.frame(minWidth: 420, minHeight: 520)
        }
    }
}

#Preview {
    DashboardView(store: PetStore(), chat: ChatStore(brains: [:]))
}
```

- [ ] **Step 4: Wire `JarvisApp.swift` (cabang macOS)** — ganti pembuatan `ContentView` menjadi `DashboardView`, tambah `ChatStore`.

Di `JarvisApp`, tambah properti:

```swift
@State private var chat = ChatStore(brains: [.ollama: OllamaBrain(), .apple: AppleBrain()])
```

Di `rootView` cabang `#if os(macOS)`, ganti:

```swift
DashboardView(
    store: store,
    chat: chat,
    onBuddyMode: toggleBuddyMode,
    isBuddyModeActive: isBuddyMode
)
.onChange(of: isBuddyMode) { _, active in
    if active {
        JarvisBuddyWindowController.shared.startBuddyMode(store: store, onDismiss: { dismissFromBuddy() })
        hidePrimaryWindows()
    } else {
        JarvisBuddyWindowController.shared.stopBuddyMode()
        showPrimaryWindows()
    }
}
```

(iOS branch tetap `ContentView(store: store)`.)

- [ ] **Step 5: Build + verifikasi manual**

Run: `xcodebuild build -scheme Jarvis -destination 'platform=macOS'`
Expected: BUILD SUCCEEDED. Jalankan app: dashboard HIG tampil, kartu wellness/screen time menampilkan nilai `PetStore`, sidebar berpindah, tombol "Buddy Mode" masih memunculkan window buddy, FAB membuka sheet chat (placeholder).

- [ ] **Step 6: Commit**

```bash
git add Jarvis/Shared/Features Jarvis/Shared/JarvisApp.swift Jarvis.xcodeproj/project.pbxproj
git commit -m "feat(dashboard): HIG NavigationSplitView shell wired to PetStore + ChatStore"
```

---

## Task 6: Chat live (Ollama + Apple) + persona + banner

**Files:**
- Modify: `Jarvis/Shared/Features/Chat/ChatView.swift` (persona picker, streaming indicator), `Jarvis/Shared/Features/Dashboard/SidebarView.swift` (sudah ada toggle otak).

**Interfaces:**
- Consumes: `ChatStore` (Task 3) sudah punya `send`, `activeBrain`, `persona`, `isStreaming`, `noticeMessage`.

> Logika sudah diuji di Task 3. Task ini menyambungkan ke UI penuh; verifikasi = manual dengan Ollama hidup.

- [ ] **Step 1: Tambah persona picker + indikator streaming ke `ChatView`**

Sisipkan toolbar/header di `ChatView.body` (di atas `ScrollView`):

```swift
.toolbar {
    ToolbarItem(placement: .automatic) {
        Picker("Persona", selection: $chat.persona) {
            ForEach(Persona.allCases, id: \.self) { Text($0.label).tag($0) }
        }.pickerStyle(.segmented)
    }
}
```

Dan indikator saat streaming (di bawah daftar pesan):

```swift
if chat.isStreaming {
    HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Jarvis mengetik…").font(.caption).foregroundStyle(.secondary) }
        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild build -scheme Jarvis -destination 'platform=macOS'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Verifikasi manual (Ollama)**

Pastikan `ollama serve` jalan. Buka app → FAB → ketik "halo, aku lagi ngoding" → balasan streaming dari `llama3.1:8b` muncul bertahap. Ganti otak ke Apple di sidebar → kirim lagi → balasan dari Foundation Models. Matikan Ollama, set otak Ollama, kirim → banner fallback "memakai Apple Intelligence" muncul.

- [ ] **Step 4: Commit**

```bash
git add Jarvis/Shared/Features/Chat/ChatView.swift Jarvis.xcodeproj/project.pbxproj
git commit -m "feat(chat): live streaming chat with persona picker + fallback banner"
```

---

## Task 7: Intent "AI bikin pengingat" → ReminderSchedule

**Files:**
- Create: `Jarvis/Shared/Brain/ReminderIntent.swift`
- Test: `JarvisTests/ReminderIntentTests.swift`
- Modify: `Jarvis/Shared/PetStore.swift` (tambah `customSchedules` + merge), `Jarvis/Shared/Brain/ChatStore.swift` (panggil parser setelah kirim)

**Interfaces:**
- Consumes: `PetStore.ReminderKind`, `PetStore.ReminderSchedule` (existing), `ChatStore` (Task 3).
- Produces: `enum ReminderIntent { static func parse(_ text: String) -> PetStore.ReminderSchedule? }`; `PetStore.addCustomSchedule(_:)`.

- [ ] **Step 1: Tulis test yang gagal** — `JarvisTests/ReminderIntentTests.swift`

```swift
import Foundation
import Testing
@testable import Jarvis

struct ReminderIntentTests {
    @Test func parsesWaterReminderWithClockTime() {
        let s = ReminderIntent.parse("tolong ingatkan minum air jam 3 sore")
        #expect(s?.kind == .water)
        #expect(s?.hour == 15)
        #expect(s?.minute == 0)
    }

    @Test func parsesStretchWithHHMM() {
        let s = ReminderIntent.parse("ingatkan stretch jam 09.30")
        #expect(s?.kind == .stretch)
        #expect(s?.hour == 9)
        #expect(s?.minute == 30)
    }

    @Test func returnsNilWhenNoReminderIntent() {
        #expect(ReminderIntent.parse("apa kabar hari ini?") == nil)
    }

    @Test func returnsNilWhenTimeMissing() {
        #expect(ReminderIntent.parse("ingatkan aku minum") == nil)
    }
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `xcodebuild test -scheme Jarvis -destination 'platform=macOS' -only-testing:JarvisTests/ReminderIntentTests`
Expected: BUILD FAILED — `cannot find 'ReminderIntent'`.

- [ ] **Step 3: Implementasi parser** — `Jarvis/Shared/Brain/ReminderIntent.swift` (target `Jarvis`)

```swift
import Foundation

enum ReminderIntent {
    /// Deteksi pola sederhana: harus ada kata "ingat/reminder" + jenis + waktu jam.
    static func parse(_ text: String) -> PetStore.ReminderSchedule? {
        let t = text.lowercased()
        guard t.contains("ingat") || t.contains("reminder") || t.contains("pengingat") else { return nil }

        let kind: PetStore.ReminderKind
        if t.contains("minum") || t.contains("air") || t.contains("hidra") { kind = .water }
        else if t.contains("stretch") || t.contains("regang") || t.contains("gerak") { kind = .stretch }
        else if t.contains("makan") { kind = .meal }
        else { return nil }

        guard let (hour, minute) = clock(in: t) else { return nil }

        let (title, body): (String, String) = {
            switch kind {
            case .water: ("Minum air", "Ambil jeda dan minum segelas air.")
            case .stretch: ("Stretch break", "Berdiri dan regangkan tubuh sebentar.")
            case .meal: ("Makan", "Saatnya makan, jangan dilewat.")
            }
        }()
        return PetStore.ReminderSchedule(
            id: "custom.\(kind.rawValue).\(hour).\(minute)",
            kind: kind, hour: hour, minute: minute, title: title, body: body
        )
    }

    /// Ekstrak jam dari "jam 3 sore", "jam 09.30", "15:00".
    private static func clock(in t: String) -> (Int, Int)? {
        let pattern = #"(?:jam\s*)?(\d{1,2})(?:[:.](\d{2}))?"#
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)),
              let hRange = Range(m.range(at: 1), in: t) else { return nil }
        var hour = Int(t[hRange]) ?? -1
        var minute = 0
        if let mmRange = Range(m.range(at: 2), in: t) { minute = Int(t[mmRange]) ?? 0 }
        if t.contains("sore") || t.contains("malam"), hour < 12 { hour += 12 }
        if t.contains("pagi"), hour == 12 { hour = 0 }
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return (hour, minute)
    }
}
```

- [ ] **Step 4: Jalankan test, pastikan lulus**

Run: `xcodebuild test -scheme Jarvis -destination 'platform=macOS' -only-testing:JarvisTests/ReminderIntentTests`
Expected: TEST SUCCEEDED (4 tests).

- [ ] **Step 5: Tambah storage di `PetStore`** — buat `reminderSchedules` menyertakan schedule kustom.

Di `PetStore.swift`, tambah properti tersimpan dan method (dekat `reminderSchedules`):

```swift
var customSchedules: [ReminderSchedule] = [] {
    didSet { saveWellness() } // ikuti pola persist yang ada
}

func addCustomSchedule(_ schedule: ReminderSchedule) {
    guard !customSchedules.contains(where: { $0.id == schedule.id }) else { return }
    customSchedules.append(schedule)
    Task { await scheduleReminders() }
}
```

Ubah computed `reminderSchedules` agar menambahkan kustom di akhir:

```swift
var reminderSchedules: [ReminderSchedule] {
    let base: [ReminderSchedule] = [ /* daftar hardcoded yang sudah ada, biarkan */ ]
    return base + customSchedules
}
```

> Catatan: `saveWellness()` sudah dipakai method lain di `PetStore`. Kalau `customSchedules` perlu ikut persist ke `UserDefaults`, tambahkan encode/decode di `saveWellness()`/`init` mengikuti pola properti wellness lain. Untuk MVP boleh in-memory (hapus `didSet`/persist) — sesuaikan dengan pola file.

- [ ] **Step 6: Sambungkan di `ChatStore.send`** — setelah append pesan user, cek intent.

Di `ChatStore`, tambah dependency opsional dan panggilan:

```swift
// tambahkan properti:
var onCreateReminder: ((PetStore.ReminderSchedule) -> Void)?

// di send(_:), setelah messages.append(user ...):
if let schedule = ReminderIntent.parse(trimmed) {
    onCreateReminder?(schedule)
    messages.append(ChatMessage(id: UUID(), role: .assistant,
        text: "Oke, pengingat dibuat: \(schedule.title) jam \(schedule.timeLabel).", date: .now))
    return
}
```

Di `JarvisApp` saat membuat `ChatStore`, set closure:

```swift
chat.onCreateReminder = { [store] schedule in store.addCustomSchedule(schedule) }
```

(Karena `chat` dibuat sebagai `@State` initializer, set `onCreateReminder` di `.task` root atau `init` setelah `store` tersedia.)

- [ ] **Step 7: Build + verifikasi manual**

Run: `xcodebuild build -scheme Jarvis -destination 'platform=macOS'`
Expected: BUILD SUCCEEDED. Di app: chat "ingatkan minum air jam 3 sore" → balasan konfirmasi + schedule kustom muncul di `RemindersCard`/notifikasi terjadwal.

- [ ] **Step 8: Commit**

```bash
git add Jarvis/Shared/Brain/ReminderIntent.swift JarvisTests/ReminderIntentTests.swift Jarvis/Shared/PetStore.swift Jarvis/Shared/Brain/ChatStore.swift Jarvis/Shared/JarvisApp.swift Jarvis.xcodeproj/project.pbxproj
git commit -m "feat(chat): natural-language 'buat pengingat' → PetStore custom schedule"
```

---

## Catatan eksekusi

- **Target membership** adalah friksi utama: tiap file baru harus masuk target `Jarvis` (sumber) / `JarvisTests` (test). Kalau pakai Xcode, drag file ke grup yang benar & centang target. Kalau otomatis, edit `project.pbxproj` (grup `Jarvis/Shared/...`).
- Task 1–4 & 7-parser adalah unit-testable murni; Task 5–6 verifikasi manual (UI).
- Task 4 (AppleBrain) & Task 5 warna/kontrol mengandalkan API OS terbaru — finalisasi lewat kompilasi di mesin dev.

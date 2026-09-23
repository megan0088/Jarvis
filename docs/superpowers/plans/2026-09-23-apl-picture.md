# Apl G — Gambar dari Image Playground — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ketik "gambarkan kucing pakai topi" di Apl, sheet Image Playground terbuka dengan
konsep itu sudah terisi, dan gambar yang dipilih masuk percakapan serta bertahan di sana.

**Architecture:** Empat unit murni memikul seluruh keputusan (mengenali ajakan, memotong
konsep, memutuskan ketersediaan, menjaga satu permintaan berjalan); satu penyimpanan berkas
yang bisa diuji di direktori sementara; dan satu sheet milik Apple yang kita tidak tiru.
`ChatStore` menangkap ajakan menggambar secara lokal — jalur ketiga sesudah reminder dan
"main suit" — sehingga model tidak pernah dilibatkan.

**Tech Stack:** Swift 6, SwiftUI, AppKit (`NSOpenPanel`, `NSSavePanel`), ImagePlayground,
Swift Testing, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-09-23-apl-picture-design.md`

## Global Constraints

- **Model tidak pernah dipanggil** dari jalur menggambar (spec §2 #1, §3).
- **Tidak ada entitlement baru**; kategori App Store tetap **Productivity** (spec §2 #7).
- Target **macOS 26+**, `SWIFT_VERSION: 6.0`, tipe UI `@MainActor`.
- **XcodeGen**: `xcodegen generate` setelah menambah berkas.
- Test yang menyentuh berkas WAJIB memakai direktori sementara, bukan container app.
- `SharedCore` tidak boleh mengimpor SwiftUI/AppKit/ImagePlayground.
- Teks antarmuka **Inggris**, komentar dan dokumen **Indonesia**.
- Setiap commit diakhiri `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.

## File Structure

**Dibuat** (`DinoPocketMac/Presentation/Picture/`): `DrawCommand.swift`,
`PictureRequest.swift` (berisi `PictureRequest`, `PictureAvailability`, `PictureSession`),
`PictureBubble.swift`; `DinoPocketMac/Infrastructure/Persistence/ImageStore.swift`.

**Diubah:** `SharedCore/Data/Models/ChatMessage.swift` (satu case lampiran),
`MessageRow.swift` (satu kind), `AnswerAnnouncement.swift` (label gambar),
`Composer.swift` (menu gambar), `ConversationView.swift` (sheet + menu),
`ChatStore.swift` (jalur menggambar), `MainWindow.swift`, `AplApp.swift`,
`AppDependencies.swift`.

**Test:** `DrawCommandTests.swift`, `PictureSessionTests.swift`, `ImageStoreTests.swift`,
`PictureWithoutBrainTests.swift`, tambahan di `ChatMessageTests.swift`,
`MessageRowTests.swift`, `AnswerAnnouncementTests.swift`.

---

### Task 1: Mengenali ajakan menggambar

**Files:**
- Create: `DinoPocketMac/Presentation/Picture/DrawCommand.swift`
- Test: `DinoPocketTests/DrawCommandTests.swift`

**Interfaces:**
- Produces: `DrawCommand.concept(in: String) -> String?` — `nil` berarti bukan ajakan
  menggambar; string berarti konsep yang sudah dipotong.

Bedanya dengan `PlayCommand` di F: unit ini tidak cukup menjawab "cocok atau tidak", ia
harus **mengembalikan konsepnya**. Dan kata "draw" jauh lebih umum daripada "main suit" —
pertanyaan koding "how do I draw a circle in SwiftUI?" harus tetap sampai ke model.

- [ ] **Step 1: Tulis test yang gagal**

```swift
import Testing
@testable import Apl

struct DrawCommandTests {

    /// Konsepnya diuji sebagai string PERSIS. "Cocok/tidak" saja tidak cukup:
    /// yang dikirim ke Image Playground adalah potongan ini.
    @Test func cutsTheConceptOut() {
        #expect(DrawCommand.concept(in: "gambarkan kucing pakai topi") == "kucing pakai topi")
        #expect(DrawCommand.concept(in: "gambar rumah di tepi danau") == "rumah di tepi danau")
        #expect(DrawCommand.concept(in: "buatkan gambar robot kecil") == "robot kecil")
        #expect(DrawCommand.concept(in: "draw a small friendly robot") == "a small friendly robot")
        #expect(DrawCommand.concept(in: "Draw an orange cat") == "an orange cat")
    }

    /// Kalimat yang meminta pengingat tetap pengingat — alasan yang sama
    /// dengan PlayCommand di F.
    @Test func doesNotHijackReminders() {
        #expect(DrawCommand.concept(in: "remind me to draw the logo at 4pm") == nil)
        #expect(DrawCommand.concept(in: "remind me to gambar poster besok") == nil)
    }

    /// Jebakan sebenarnya: "draw" adalah kata biasa di percakapan tentang
    /// koding, dan pertanyaan seperti ini harus sampai ke model.
    @Test func doesNotFireOnQuestions() {
        #expect(DrawCommand.concept(in: "how do I draw a circle in SwiftUI?") == nil)
        #expect(DrawCommand.concept(in: "what does Canvas draw first?") == nil)
        #expect(DrawCommand.concept(in: "apa bedanya draw dan render?") == nil)
    }

    /// Ajakan tanpa konsep bukan ajakan: tidak ada yang bisa dikirim.
    @Test func needsSomethingToDraw() {
        #expect(DrawCommand.concept(in: "gambarkan") == nil)
        #expect(DrawCommand.concept(in: "draw") == nil)
        #expect(DrawCommand.concept(in: "draw a") == nil)
    }
}
```

- [ ] **Step 2: Jalankan dan pastikan gagal**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/DrawCommandTests 2>&1 | grep -E "error:" | head -3`
Expected: `cannot find 'DrawCommand' in scope`.

- [ ] **Step 3: Tulis implementasinya**

```swift
//
//  DrawCommand.swift
//  Apl
//
//  Mengenali ajakan menggambar dan memotong konsepnya (spec G §2 #2, §3).
//
//  "draw" adalah kata biasa di percakapan tentang koding, jadi unit ini lebih
//  berhati-hati daripada `PlayCommand`: kalimat tanya tidak pernah jadi ajakan,
//  dan ajakan tanpa konsep bukan ajakan sama sekali.
//

import Foundation

enum DrawCommand {

    /// Awalan yang dikenali, diperiksa dari yang paling panjang supaya
    /// "buatkan gambar" tidak keburu tertangkap "gambar".
    private static let prefixes = [
        "buatkan gambar", "bikin gambar", "tolong gambarkan",
        "gambarkan", "gambar", "draw me", "draw",
    ]

    /// Konsep yang diminta, atau `nil` bila ini bukan ajakan menggambar.
    static func concept(in text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()

        // Pengingat tetap pengingat, apa pun isinya sesudah itu.
        guard !lowered.contains("remind me") else { return nil }
        // Pertanyaan tidak pernah jadi perintah menggambar.
        guard !lowered.hasSuffix("?") else { return nil }
        guard !questionOpeners.contains(where: { lowered.hasPrefix($0) }) else { return nil }

        guard let prefix = prefixes.first(where: { lowered.hasPrefix($0) }) else { return nil }
        let concept = trimmed.dropFirst(prefix.count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // "draw a" tanpa apa-apa sesudahnya tidak punya yang bisa digambar.
        guard concept.count >= 3 else { return nil }
        return concept
    }

    private static let questionOpeners = [
        "how ", "what ", "why ", "when ", "where ", "which ", "apa ", "kenapa ", "bagaimana ",
    ]
}
```

- [ ] **Step 4: Jalankan dan pastikan lulus**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/DrawCommandTests 2>&1 | grep -E "Test run with|TEST"`
Expected: PASS (4 test).

- [ ] **Step 5: Commit**

```bash
git add DinoPocketMac/Presentation/Picture/DrawCommand.swift DinoPocketTests/DrawCommandTests.swift
git commit -m "$(cat <<'EOF'
feat(g): mengenali ajakan menggambar dan memotong konsepnya

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Permintaan, ketersediaan, dan satu sheet saja

**Files:**
- Create: `DinoPocketMac/Presentation/Picture/PictureRequest.swift`
- Test: `DinoPocketTests/PictureSessionTests.swift`

**Interfaces:**
- Produces: `PictureRequest(concept:sourceImage:)`, `PictureAvailability.decide(isAvailable:)`,
  `PictureAvailability.unavailableNotice`, `PictureSession` (`request`, `start(_:) -> Bool`,
  `finish()`).

Tiga hal kecil yang semuanya bisa diuji tanpa framework Apple sama sekali — itulah
alasannya dipisahkan dari view.

- [ ] **Step 1: Tulis test yang gagal**

```swift
import Foundation
import Testing
@testable import Apl

@MainActor
struct PictureSessionTests {

    @Test func availabilityIsADecisionNotAnIf() {
        #expect(PictureAvailability.decide(isAvailable: true) == .ready)
        #expect(PictureAvailability.decide(isAvailable: false) == .unavailable)
        #expect(PictureAvailability.unavailableNotice.isEmpty == false)
    }

    @Test func startsOneRequest() {
        let session = PictureSession()
        #expect(session.request == nil)
        #expect(session.start(PictureRequest(concept: "a cat", sourceImage: nil)))
        #expect(session.request?.concept == "a cat")
    }

    /// Sheet kedua di atas sheet pertama bukan jawaban atas apa pun
    /// (spec G §5).
    @Test func refusesASecondRequestWhileOneIsOpen() {
        let session = PictureSession()
        #expect(session.start(PictureRequest(concept: "a cat", sourceImage: nil)))
        #expect(session.start(PictureRequest(concept: "a dog", sourceImage: nil)) == false)
        #expect(session.request?.concept == "a cat")
    }

    @Test func finishClearsIt() {
        let session = PictureSession()
        _ = session.start(PictureRequest(concept: "a cat", sourceImage: nil))
        session.finish()
        #expect(session.request == nil)
        #expect(session.start(PictureRequest(concept: "a dog", sourceImage: nil)))
    }
}
```

- [ ] **Step 2: Jalankan dan pastikan gagal**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/PictureSessionTests 2>&1 | grep -E "error:" | head -3`
Expected: `cannot find 'PictureAvailability' in scope`.

- [ ] **Step 3: Tulis implementasinya**

```swift
//
//  PictureRequest.swift
//  Apl
//
//  Permintaan gambar yang sedang berjalan, dan keputusan-keputusan kecil di
//  sekitarnya (spec G §3, §5).
//
//  Tidak ada satu pun `import ImagePlayground` di sini: ketersediaan masuk
//  sebagai Bool, supaya seluruh cabangnya bisa diuji tanpa framework.
//

import Foundation
import Observation

struct PictureRequest: Equatable {
    /// Boleh kosong: menu "Describe an image…" membuka sheet tanpa konsep.
    let concept: String
    /// Foto yang jadi dasar, bila pengguna memilihnya.
    let sourceImage: URL?
}

enum PictureAvailability: Equatable {
    case ready, unavailable

    static func decide(isAvailable: Bool) -> PictureAvailability {
        isAvailable ? .ready : .unavailable
    }

    /// Satu kalimat, lalu jalan ke System Settings — sama seperti banner AI
    /// sejak B. Bukan pesan error.
    static let unavailableNotice =
        "Image Playground isn't available yet. Turn on Apple Intelligence in System Settings."
}

@MainActor
@Observable
final class PictureSession {

    private(set) var request: PictureRequest?

    /// `false` bila sudah ada yang terbuka; pemanggil mengabaikannya
    /// (spec G §5 — sheet kedua di atas sheet pertama bukan jawaban).
    @discardableResult
    func start(_ request: PictureRequest) -> Bool {
        guard self.request == nil else { return false }
        self.request = request
        return true
    }

    func finish() {
        request = nil
    }
}
```

- [ ] **Step 4: Jalankan dan pastikan lulus**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/PictureSessionTests 2>&1 | grep -E "Test run with|TEST"`
Expected: PASS (4 test).

- [ ] **Step 5: Commit**

```bash
git add DinoPocketMac/Presentation/Picture/PictureRequest.swift DinoPocketTests/PictureSessionTests.swift
git commit -m "$(cat <<'EOF'
feat(g): permintaan gambar, ketersediaan, dan satu sheet saja

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Penyimpanan gambar

**Files:**
- Create: `DinoPocketMac/Infrastructure/Persistence/ImageStore.swift`
- Test: `DinoPocketTests/ImageStoreTests.swift`

**Interfaces:**
- Produces: `ImageStore(folder:)`, `ImageStore.limit = 20`, `save(contentsOf:) throws -> String`,
  `url(for:) -> URL?`, `prune(keeping: Set<String>)`, `eraseAllStoredData()`.

Aturan pentingnya ada di `prune`: folder dijaga sebagai **fungsi dari percakapan**
(spec G §4). Berkas yang tidak dirujuk pesan mana pun tidak punya cara untuk ditampilkan
lagi, jadi menyimpannya hanya menimbun berkas yatim.

- [ ] **Step 1: Tulis test yang gagal**

```swift
import Foundation
import Testing
@testable import Apl

@MainActor
struct ImageStoreTests {

    /// Direktori sementara, bukan container app — test host-nya Apl.app.
    private func store() throws -> (ImageStore, URL) {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("test.images.\(UUID())", isDirectory: true)
        return (ImageStore(folder: folder), folder)
    }

    private func sourceFile(_ bytes: Int = 8) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("src.\(UUID()).png")
        try Data(repeating: 7, count: bytes).write(to: url)
        return url
    }

    @Test func savesAndFindsAgain() throws {
        let (store, _) = try store()
        let name = try store.save(contentsOf: try sourceFile())
        #expect(name.hasSuffix(".png"))
        #expect(store.url(for: name) != nil)
    }

    /// Pesan menyimpan nama, bukan gambarnya. Berkas yang hilang harus
    /// menghasilkan nil, bukan URL yang menunjuk ke ketiadaan.
    @Test func missingFileIsNil() throws {
        let (store, _) = try store()
        #expect(store.url(for: "tidak-ada.png") == nil)
    }

    @Test func pruneDropsWhatNoMessageReferences() throws {
        let (store, _) = try store()
        let kept = try store.save(contentsOf: try sourceFile())
        let dropped = try store.save(contentsOf: try sourceFile())
        store.prune(keeping: [kept])
        #expect(store.url(for: kept) != nil)
        #expect(store.url(for: dropped) == nil)
    }

    /// Pagar keras: satu sesi yang penuh gambar tidak boleh menggelembung
    /// tanpa batas, bahkan bila semuanya masih dirujuk.
    @Test func hardCapKeepsTheNewest() throws {
        let (store, _) = try store()
        var names: [String] = []
        for _ in 0..<(ImageStore.limit + 3) {
            names.append(try store.save(contentsOf: try sourceFile()))
        }
        store.prune(keeping: Set(names))
        let survivors = names.filter { store.url(for: $0) != nil }
        #expect(survivors.count == ImageStore.limit)
        #expect(survivors.contains(names.last!))
        #expect(survivors.contains(names.first!) == false)
    }

    @Test func eraseEmptiesTheFolder() throws {
        let (store, folder) = try store()
        _ = try store.save(contentsOf: try sourceFile())
        store.eraseAllStoredData()
        #expect(FileManager.default.fileExists(atPath: folder.path) == false)
    }
}
```

- [ ] **Step 2: Jalankan dan pastikan gagal**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/ImageStoreTests 2>&1 | grep -E "error:" | head -3`
Expected: `cannot find 'ImageStore' in scope`.

- [ ] **Step 3: Tulis implementasinya**

```swift
//
//  ImageStore.swift
//  Apl
//
//  Gambar yang dibuat lewat Image Playground, tersimpan di container app
//  (spec G §4).
//
//  Nama berkasnya UUID, bukan potongan kalimat: konsep yang diketik bisa
//  berisi apa saja, dan menuliskannya jadi nama berkas berarti menaruh isi
//  percakapan ke dalam sistem berkas tanpa alasan.
//

import Foundation

@MainActor
final class ImageStore {

    /// Pagar keras, di atas aturan "hanya yang dirujuk percakapan".
    static let limit = 20

    private let folder: URL

    init(folder: URL) {
        self.folder = folder
    }

    /// Menyalin bytes apa adanya — tanpa kompresi ulang (spec G §2 #6).
    func save(contentsOf url: URL) throws -> String {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = "\(UUID().uuidString).png"
        try FileManager.default.copyItem(at: url, to: folder.appendingPathComponent(name))
        return name
    }

    func url(for name: String) -> URL? {
        let candidate = folder.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }

    /// Membuang yang tidak dirujuk pesan mana pun, lalu menegakkan pagar 20
    /// dengan menyisakan yang terbaru.
    func prune(keeping names: Set<String>) {
        let manager = FileManager.default
        guard let files = try? manager.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }

        var kept: [(url: URL, date: Date)] = []
        for file in files {
            guard names.contains(file.lastPathComponent) else {
                try? manager.removeItem(at: file)
                continue
            }
            let date = (try? file.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate) ?? .distantPast
            kept.append((file, date))
        }

        guard kept.count > Self.limit else { return }
        for old in kept.sorted(by: { $0.date > $1.date }).dropFirst(Self.limit) {
            try? manager.removeItem(at: old.url)
        }
    }
}

extension ImageStore: LocallyErasable {
    func eraseAllStoredData() {
        try? FileManager.default.removeItem(at: folder)
    }
}
```

- [ ] **Step 4: Jalankan dan pastikan lulus**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/ImageStoreTests 2>&1 | grep -E "Test run with|TEST"`
Expected: PASS (5 test).

Kalau `hardCapKeepsTheNewest` gagal karena beberapa berkas berbagi detik yang sama,
tambahkan `try await Task.sleep(for: .milliseconds(1100))`? **Jangan.** Ubah testnya
menjadi `@Test func` biasa yang menyetel tanggal ubah secara eksplisit:

```swift
        for (index, name) in names.enumerated() {
            let url = store.url(for: name)!
            try FileManager.default.setAttributes(
                [.modificationDate: Date(timeIntervalSince1970: 1_700_000_000 + Double(index))],
                ofItemAtPath: url.path)
        }
```
sisipkan sebelum `store.prune(keeping:)`. Waktu yang dikarang selalu lebih baik daripada
test yang menunggu.

- [ ] **Step 5: Commit**

```bash
git add DinoPocketMac/Infrastructure/Persistence/ImageStore.swift DinoPocketTests/ImageStoreTests.swift
git commit -m "$(cat <<'EOF'
feat(g): penyimpanan gambar yang dijaga sebagai fungsi dari percakapan

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Lampiran gambar pada pesan

**Files:**
- Modify: `SharedCore/Data/Models/ChatMessage.swift`,
  `DinoPocketMac/Presentation/Chat/MessageRow.swift`
- Test: `DinoPocketTests/ChatMessageTests.swift`, `DinoPocketTests/MessageRowTests.swift`

**Interfaces:**
- Produces: `ChatMessage.Attachment.picture(name: String, concept: String)`,
  `MessageRowKind.picture(name: String, concept: String)`.

Bentuk baris dipilih dari **data**, bukan dari bunyi teks — aturan yang sudah berlaku sejak
B dan alasan chip reminder tidak pernah ditebak dari kalimat konfirmasi.

- [ ] **Step 1: Tulis test yang gagal**

Tambahkan ke `DinoPocketTests/ChatMessageTests.swift`:

```swift
    /// Percakapan yang tersimpan SEBELUM G tetap terbaca: `attachment` sudah
    /// `decodeIfPresent` sejak B, dan case baru tidak boleh merusak itu.
    @Test func oldConversationsStillDecode() throws {
        let json = """
        {"id":"\(UUID().uuidString)","role":"assistant","text":"Done",
         "date":768000000,"status":"complete"}
        """.data(using: .utf8)!
        let message = try JSONDecoder().decode(ChatMessage.self, from: json)
        #expect(message.attachment == nil)
    }

    @Test func pictureAttachmentRoundTrips() throws {
        let original = ChatMessage(role: .assistant, text: "",
                                   attachment: .picture(name: "a.png", concept: "an orange cat"))
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(ChatMessage.self, from: data)
        #expect(restored.attachment == .picture(name: "a.png", concept: "an orange cat"))
    }
```

Tambahkan ke `DinoPocketTests/MessageRowTests.swift`:

```swift
    @Test func pictureAttachmentPicksThePictureRow() {
        let message = ChatMessage(role: .assistant, text: "",
                                  attachment: .picture(name: "a.png", concept: "an orange cat"))
        #expect(MessageRow.kind(of: message) == .picture(name: "a.png", concept: "an orange cat"))
    }

    /// Gambar yang gagal tetap kalah oleh status gagal: yang perlu dilihat
    /// pengguna adalah kegagalannya.
    @Test func failureStillWins() {
        let message = ChatMessage(role: .assistant, text: "", status: .failed,
                                  attachment: .picture(name: "a.png", concept: "a cat"))
        #expect(MessageRow.kind(of: message) == .failed)
    }
```

- [ ] **Step 2: Jalankan dan pastikan gagal**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/MessageRowTests 2>&1 | grep -E "error:" | head -3`
Expected: `type 'ChatMessage.Attachment' has no member 'picture'`.

Catatan: `ChatMessage(role:text:status:attachment:)` — urutan argumen init yang ada adalah
`(id:role:text:date:attachment:status:)`. Tulis pemanggilannya sesuai urutan itu:
`ChatMessage(role: .assistant, text: "", attachment: .picture(...), status: .failed)`.

- [ ] **Step 3: Tambahkan case lampiran**

Di `SharedCore/Data/Models/ChatMessage.swift`, di dalam `enum Attachment`:

```swift
        /// Gambar yang dibuat lewat Image Playground (spec G §3). Nama berkas
        /// dan konsepnya disimpan bersama: konsepnya yang dibacakan VoiceOver
        /// dan ditampilkan sebagai keterangan.
        case picture(name: String, concept: String)
```

- [ ] **Step 4: Tambahkan kind dan barisnya**

Di `MessageRow.swift`, tambahkan case ke `MessageRowKind`:

```swift
    case picture(name: String, concept: String)
```

dan di `kind(of:)`, **sesudah** pemeriksaan `status == .failed` dan sebaris dengan
pemeriksaan reminder:

```swift
        if case .picture(let name, let concept)? = message.attachment {
            return .picture(name: name, concept: concept)
        }
```

Di `body`, tambahkan cabangnya (view-nya ditulis di Task 5; untuk sementara pakai
`Text(concept)` supaya tugas ini bisa dikompilasi dan diuji sendiri):

```swift
        case .picture(let name, let concept):
            PictureBubble(name: name, concept: concept, store: imageStore)
```

Karena `PictureBubble` belum ada, **Task 4 berhenti di `kind(of:)`**: biarkan `body`
memakai `AssistantMessage(text: concept)` dulu, dan Task 5 yang menggantinya. Tulis
komentar satu baris di sana supaya tidak tertinggal:

```swift
        case .picture(_, let concept):
            // Sementara sampai Task 5: gelembung gambarnya belum ada.
            AssistantMessage(text: concept)
```

- [ ] **Step 5: Jalankan dan pastikan lulus**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' 2>&1 | grep -E "error:|Test run with"`
Expected: seluruh suite lulus.

- [ ] **Step 6: Commit**

```bash
git add SharedCore/Data/Models/ChatMessage.swift DinoPocketMac/Presentation/Chat/MessageRow.swift DinoPocketTests/ChatMessageTests.swift DinoPocketTests/MessageRowTests.swift
git commit -m "$(cat <<'EOF'
feat(g): lampiran gambar pada pesan, tanpa merusak percakapan lama

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Gelembung gambar dan suaranya

**Files:**
- Create: `DinoPocketMac/Presentation/Picture/PictureBubble.swift`
- Modify: `DinoPocketMac/Presentation/Chat/AnswerAnnouncement.swift`,
  `DinoPocketMac/Presentation/Chat/MessageRow.swift`,
  `DinoPocketMac/Presentation/Chat/ConversationView.swift`
- Test: `DinoPocketTests/AnswerAnnouncementTests.swift`

**Interfaces:**
- Consumes: `ImageStore` (Task 3), `MessageRowKind.picture` (Task 4).
- Produces: `PictureBubble(name:concept:store:)`; `MessageRow(message:reminders:imageStore:canRetry:onRetry:)`.

- [ ] **Step 1: Tulis test yang gagal**

Tambahkan ke `DinoPocketTests/AnswerAnnouncementTests.swift`:

```swift
    /// Gambar tanpa label adalah lubang di percakapan bagi yang tidak
    /// melihatnya. Teks pesannya kosong, jadi konsepnyalah yang dibacakan.
    @Test func picturesAreAnnouncedByTheirConcept() {
        let messages = [ChatMessage(role: .user, text: "gambarkan kucing oranye"),
                        ChatMessage(role: .assistant, text: "",
                                    attachment: .picture(name: "a.png", concept: "kucing oranye"))]
        #expect(AnswerAnnouncement.text(messages: messages, isStreaming: false)
                == "Image of kucing oranye")
    }
```

- [ ] **Step 2: Jalankan dan pastikan gagal**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/AnswerAnnouncementTests 2>&1 | grep -E "error:|recorded an issue" | head -3`
Expected: gagal — fungsi itu mengembalikan `nil` untuk pesan berteks kosong.

- [ ] **Step 3: Ajari pengumumannya mengenali gambar**

Di `AnswerAnnouncement.text(messages:isStreaming:)`, **sebelum** baris terakhir
`return last.text.isEmpty ? nil : last.text`:

```swift
        if case .picture(_, let concept)? = last.attachment {
            return "Image of \(concept)"
        }
```

- [ ] **Step 4: Tulis `PictureBubble`**

```swift
//
//  PictureBubble.swift
//  Apl
//
//  Gambar di dalam percakapan (spec G §3, §4).
//
//  Pesannya tidak berteks: gambarnya sudah ada di sana, dan menambahkan
//  "Here's your image" hanya menambah baris yang harus dibaca. Konsepnya
//  tampil sebagai keterangan kecil, dan itu pula yang dibacakan VoiceOver.
//

import AppKit
import SwiftUI

struct PictureBubble: View {
    let name: String
    let concept: String
    let store: ImageStore

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let url = store.url(for: name), let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 320, maxHeight: 320)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .strokeBorder(.separator))
                    .accessibilityLabel("Image of \(concept)")
                HStack(spacing: Spacing.sm) {
                    Text(concept)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Save") { save(url) }
                        .buttonStyle(.link)
                        .font(.caption)
                }
            } else {
                // Berkasnya sudah dipangkas atau dihapus pengguna. Satu baris
                // tenang, bukan ruang kosong dan bukan tanda seru.
                Label("Image no longer stored", systemImage: "photo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func save(_ url: URL) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Apl image \(Date.now.formatted(.dateTime.year().month().day())).png"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        try? FileManager.default.removeItem(at: destination)
        try? FileManager.default.copyItem(at: url, to: destination)
    }
}

#Preview("Gambar hilang") {
    PictureBubble(name: "tidak-ada.png", concept: "an orange cat",
                  store: ImageStore(folder: FileManager.default.temporaryDirectory
                      .appendingPathComponent("apl.preview.images", isDirectory: true)))
        .padding(Spacing.xl)
}
```

- [ ] **Step 5: Sambungkan ke baris pesan**

Di `MessageRow.swift`, tambahkan properti `let imageStore: ImageStore` dan ganti cabang
sementara dari Task 4 menjadi:

```swift
        case .picture(let name, let concept):
            PictureBubble(name: name, concept: concept, store: imageStore)
```

Di `ConversationView.swift`, tambahkan `let imageStore: ImageStore` dan teruskan ke
`MessageRow(message:reminders:imageStore:canRetry:onRetry:)`. Perbarui juga ketiga
`#Preview` di `MessageRow.swift` dan `ConversationView.swift` dengan
`ImageStore(folder: FileManager.default.temporaryDirectory.appendingPathComponent("apl.preview.images", isDirectory: true))`.

- [ ] **Step 6: Jalankan seluruh suite**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' 2>&1 | grep -E "error:|Test run with"`
Expected: seluruh suite lulus.

- [ ] **Step 7: Commit**

```bash
git add DinoPocketMac/Presentation/Picture/PictureBubble.swift DinoPocketMac/Presentation/Chat DinoPocketTests/AnswerAnnouncementTests.swift
git commit -m "$(cat <<'EOF'
feat(g): gelembung gambar, beserta labelnya untuk VoiceOver

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Jalur menggambar di ChatStore

**Files:**
- Modify: `DinoPocketMac/Presentation/ViewModels/ChatStore.swift`
- Test: `DinoPocketTests/PictureWithoutBrainTests.swift`

**Interfaces:**
- Consumes: `DrawCommand.concept(in:)` (Task 1), `PictureRequest` (Task 2).
- Produces: `ChatStore.pictureRequested: ((PictureRequest) -> Void)?`,
  `ChatStore.appendPicture(name:concept:)`, `ChatStore.pictureNames: Set<String>`.

- [ ] **Step 1: Tulis test yang gagal**

```swift
import Foundation
import Testing
@testable import Apl

@MainActor
struct PictureWithoutBrainTests {

    private func store() -> ChatStore {
        ChatStore(brain: nil, defaults: UserDefaults(suiteName: "test.picture.\(UUID())")!)
    }

    /// Janji spec G §2 #1: jalur menggambar tidak pernah menyentuh model.
    /// `brain: nil` membuat jalur model gagal keras.
    @Test func drawingNeverReachesTheModel() async {
        let chat = store()
        var asked: PictureRequest?
        chat.pictureRequested = { asked = $0 }

        await chat.send("gambarkan kucing oranye")

        #expect(asked?.concept == "kucing oranye")
        #expect(asked?.sourceImage == nil)
        #expect(chat.noticeMessage == nil)
        #expect(chat.isStreaming == false)
    }

    /// Spec G §2 #5: tidak ada kalimat jawaban saat sheet dibuka. Yang ada di
    /// percakapan hanyalah kalimat pengguna sendiri.
    @Test func aplSaysNothingUntilThereIsAnImage() async {
        let chat = store()
        chat.pictureRequested = { _ in }

        await chat.send("gambarkan kucing oranye")

        #expect(chat.messages.count == 1)
        #expect(chat.messages.first?.role == .user)
    }

    @Test func appendingAPictureAttachesIt() async {
        let chat = store()
        chat.pictureRequested = { _ in }
        await chat.send("gambarkan kucing oranye")

        chat.appendPicture(name: "a.png", concept: "kucing oranye")

        #expect(chat.messages.last?.role == .assistant)
        #expect(chat.messages.last?.text.isEmpty == true)
        #expect(chat.messages.last?.attachment == .picture(name: "a.png", concept: "kucing oranye"))
        #expect(chat.pictureNames == ["a.png"])
    }

    /// Tanpa pemasangan, kalimatnya bukan urusan siapa-siapa dan harus
    /// diteruskan seperti pesan biasa.
    @Test func withoutAHandlerTheSentenceGoesOnAsUsual() async {
        let chat = store()
        await chat.send("gambarkan kucing oranye")
        #expect(chat.noticeMessage == ChatStore.unavailableNotice)
    }
}
```

- [ ] **Step 2: Jalankan dan pastikan gagal**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/PictureWithoutBrainTests 2>&1 | grep -E "error:" | head -3`
Expected: `value of type 'ChatStore' has no member 'pictureRequested'`.

- [ ] **Step 3: Tambahkan jalurnya**

Di `ChatStore`, dekat `playRequested`:

```swift
    /// Ajakan menggambar. Dipasang app; `nil` berarti tidak ada yang bisa
    /// membuka sheet, dan kalimatnya diteruskan seperti pesan biasa.
    var pictureRequested: ((PictureRequest) -> Void)?
```

Di `send(_:)`, **sesudah** blok "main suit" dan **sebelum** `await streamReply()`:

```swift
        // Ajakan menggambar juga ditangani lokal (spec G §2 #1). Tidak ada
        // kalimat jawaban di sini: pesan Apl baru ada kalau gambarnya benar-
        // benar jadi (spec G §2 #5).
        if let pictureRequested, let concept = DrawCommand.concept(in: trimmed) {
            noticeMessage = nil
            persistRecent()
            pictureRequested(PictureRequest(concept: concept, sourceImage: nil))
            return
        }
```

Dan dua anggota baru:

```swift
    /// Menyisipkan gambar yang sudah tersimpan sebagai pesan Apl. Teksnya
    /// kosong dengan sengaja; lampirannya yang membawa arti.
    func appendPicture(name: String, concept: String) {
        finalizeInterruptedAssistant()
        messages.append(ChatMessage(role: .assistant, text: "", date: now(),
                                    attachment: .picture(name: name, concept: concept)))
        persistRecent()
    }

    /// Nama berkas yang masih dirujuk percakapan — dipakai `ImageStore.prune`.
    var pictureNames: Set<String> {
        Set(messages.compactMap {
            if case .picture(let name, _)? = $0.attachment { return name }
            return nil
        })
    }
```

- [ ] **Step 4: Jalankan dan pastikan lulus**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/PictureWithoutBrainTests 2>&1 | grep -E "Test run with|TEST"`
Expected: PASS (4 test).

- [ ] **Step 5: Commit**

```bash
git add DinoPocketMac/Presentation/ViewModels/ChatStore.swift DinoPocketTests/PictureWithoutBrainTests.swift
git commit -m "$(cat <<'EOF'
feat(g): jalur menggambar ditangani lokal, dan Apl diam sampai gambarnya ada

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Sheet, menu, dan pemasangan

**Files:**
- Modify: `DinoPocketMac/Presentation/Chat/Composer.swift`,
  `DinoPocketMac/Presentation/Chat/ConversationView.swift`,
  `DinoPocketMac/Presentation/Window/MainWindow.swift`,
  `DinoPocketMac/App/AplApp.swift`, `DinoPocketMac/App/AppDependencies.swift`,
  `project.yml` (hanya bila linker mengeluh)

**Interfaces:**
- Consumes: semua unit Task 1–6.
- Produces: `Composer.picture: PictureMenuActions?`, `AppDependencies.imageStore`.

- [ ] **Step 1: Menu di composer**

Di `Composer.swift`, tambahkan tipe dan properti:

```swift
/// Menu gambar di composer. `nil` berarti tidak ada — bubble ⌥Space memakai
/// composer yang sama, dan sheet tidak punya jendela untuk ditempelkan di sana
/// (spec G §2 #3).
struct PictureMenuActions {
    let isEnabled: Bool
    let describe: () -> Void
    let usePhoto: () -> Void
}
```

```swift
    var picture: PictureMenuActions?
```

dan di dalam `HStack` `body`, **sebelum** `TextField`:

```swift
            if let picture {
                Menu {
                    Button("Describe an image…", action: picture.describe)
                    Button("Use a photo…", action: picture.usePhoto)
                } label: {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 13))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 22)
                .disabled(!picture.isEnabled)
                .help(picture.isEnabled
                      ? "Create an image"
                      : "Image Playground isn't available yet")
                .accessibilityLabel("Create an image")
                .padding(.bottom, 9)
            }
```

- [ ] **Step 2: Sheet di ConversationView**

Tambahkan `import ImagePlayground`, `import AppKit`, dan `import UniformTypeIdentifiers` di
kepala berkas, lalu empat properti:

```swift
    let pictures: PictureSession
    let imageStore: ImageStore
    /// Menu dinonaktifkan (bukan disembunyikan) saat Image Playground belum
    /// tersedia — kontrol yang lenyap tidak mengajarkan apa-apa (spec G §5).
    var pictureIsAvailable = true
    /// Dipanggil saat sheet selesai: URL sementara dari Apple, beserta konsep
    /// yang diminta. Penyalinan dan pemangkasannya milik `AplApp`.
    let onPictureCreated: (URL, String) -> Void
```

Pasang sheet-nya pada `VStack` terluar `body`, di bawah `.announcesAnswers(...)`:

```swift
        // Varian `concepts:` dipakai untuk KEDUA jalur: array kosong berarti
        // sheet terbuka tanpa konsep, dan itu persis yang diminta menu
        // "Describe an image…".
        .imagePlaygroundSheet(
            isPresented: Binding(get: { pictures.request != nil },
                                 set: { if !$0 { pictures.finish() } }),
            concepts: pictures.request.map { request in
                request.concept.isEmpty ? [] : [ImagePlaygroundConcept.text(request.concept)]
            } ?? [],
            sourceImage: pictures.request?.sourceImage
                .flatMap { NSImage(contentsOf: $0) }
                .map { Image(nsImage: $0) },
            onCompletion: { url in
                let concept = pictures.request?.concept ?? ""
                pictures.finish()
                onPictureCreated(url, concept)
            },
            onCancellation: { pictures.finish() }
        )
```

Composer-nya menerima menunya:

```swift
                Composer(draft: $draft, state: composerState,
                         onSend: { send() },
                         onStop: { chat.stopStreaming() },
                         focus: composerFocus,
                         picture: PictureMenuActions(
                            isEnabled: pictureIsAvailable,
                            describe: { pictures.start(PictureRequest(concept: "", sourceImage: nil)) },
                            usePhoto: { choosePhoto() }))
```

dan satu fungsi privat:

```swift
    /// Panel dibatasi ke gambar, jadi yang salah jenis tidak bisa dipilih sejak
    /// awal. Yang tidak terbaca sama sekali dikatakan sebelum sheet dibuka
    /// (spec G §5).
    private func choosePhoto() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        panel.prompt = "Use Photo"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard NSImage(contentsOf: url) != nil else {
            chat.appendAssistantNote("I couldn't read that image.")
            return
        }
        pictures.start(PictureRequest(concept: "", sourceImage: url))
    }
```

Perbarui ketiga `#Preview` di berkas ini dengan `pictures: PictureSession()`,
`imageStore: ImageStore(folder: FileManager.default.temporaryDirectory.appendingPathComponent("apl.preview.images", isDirectory: true))`,
dan `onPictureCreated: { _, _ in }`.

- [ ] **Step 3: Pasang di app**

`AppDependencies`: tambahkan `let imageStore: ImageStore`, buat dengan
`ImageStore(folder: AppDependencies.imagesFolder())`, masukkan ke `erasable`, dan tambahkan:

```swift
    /// Gambar tinggal di container app, bersebelahan dengan cadangan Code.
    static func imagesFolder() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Apl/Images", isDirectory: true)
    }
```

`AplApp`: tambahkan `@State private var pictures = PictureSession()`, teruskan
`pictures`, `Self.deps.imageStore`, ketersediaan, dan penanganan hasil ke `MainWindow`,
lalu pasang jalurnya di `.task` yang sama dengan `chat.playRequested`:

```swift
            chat.pictureRequested = { request in
                guard PictureAvailability.decide(
                        isAvailable: ImagePlaygroundViewController.isAvailable) == .ready else {
                    chat.appendAssistantNote(PictureAvailability.unavailableNotice)
                    return
                }
                _ = pictures.start(request)
            }
```

dan fungsi penerima hasilnya:

```swift
    /// URL dari Apple hidup di tempat sementara; kalau menyalinnya gagal, Apl
    /// mengatakannya alih-alih menaruh lampiran rusak (spec G §5).
    private func keepPicture(at url: URL, concept: String) {
        do {
            let name = try Self.deps.imageStore.save(contentsOf: url)
            chat.appendPicture(name: name, concept: concept)
            Self.deps.imageStore.prune(keeping: chat.pictureNames)
        } catch {
            chat.appendAssistantNote("I couldn't keep that image.")
        }
    }
```

`MainWindow`: tambahkan properti yang sama (`pictures`, `imageStore`, `pictureIsAvailable`,
`onPictureCreated`) dan teruskan ke `ConversationView`; `pictureIsAvailable` diisi
`ImagePlaygroundViewController.isAvailable` dari `AplApp`, dan `onPictureCreated` diisi
`keepPicture(at:concept:)`. Ketiga `#Preview` di `MainWindow.swift` ikut diperbarui dengan
nilai preview yang sama seperti di `ConversationView.swift`. Bubble ⌥Space **tidak**
menerima satu pun dari ini (spec G §2 #3).

- [ ] **Step 4: Build, dan hanya bila linker mengeluh**

Run: `xcodegen generate && xcodebuild build -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' 2>&1 | grep -E "error:|BUILD" | head -5`

Autolink Swift biasanya cukup. Bila muncul `ld: framework 'ImagePlayground' not found` atau
simbol yang hilang, tambahkan ke target `DinoPocketMac` di `project.yml`:

```yaml
    dependencies:
      - sdk: ImagePlayground.framework
```

- [ ] **Step 5: Seluruh suite, pemeriksa, entitlements**

Run: `xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' 2>&1 | grep -E "error:|Test run with"`
Run: `./scripts/verify-boundaries.sh && ./scripts/verify-release.sh 2>&1 | tail -3`
Run: `git diff project.yml | grep -i entitle || echo "(tidak ada entitlement baru)"`
Expected: suite lulus, kedua pemeriksa hijau, tidak ada entitlement baru.

**Periksa juga Release**, karena `#Preview` ikut dikompilasi di sana — pelajaran dari F:

Run: `xcodebuild build -project DinoPocket.xcodeproj -scheme DinoPocketMac -configuration Release -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD" | head -3`

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
feat(g): sheet Image Playground, menu composer, dan pemasangannya

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Verifikasi manual dan catatan

- [ ] **Step 1: Daftar periksa spec §6**

1. Ketik "gambarkan kucing oranye" → sheet terbuka dengan konsep sudah terisi.
2. Pilih satu gambar → ia masuk percakapan **tanpa** kalimat pengantar.
3. Tutup app, buka lagi → gambarnya masih ada di percakapan.
4. **Save** menulis berkas ke folder pilihan.
5. Menu composer: "Describe an image…" membuka sheet kosong; "Use a photo…" membuka panel,
   dan foto yang dipilih terpakai sebagai dasar.
6. Batalkan sheet → percakapan hanya berisi kalimat yang kamu ketik, tanpa jawaban.
7. "remind me to draw the logo at 4pm" → tetap **reminder**.
8. "how do I draw a circle in SwiftUI?" → tetap pertanyaan ke model.
9. **Erase All Data** → folder `Application Support/Apl/Images/` hilang.
10. **VoiceOver** membaca gambar sebagai "Image of ⟨konsep⟩".
11. Regresi: reminder, "main suit", sisi Code, ⌥Space, dan sapaan proaktif tidak berubah.

- [ ] **Step 2: Satu item milik pemiliknya**

Mematikan Apple Intelligence untuk melihat kalimat "Image Playground isn't available yet"
dan menu yang nonaktif. **Jangan** menyentuh pengaturan sistem dari sesi ini — minta
pemiliknya melakukannya dan laporkan hasilnya.

- [ ] **Step 3: Perbaiki temuan, satu commit per temuan**

- [ ] **Step 4: Tulis hasilnya** di plan ini dan tandai DoD di spec §7.

---

## Self-review

**Cakupan spec.** §2 #1 → Task 1 dan 6 (`PictureWithoutBrainTests`); #2 → Task 1 (ketik)
dan Task 7 Step 1–2 (menu dua baris); #3 → Task 7 Step 3 (bubble tidak menerima apa pun);
#4 → Task 3 dan 6; #5 → Task 6 (`aplSaysNothingUntilThereIsAnImage`); #6 → Task 3
(`save` menyalin apa adanya); #7 → Task 7 Step 5. §3 → Task 2, 4, 5, 6. §4 → Task 3 dan
Task 5 (baris "Image no longer stored", tombol Save). §5 → Task 2
(`unavailableNotice`), Task 7 (pemeriksaan sebelum membuka, `choosePhoto`, `keepPicture`),
Task 5 (VoiceOver). §6 → Task 1–6 untuk unit, Task 8 untuk manual. §7 → Task 8 Step 4.

**Placeholder.** Setiap langkah kode memuat kodenya. Yang berupa prosa adalah penyisipan
mekanis ke berkas yang sudah ada, dan semuanya menyebut berkas, tempat sisipan, serta nama
yang dipakai. Task 4 sengaja memakai baris sementara `AssistantMessage(text: concept)` dan
Task 5 menggantinya — itu ditulis eksplisit di kedua tugas, bukan ditinggalkan.

**Konsistensi.** `PictureRequest(concept:sourceImage:)` dibuat Task 2 dan dipakai Task 6
dan 7. `PictureSession.start` mengembalikan `Bool` di ketiganya. `ImageStore.save`
mengembalikan **nama**, bukan URL, dan itulah yang disimpan `ChatStore.appendPicture` dan
dibaca `PictureBubble`. `ChatStore.pictureNames` (Task 6) persis yang diminta
`ImageStore.prune(keeping:)` (Task 3). `MessageRowKind.picture(name:concept:)` (Task 4)
sama persis dengan `ChatMessage.Attachment.picture(name:concept:)`.

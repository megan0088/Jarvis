# Apl E — Sisi Code — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Jendela utama punya ruang kedua bernama Code: Anda menunjuk folder dan berkas,
bertanya, dan Apl boleh menulis berkas itu — dengan anggaran token yang terlihat dan jalan
kembali yang selalu ada.

**Architecture:** Empat unit murni memikul seluruh keputusan (penyaringan berkas, anggaran
token, pemeriksaan jawaban, instructions). Di sekelilingnya: bookmark folder, penulis
berkas dengan cadangan, percakapan kedua dengan otak kedua, dan satu tampilan.

**Tech Stack:** Swift 6, SwiftUI, Foundation Models (`LanguageModelSession`), security-scoped
bookmark, Swift Testing, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-09-21-apl-code-side-design.md`

## Global Constraints

- **Tidak ada entitlement baru.** `ENABLE_USER_SELECTED_FILES: readwrite` sudah ada;
  `project.yml` tidak boleh bertambah izin (spec §2 #7, §9).
- **Otak tetap on-device.** Tidak ada panggilan jaringan, tidak ada kunci API.
- Target **macOS 26+**, `SWIFT_VERSION: 6.0`, semua tipe UI `@MainActor`.
- **XcodeGen**: jalankan `xcodegen generate` setelah menambah berkas.
- Test host `Apl.app`: setiap test yang menyentuh `UserDefaults` WAJIB memakai suite
  terisolasi; setiap test yang menyentuh disk memakai folder sementara sendiri.
- `SharedCore` tidak boleh mengimpor SwiftUI/AppKit.
- Teks antarmuka **Inggris**, komentar dan dokumen **Indonesia**.
- Setiap commit diakhiri `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.

## File Structure

**Dibuat** (`DinoPocketMac/Presentation/Code/` kecuali disebut lain): `WorkspaceFile.swift`,
`WorkspaceListing.swift`, `ContextBudget.swift`, `CodeAnswer.swift`, `CodeView.swift`,
`FileChip.swift`; `SharedCore/Infrastructure/Services/CodeInstructions.swift`;
`DinoPocketMac/Infrastructure/Persistence/CodeWorkspace.swift`;
`DinoPocketMac/Infrastructure/Services/FileWriter.swift`.

**Diubah:** `SharedCore/Infrastructure/Services/AppleBrain.swift` (instructions jadi
parameter), `DinoPocketMac/Presentation/ViewModels/ChatStore.swift` (kunci penyimpanan jadi
parameter), `MainWindow.swift` (pemilih Chat | Code), `AppDependencies.swift`, `AplApp.swift`.

**Test:** `WorkspaceListingTests.swift`, `ContextBudgetTests.swift`, `CodeAnswerTests.swift`,
`CodeInstructionsTests.swift`, `FileWriterTests.swift`, `CodeWorkspaceTests.swift`,
`SecondBrainTests.swift`.

---

### Task 1: Daftar berkas yang masuk akal

**Files:**
- Create: `DinoPocketMac/Presentation/Code/WorkspaceFile.swift`,
  `DinoPocketMac/Presentation/Code/WorkspaceListing.swift`
- Test: `DinoPocketTests/WorkspaceListingTests.swift`

**Interfaces:**
- Produces: `WorkspaceFile` (`relativePath`, `byteCount`, `id`, `name`),
  `WorkspaceListing.Entry` (`relativePath`, `byteCount`, `isDirectory`),
  `WorkspaceListing.filter(_:) -> [WorkspaceFile]`, konstanta `skippedDirectories`,
  `maxFileBytes`, `textExtensions`.

- [ ] **Step 1: Tulis test yang gagal**

```swift
import Testing
@testable import Apl

struct WorkspaceListingTests {

    private func entry(_ path: String, bytes: Int = 100, dir: Bool = false) -> WorkspaceListing.Entry {
        WorkspaceListing.Entry(relativePath: path, byteCount: bytes, isDirectory: dir)
    }

    @Test func keepsSourceFiles() {
        let files = WorkspaceListing.filter([entry("Sources/App.swift"), entry("README.md")])
        #expect(files.map(\.relativePath) == ["README.md", "Sources/App.swift"])
    }

    @Test func directoriesNeverAppear() {
        #expect(WorkspaceListing.filter([entry("Sources", dir: true)]).isEmpty)
    }

    /// Folder yang isinya bukan tulisan manusia: membiarkannya membuat daftar
    /// berisi ribuan berkas yang tidak akan pernah ditunjuk siapa pun.
    @Test func skipsGeneratedAndVendoredFolders() {
        let noisy = [".git/config", "build/App.o", "DerivedData/x.swift",
                     "node_modules/left-pad/index.js", "Pods/Lib/Lib.swift",
                     ".build/debug/App.swift"]
        #expect(WorkspaceListing.filter(noisy.map { entry($0) }).isEmpty)
    }

    @Test func skipsHiddenFilesAnywhereInThePath() {
        #expect(WorkspaceListing.filter([entry(".env"), entry("Sources/.secret/key.swift")]).isEmpty)
    }

    @Test func skipsBinariesByExtension() {
        #expect(WorkspaceListing.filter([entry("Assets/logo.png"), entry("App.usdz")]).isEmpty)
    }

    /// Berkas raksasa tidak akan pernah muat di konteks; menampilkannya hanya
    /// mengundang penolakan di langkah berikutnya.
    @Test func skipsFilesLargerThanTheCap() {
        #expect(WorkspaceListing.filter([entry("Big.swift", bytes: WorkspaceListing.maxFileBytes + 1)]).isEmpty)
        #expect(WorkspaceListing.filter([entry("Ok.swift", bytes: WorkspaceListing.maxFileBytes)]).count == 1)
    }

    @Test func sortedByPath() {
        let files = WorkspaceListing.filter([entry("b.swift"), entry("a.swift"), entry("A/z.swift")])
        #expect(files.map(\.relativePath) == ["A/z.swift", "a.swift", "b.swift"])
    }

    @Test func nameIsTheLastComponent() {
        #expect(WorkspaceListing.filter([entry("Sources/App/Main.swift")]).first?.name == "Main.swift")
    }
}
```

- [ ] **Step 2: Jalankan dan pastikan gagal**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/WorkspaceListingTests 2>&1 | grep -E "error:" | head -3`
Expected: `cannot find 'WorkspaceListing' in scope`.

- [ ] **Step 3: Tulis `WorkspaceFile`**

```swift
//
//  WorkspaceFile.swift
//  Apl
//
//  Satu berkas di folder kerja (spec E §5).
//

struct WorkspaceFile: Equatable, Identifiable, Hashable {
    let relativePath: String
    let byteCount: Int

    var id: String { relativePath }
    var name: String { relativePath.split(separator: "/").last.map(String.init) ?? relativePath }
}
```

- [ ] **Step 4: Tulis `WorkspaceListing`**

```swift
//
//  WorkspaceListing.swift
//  Apl
//
//  Menyaring isi folder jadi daftar yang masuk akal dibicarakan (spec E §5).
//
//  Murni: penelusuran disk terjadi di `CodeWorkspace`, aturan penyaringannya di
//  sini — supaya "apa yang dilewati" bisa dibuktikan tanpa folder sungguhan.
//

import Foundation

enum WorkspaceListing {

    struct Entry: Equatable {
        let relativePath: String
        let byteCount: Int
        var isDirectory = false
    }

    /// Folder yang isinya hasil generate, unduhan, atau riwayat — bukan tulisan
    /// yang akan dibicarakan seseorang.
    static let skippedDirectories: Set<String> = [
        ".git", ".build", ".swiftpm", "build", "DerivedData",
        "node_modules", "Pods", "Carthage", ".venv", "venv", "__pycache__",
    ]

    /// Di atas ini tidak akan pernah muat di konteks (spec E §4).
    static let maxFileBytes = 200_000

    static let textExtensions: Set<String> = [
        "swift", "m", "mm", "h", "hpp", "c", "cc", "cpp", "java", "kt", "go", "rs",
        "js", "jsx", "ts", "tsx", "py", "rb", "php", "sh", "zsh", "bash",
        "json", "yml", "yaml", "toml", "xml", "plist", "md", "txt", "css", "scss", "html", "sql",
    ]

    static func filter(_ entries: [Entry]) -> [WorkspaceFile] {
        entries
            .filter { !$0.isDirectory }
            .filter { entry in
                let parts = entry.relativePath.split(separator: "/").map(String.init)
                guard !parts.contains(where: { $0.hasPrefix(".") }) else { return false }
                guard !parts.dropLast().contains(where: skippedDirectories.contains) else { return false }
                guard entry.byteCount <= maxFileBytes else { return false }
                let ext = (entry.relativePath as NSString).pathExtension.lowercased()
                return textExtensions.contains(ext)
            }
            .map { WorkspaceFile(relativePath: $0.relativePath, byteCount: $0.byteCount) }
            .sorted { $0.relativePath < $1.relativePath }
    }
}
```

- [ ] **Step 5: Jalankan dan pastikan lulus**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/WorkspaceListingTests 2>&1 | grep -E "Test run with|TEST"`
Expected: PASS (8 test).

- [ ] **Step 6: Commit**

```bash
git add DinoPocketMac/Presentation/Code DinoPocketTests/WorkspaceListingTests.swift
git commit -m "$(cat <<'EOF'
feat(e): daftar berkas yang masuk akal dibicarakan

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Anggaran token

**Files:**
- Create: `DinoPocketMac/Presentation/Code/ContextBudget.swift`
- Test: `DinoPocketTests/ContextBudgetTests.swift`

**Interfaces:**
- Consumes: `WorkspaceFile` (Task 1).
- Produces: `ContextBudget.limit` (1.600), `.charactersPerToken` (3,5),
  `.tokens(forCharacters:)`, `.tokens(for:)`, `.used(_:)`, `.remaining(after:)`,
  `.canAdd(_:to:)`.

- [ ] **Step 1: Tulis test yang gagal**

```swift
import Testing
@testable import Apl

struct ContextBudgetTests {

    private func file(_ bytes: Int) -> WorkspaceFile {
        WorkspaceFile(relativePath: "F\(bytes).swift", byteCount: bytes)
    }

    /// Perkiraan sengaja konservatif: 3,5 karakter per token, dibulatkan ke atas.
    @Test func estimateRoundsUp() {
        #expect(ContextBudget.tokens(forCharacters: 0) == 0)
        #expect(ContextBudget.tokens(forCharacters: 7) == 2)
        #expect(ContextBudget.tokens(forCharacters: 8) == 3)
    }

    @Test func usedIsTheSumOfAttachments() {
        let attached = [file(3_500), file(3_500)]
        #expect(ContextBudget.used(attached) == 2_000)
        #expect(ContextBudget.remaining(after: attached) == ContextBudget.limit - 2_000)
    }

    @Test func fileThatFitsIsAccepted() {
        #expect(ContextBudget.canAdd(file(3_500), to: []))
    }

    @Test func fileThatOverflowsIsRefused() {
        let attached = [file(5_000)]
        #expect(ContextBudget.canAdd(file(3_000), to: attached) == false)
    }

    /// Berkas tunggal yang lebih besar dari seluruh anggaran tidak pernah bisa
    /// dilampirkan — versi ini tidak memotong berkas jadi sebagian (spec E §4).
    @Test func fileLargerThanTheWholeBudgetIsRefusedEvenWhenEmpty() {
        #expect(ContextBudget.canAdd(file(100_000), to: []) == false)
    }

    @Test func remainingNeverGoesNegative() {
        #expect(ContextBudget.remaining(after: [file(100_000)]) == 0)
    }
}
```

- [ ] **Step 2: Jalankan dan pastikan gagal**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/ContextBudgetTests 2>&1 | grep -E "error:" | head -3`
Expected: `cannot find 'ContextBudget' in scope`.

- [ ] **Step 3: Tulis implementasinya**

```swift
//
//  ContextBudget.swift
//  Apl
//
//  Berapa yang muat, dan berapa sisanya (spec E §4).
//
//  Model on-device punya ~4.096 token untuk SEGALANYA. Jatah berkas 1.600 token
//  adalah sisa setelah instructions, dua giliran ingatan, dan ruang jawaban —
//  dengan margin yang sengaja ditinggalkan karena perkiraan ini kasar.
//

import Foundation

enum ContextBudget {

    static let limit = 1_600
    static let charactersPerToken = 3.5

    static func tokens(forCharacters count: Int) -> Int {
        Int((Double(count) / charactersPerToken).rounded(.up))
    }

    static func tokens(for file: WorkspaceFile) -> Int {
        tokens(forCharacters: file.byteCount)
    }

    static func used(_ attached: [WorkspaceFile]) -> Int {
        attached.reduce(0) { $0 + tokens(for: $1) }
    }

    static func remaining(after attached: [WorkspaceFile]) -> Int {
        max(0, limit - used(attached))
    }

    static func canAdd(_ file: WorkspaceFile, to attached: [WorkspaceFile]) -> Bool {
        tokens(for: file) <= remaining(after: attached)
    }
}
```

- [ ] **Step 4: Jalankan dan pastikan lulus**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/ContextBudgetTests 2>&1 | grep -E "Test run with|TEST"`
Expected: PASS (6 test).

- [ ] **Step 5: Commit**

```bash
git add DinoPocketMac/Presentation/Code/ContextBudget.swift DinoPocketTests/ContextBudgetTests.swift
git commit -m "$(cat <<'EOF'
feat(e): anggaran token yang menolak, bukan memotong diam-diam

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Memeriksa jawaban sebelum dipakai menulis

**Files:**
- Create: `DinoPocketMac/Presentation/Code/CodeAnswer.swift`
- Test: `DinoPocketTests/CodeAnswerTests.swift`

**Interfaces:**
- Consumes: `MarkdownBlocks.split(_:)` dari sub-project B.
- Produces: `CodeAnswer.Rejection` (`.noCodeBlock`, `.manyCodeBlocks`, `.empty`,
  `.sizeOutOfBand`), `CodeAnswer.fileContents(from:originalCharacters:) -> Result<String, Rejection>`,
  konstanta `minRatio` (0,5) dan `maxRatio` (2,0).

- [ ] **Step 1: Tulis test yang gagal**

```swift
import Testing
@testable import Apl

struct CodeAnswerTests {

    private func block(_ body: String) -> String { "```swift\n\(body)\n```" }

    @Test func oneBlockOfReasonableSizeIsAccepted() {
        let body = String(repeating: "let x = 1\n", count: 10)
        let answer = "Here you go:\n\n" + block(body)
        #expect(try? CodeAnswer.fileContents(from: answer, originalCharacters: body.count).get() != nil)
    }

    @Test func answerWithoutACodeBlockWritesNothing() {
        #expect(CodeAnswer.fileContents(from: "I would change the name.", originalCharacters: 100)
                == .failure(.noCodeBlock))
    }

    /// Dua blok berarti model memberi potongan, bukan berkas utuh — dan menulis
    /// salah satunya berarti membuang sisanya.
    @Test func twoBlocksWriteNothing() {
        let answer = block("a") + "\n\n" + block("b")
        #expect(CodeAnswer.fileContents(from: answer, originalCharacters: 100)
                == .failure(.manyCodeBlocks))
    }

    @Test func emptyBlockWritesNothing() {
        #expect(CodeAnswer.fileContents(from: block(""), originalCharacters: 100)
                == .failure(.empty))
    }

    /// Model kecil kadang berhenti di tengah. Berkas yang tiba-tiba tinggal
    /// seperlima bukan suntingan — itu kehilangan.
    @Test func suspiciouslyShortAnswerWritesNothing() {
        let short = "let x = 1"
        if case .failure(let reason) = CodeAnswer.fileContents(from: block(short), originalCharacters: 1_000) {
            #expect(reason == .sizeOutOfBand)
        } else {
            Issue.record("jawaban terlalu pendek seharusnya ditolak")
        }
    }

    @Test func suspiciouslyLongAnswerWritesNothing() {
        let long = String(repeating: "x", count: 1_000)
        if case .failure(let reason) = CodeAnswer.fileContents(from: block(long), originalCharacters: 100) {
            #expect(reason == .sizeOutOfBand)
        } else {
            Issue.record("jawaban terlalu panjang seharusnya ditolak")
        }
    }

    @Test func returnedContentsAreTheBlockWithoutTheFence() {
        let body = String(repeating: "let x = 1\n", count: 10)
        let contents = try? CodeAnswer.fileContents(from: block(body), originalCharacters: body.count).get()
        #expect(contents?.contains("```") == false)
        #expect(contents?.hasPrefix("let x = 1") == true)
    }
}
```

- [ ] **Step 2: Jalankan dan pastikan gagal**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/CodeAnswerTests 2>&1 | grep -E "error:" | head -3`
Expected: `cannot find 'CodeAnswer' in scope`.

- [ ] **Step 3: Tulis implementasinya**

```swift
//
//  CodeAnswer.swift
//  Apl
//
//  Memeriksa jawaban model sebelum ia menyentuh berkas siapa pun (spec E §6 #3).
//
//  Model on-device kadang berhenti di tengah atau menjawab dengan potongan
//  alih-alih berkas utuh. Yang berbahaya bukan jawaban yang salah — itu bisa
//  dibaca dan diabaikan — melainkan jawaban setengah jadi yang terlanjur
//  ditulis ke berkas yang sedang jalan.
//

import Foundation

enum CodeAnswer {

    enum Rejection: Equatable {
        case noCodeBlock
        case manyCodeBlocks
        case empty
        case sizeOutOfBand
    }

    static let minRatio = 0.5
    static let maxRatio = 2.0

    static func fileContents(from answer: String,
                             originalCharacters: Int) -> Result<String, Rejection> {
        let blocks = MarkdownBlocks.split(answer).compactMap { block -> String? in
            if case .code(_, let code, _) = block { return code }
            return nil
        }
        guard !blocks.isEmpty else { return .failure(.noCodeBlock) }
        guard blocks.count == 1 else { return .failure(.manyCodeBlocks) }

        let contents = blocks[0].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !contents.isEmpty else { return .failure(.empty) }

        guard originalCharacters > 0 else { return .success(contents) }
        let ratio = Double(contents.count) / Double(originalCharacters)
        guard ratio >= minRatio, ratio <= maxRatio else { return .failure(.sizeOutOfBand) }
        return .success(contents)
    }
}
```

- [ ] **Step 4: Jalankan dan pastikan lulus**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/CodeAnswerTests 2>&1 | grep -E "Test run with|TEST"`
Expected: PASS (7 test).

- [ ] **Step 5: Commit**

```bash
git add DinoPocketMac/Presentation/Code/CodeAnswer.swift DinoPocketTests/CodeAnswerTests.swift
git commit -m "$(cat <<'EOF'
feat(e): jawaban diperiksa sebelum menyentuh berkas

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Instructions sisi Code

**Files:**
- Create: `SharedCore/Infrastructure/Services/CodeInstructions.swift`
- Test: `DinoPocketTests/CodeInstructionsTests.swift`

**Interfaces:**
- Produces: `CodeInstructions.text`.

- [ ] **Step 1: Tulis test yang gagal**

```swift
import Testing
@testable import Apl

struct CodeInstructionsTests {

    /// Instructions punya jatah ~300 token dari ~4.096 (spec E §4). Melewatinya
    /// berarti memakan ruang berkas tanpa ada yang memberi tahu.
    @Test func fitsItsShareOfTheContext() {
        #expect(ContextBudget.tokens(forCharacters: CodeInstructions.text.count) <= 300)
    }

    @Test func demandsWholeFilesInOneBlock() {
        let text = CodeInstructions.text.lowercased()
        #expect(text.contains("entire file"))
        #expect(text.contains("one code block"))
    }

    /// Persona Apl tetap, tapi sisi Code tidak boleh berbasa-basi: setiap kata
    /// basa-basi memakan token yang seharusnya jadi kode.
    @Test func asksForTerseAnswers() {
        #expect(CodeInstructions.text.lowercased().contains("brief"))
    }
}
```

- [ ] **Step 2: Jalankan dan pastikan gagal**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/CodeInstructionsTests 2>&1 | grep -E "error:" | head -3`
Expected: `cannot find 'CodeInstructions' in scope`.

- [ ] **Step 3: Tulis implementasinya**

```swift
//
//  CodeInstructions.swift
//  Apl
//
//  Instructions untuk sisi Code (spec E §2 #3).
//
//  Terpisah dari `AplInstructions` karena sesinya memang terpisah — dan karena
//  yang dibutuhkan di sini kebalikan dari persona chat: sesingkat mungkin,
//  selalu menyebut nama berkas, dan kalau diminta mengubah, kembalikan berkas
//  UTUH dalam satu blok. Blok kedua atau potongan akan ditolak sebelum ditulis.
//

enum CodeInstructions {
    static let text = """
    You are Apl, helping with code on this Mac. Be brief and technical.

    You only see the files the person attached. Never guess about code you were \
    not given; say which file you would need instead.

    Always name the file you are talking about.

    When asked to change a file, reply with the entire file after the change, in \
    exactly one code block, and nothing else after it. Never reply with a \
    fragment or with two code blocks — a fragment cannot be applied and will be \
    rejected.
    """
}
```

- [ ] **Step 4: Jalankan dan pastikan lulus**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/CodeInstructionsTests 2>&1 | grep -E "Test run with|TEST"`
Expected: PASS (3 test).

- [ ] **Step 5: Commit**

```bash
git add SharedCore/Infrastructure/Services/CodeInstructions.swift DinoPocketTests/CodeInstructionsTests.swift
git commit -m "$(cat <<'EOF'
feat(e): instructions sisi Code, ringkas dan menuntut berkas utuh

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Menulis berkas dengan jalan kembali

**Files:**
- Create: `DinoPocketMac/Infrastructure/Services/FileWriter.swift`
- Test: `DinoPocketTests/FileWriterTests.swift`

**Interfaces:**
- Produces: `FileWriter` (`init(backups:)`, `write(_:to:in:expecting:) throws -> Receipt`,
  `undo(_:in:) throws`), `FileWriter.Snapshot` (`modified`, `byteCount`),
  `FileWriter.Receipt` (`relativePath`, `changedLines`, `backupID`),
  `FileWriter.Failure` (`.outsideWorkspace`, `.staleOnDisk`, `.missing`),
  `FileWriter.changedLines(from:to:)`.

- [ ] **Step 1: Tulis test yang gagal**

```swift
import Foundation
import Testing
@testable import Apl

@MainActor
struct FileWriterTests {

    private func sandbox(_ name: String) throws -> (workspace: URL, backups: URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("apl.filewriter.\(name).\(UUID().uuidString)")
        let workspace = root.appendingPathComponent("workspace")
        let backups = root.appendingPathComponent("backups")
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: backups, withIntermediateDirectories: true)
        return (workspace, backups)
    }

    private func seed(_ workspace: URL, _ path: String, _ contents: String) throws -> FileWriter.Snapshot {
        let url = workspace.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return try FileWriter.snapshot(of: path, in: workspace)
    }

    @Test func writesAndReportsChangedLines() throws {
        let (workspace, backups) = try sandbox(#function)
        let before = try seed(workspace, "A.swift", "one\ntwo\nthree\n")
        let writer = FileWriter(backups: backups)

        let receipt = try writer.write("one\nTWO\nthree\n", to: "A.swift",
                                       in: workspace, expecting: before)
        #expect(receipt.changedLines == 2)
        let after = try String(contentsOf: workspace.appendingPathComponent("A.swift"), encoding: .utf8)
        #expect(after == "one\nTWO\nthree\n")
    }

    /// Penulisan tidak pernah keluar dari folder pilihan pengguna.
    @Test func refusesPathsThatEscapeTheWorkspace() throws {
        let (workspace, backups) = try sandbox(#function)
        let before = try seed(workspace, "A.swift", "x\n")
        let writer = FileWriter(backups: backups)
        #expect(throws: FileWriter.Failure.outsideWorkspace) {
            try writer.write("y\n", to: "../escape.swift", in: workspace, expecting: before)
        }
    }

    /// Berkas yang disunting di Xcode sejak dilampirkan tidak boleh ditimpa:
    /// tanpa pemeriksaan ini, suntingan itu lenyap tanpa suara.
    @Test func refusesFileThatChangedOnDiskSinceItWasAttached() throws {
        let (workspace, backups) = try sandbox(#function)
        let before = try seed(workspace, "A.swift", "old\n")
        try "edited in Xcode\n".write(to: workspace.appendingPathComponent("A.swift"),
                                      atomically: true, encoding: .utf8)
        let writer = FileWriter(backups: backups)
        #expect(throws: FileWriter.Failure.staleOnDisk) {
            try writer.write("new\n", to: "A.swift", in: workspace, expecting: before)
        }
    }

    @Test func undoRestoresTheExactPreviousContents() throws {
        let (workspace, backups) = try sandbox(#function)
        let before = try seed(workspace, "A.swift", "one\ntwo\n")
        let writer = FileWriter(backups: backups)
        let receipt = try writer.write("changed\n", to: "A.swift", in: workspace, expecting: before)

        try writer.undo(receipt, in: workspace)
        let restored = try String(contentsOf: workspace.appendingPathComponent("A.swift"), encoding: .utf8)
        #expect(restored == "one\ntwo\n")
    }

    /// Undo yang menimpa pekerjaan yang lebih baru sama buruknya dengan tulis
    /// yang menimpa: keduanya menghapus sesuatu yang tidak pernah dilihat.
    @Test func undoRefusesWhenTheFileChangedAgainAfterTheWrite() throws {
        let (workspace, backups) = try sandbox(#function)
        let before = try seed(workspace, "A.swift", "one\n")
        let writer = FileWriter(backups: backups)
        let receipt = try writer.write("two\n", to: "A.swift", in: workspace, expecting: before)
        try "three\n".write(to: workspace.appendingPathComponent("A.swift"),
                            atomically: true, encoding: .utf8)

        #expect(throws: FileWriter.Failure.staleOnDisk) {
            try writer.undo(receipt, in: workspace)
        }
    }

    @Test func changedLinesCountsOnlyTheChangedRegion() {
        #expect(FileWriter.changedLines(from: ["a", "b", "c"], to: ["a", "b", "c"]) == 0)
        #expect(FileWriter.changedLines(from: ["a", "b", "c"], to: ["a", "B", "c"]) == 2)
        #expect(FileWriter.changedLines(from: ["a", "c"], to: ["a", "b", "c"]) == 1)
    }
}
```

- [ ] **Step 2: Jalankan dan pastikan gagal**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/FileWriterTests 2>&1 | grep -E "error:" | head -3`
Expected: `cannot find 'FileWriter' in scope`.

- [ ] **Step 3: Tulis implementasinya**

```swift
//
//  FileWriter.swift
//  Apl
//
//  Menulis berkas pengguna, dengan jalan kembali yang selalu ada (spec E §6).
//
//  Tiga penolakan yang tidak bisa ditawar: keluar dari workspace, berkas yang
//  berubah di disk sejak dilampirkan, dan Undo yang akan menimpa pekerjaan
//  lebih baru. Ketiganya soal yang sama — jangan menghapus sesuatu yang tidak
//  pernah dilihat.
//

import Foundation

@MainActor
final class FileWriter {

    struct Snapshot: Equatable {
        let modified: Date
        let byteCount: Int
    }

    struct Receipt: Equatable {
        let relativePath: String
        let changedLines: Int
        let backupID: UUID
        /// Keadaan berkas TEPAT setelah ditulis; Undo menolak bila sudah beda.
        let afterWrite: Snapshot
    }

    enum Failure: Error, Equatable {
        case outsideWorkspace
        case staleOnDisk
        case missing
    }

    private let backups: URL

    init(backups: URL) {
        self.backups = backups
    }

    nonisolated static func snapshot(of relativePath: String, in workspace: URL) throws -> Snapshot {
        let url = try resolved(relativePath, in: workspace)
        let values = try url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        guard let modified = values.contentModificationDate, let size = values.fileSize else {
            throw Failure.missing
        }
        return Snapshot(modified: modified, byteCount: size)
    }

    @discardableResult
    func write(_ contents: String, to relativePath: String, in workspace: URL,
               expecting: Snapshot) throws -> Receipt {
        let url = try Self.resolved(relativePath, in: workspace)
        guard try Self.snapshot(of: relativePath, in: workspace) == expecting else {
            throw Failure.staleOnDisk
        }

        let old = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let backupID = UUID()
        try FileManager.default.createDirectory(at: backups, withIntermediateDirectories: true)
        try old.write(to: backups.appendingPathComponent(backupID.uuidString),
                      atomically: true, encoding: .utf8)

        try contents.write(to: url, atomically: true, encoding: .utf8)

        return Receipt(relativePath: relativePath,
                       changedLines: Self.changedLines(from: old.lines, to: contents.lines),
                       backupID: backupID,
                       afterWrite: try Self.snapshot(of: relativePath, in: workspace))
    }

    func undo(_ receipt: Receipt, in workspace: URL) throws {
        let url = try Self.resolved(receipt.relativePath, in: workspace)
        guard try Self.snapshot(of: receipt.relativePath, in: workspace) == receipt.afterWrite else {
            throw Failure.staleOnDisk
        }
        let backup = backups.appendingPathComponent(receipt.backupID.uuidString)
        guard let old = try? String(contentsOf: backup, encoding: .utf8) else { throw Failure.missing }
        try old.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Hanya baris di DAERAH yang berubah yang dihitung: awalan dan akhiran yang
    /// sama dipangkas dulu, supaya "12 baris berubah" berarti apa yang dikatakan.
    nonisolated static func changedLines(from old: [String], to new: [String]) -> Int {
        var start = 0
        while start < old.count, start < new.count, old[start] == new[start] { start += 1 }
        var endOld = old.count, endNew = new.count
        while endOld > start, endNew > start, old[endOld - 1] == new[endNew - 1] {
            endOld -= 1; endNew -= 1
        }
        return (endOld - start) + (endNew - start)
    }

    /// Menolak path yang keluar dari workspace SEBELUM menyentuh disk.
    nonisolated static func resolved(_ relativePath: String, in workspace: URL) throws -> URL {
        let url = workspace.appendingPathComponent(relativePath).standardizedFileURL
        let root = workspace.standardizedFileURL.path
        guard url.path == root || url.path.hasPrefix(root + "/") else {
            throw Failure.outsideWorkspace
        }
        return url
    }
}

private extension String {
    var lines: [String] { components(separatedBy: "\n") }
}
```

- [ ] **Step 4: Jalankan dan pastikan lulus**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/FileWriterTests 2>&1 | grep -E "Test run with|TEST"`
Expected: PASS (6 test).

- [ ] **Step 5: Commit**

```bash
git add DinoPocketMac/Infrastructure/Services/FileWriter.swift DinoPocketTests/FileWriterTests.swift
git commit -m "$(cat <<'EOF'
feat(e): penulis berkas yang menolak menghapus yang tak pernah dilihat

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Folder kerja yang bertahan

**Files:**
- Create: `DinoPocketMac/Infrastructure/Persistence/CodeWorkspace.swift`
- Test: `DinoPocketTests/CodeWorkspaceTests.swift`

**Interfaces:**
- Consumes: `WorkspaceListing` (Task 1).
- Produces: `BookmarkStoring` (`save(_:for:)`, `resolve(_:) -> URL?`),
  `UserDefaultsBookmarkStore`, `CodeWorkspace` (`init(bookmarks:defaults:)`, `var url: URL?`,
  `func choose(_:)`, `func forget()`, `func files() -> [WorkspaceFile]`,
  `func contents(of:) -> String?`), kunci `code.workspace`.

- [ ] **Step 1: Tulis test yang gagal**

```swift
import Foundation
import Testing
@testable import Apl

@MainActor
final class FakeBookmarks: BookmarkStoring {
    private(set) var saved: [String: URL] = [:]
    func save(_ url: URL, for key: String) throws { saved[key] = url }
    func resolve(_ key: String) -> URL? { saved[key] }
}

@MainActor
struct CodeWorkspaceTests {

    private func tempFolder(_ name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("apl.workspace.\(name).\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func remembersTheChosenFolder() throws {
        let folder = try tempFolder(#function)
        let bookmarks = FakeBookmarks()
        let workspace = CodeWorkspace(bookmarks: bookmarks)
        try workspace.choose(folder)

        #expect(workspace.url == folder)
        #expect(CodeWorkspace(bookmarks: bookmarks).url == folder)
    }

    @Test func forgettingClearsIt() throws {
        let folder = try tempFolder(#function)
        let workspace = CodeWorkspace(bookmarks: FakeBookmarks())
        try workspace.choose(folder)
        workspace.forget()
        #expect(workspace.url == nil)
    }

    @Test func listsOnlyFilesWorthTalkingAbout() throws {
        let folder = try tempFolder(#function)
        try "let a = 1".write(to: folder.appendingPathComponent("A.swift"),
                              atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(
            at: folder.appendingPathComponent(".git"), withIntermediateDirectories: true)
        try "noise".write(to: folder.appendingPathComponent(".git/config"),
                          atomically: true, encoding: .utf8)

        let workspace = CodeWorkspace(bookmarks: FakeBookmarks())
        try workspace.choose(folder)
        #expect(workspace.files().map(\.name) == ["A.swift"])
    }

    @Test func readsContentsOfAListedFile() throws {
        let folder = try tempFolder(#function)
        try "let a = 1".write(to: folder.appendingPathComponent("A.swift"),
                              atomically: true, encoding: .utf8)
        let workspace = CodeWorkspace(bookmarks: FakeBookmarks())
        try workspace.choose(folder)
        #expect(workspace.contents(of: "A.swift") == "let a = 1")
    }
}
```

- [ ] **Step 2: Jalankan dan pastikan gagal**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/CodeWorkspaceTests 2>&1 | grep -E "error:" | head -3`
Expected: `cannot find type 'BookmarkStoring' in scope`.

- [ ] **Step 3: Tulis implementasinya**

```swift
//
//  CodeWorkspace.swift
//  Apl
//
//  Folder kerja sisi Code (spec E §2 #4).
//
//  Disimpan sebagai security-scoped bookmark: pengguna memilih sekali, dan
//  pilihan itu bertahan antar-peluncuran tanpa panel Open muncul lagi. Itu
//  satu-satunya cara app sandbox boleh membaca folder di luar containernya —
//  dan `ENABLE_USER_SELECTED_FILES` sudah ada sejak sebelum sub-project ini,
//  jadi tidak ada izin baru yang diminta.
//

import Foundation
import Observation

@MainActor
protocol BookmarkStoring {
    func save(_ url: URL, for key: String) throws
    func resolve(_ key: String) -> URL?
}

@MainActor
struct UserDefaultsBookmarkStore: BookmarkStoring {
    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func save(_ url: URL, for key: String) throws {
        let data = try url.bookmarkData(options: .withSecurityScope,
                                        includingResourceValuesForKeys: nil, relativeTo: nil)
        defaults.set(data, forKey: key)
        // Dipaksa turun ke disk; lihat catatan di `ProfileStore`.
        defaults.synchronize()
    }

    func resolve(_ key: String) -> URL? {
        guard let data = defaults.data(forKey: key) else { return nil }
        var stale = false
        let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope,
                           relativeTo: nil, bookmarkDataIsStale: &stale)
        guard let url, url.startAccessingSecurityScopedResource() else { return nil }
        return url
    }
}

@MainActor
@Observable
final class CodeWorkspace {

    nonisolated static let key = "code.workspace"

    private(set) var url: URL?
    private let bookmarks: any BookmarkStoring

    init(bookmarks: any BookmarkStoring = UserDefaultsBookmarkStore()) {
        self.bookmarks = bookmarks
        url = bookmarks.resolve(Self.key)
    }

    func choose(_ folder: URL) throws {
        try bookmarks.save(folder, for: Self.key)
        url = folder
    }

    func forget() {
        url?.stopAccessingSecurityScopedResource()
        url = nil
    }

    /// Penelusuran disk ada di sini; aturan penyaringannya di `WorkspaceListing`,
    /// supaya "apa yang dilewati" bisa diuji tanpa folder sungguhan.
    func files() -> [WorkspaceFile] {
        guard let url else { return [] }
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey]
        guard let walker = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys) else {
            return []
        }
        var entries: [WorkspaceListing.Entry] = []
        for case let item as URL in walker {
            let values = try? item.resourceValues(forKeys: Set(keys))
            let relative = item.path.replacingOccurrences(of: url.path + "/", with: "")
            entries.append(WorkspaceListing.Entry(relativePath: relative,
                                                  byteCount: values?.fileSize ?? 0,
                                                  isDirectory: values?.isDirectory ?? false))
        }
        return WorkspaceListing.filter(entries)
    }

    func contents(of relativePath: String) -> String? {
        guard let url, let file = try? FileWriter.resolved(relativePath, in: url) else { return nil }
        return try? String(contentsOf: file, encoding: .utf8)
    }
}
```

- [ ] **Step 4: Jalankan dan pastikan lulus**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/CodeWorkspaceTests 2>&1 | grep -E "Test run with|TEST"`
Expected: PASS (4 test).

- [ ] **Step 5: Commit**

```bash
git add DinoPocketMac/Infrastructure/Persistence/CodeWorkspace.swift DinoPocketTests/CodeWorkspaceTests.swift
git commit -m "$(cat <<'EOF'
feat(e): folder kerja yang bertahan lewat security-scoped bookmark

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Otak kedua

**Files:**
- Modify: `SharedCore/Infrastructure/Services/AppleBrain.swift`,
  `DinoPocketMac/Presentation/ViewModels/ChatStore.swift`
- Test: `DinoPocketTests/SecondBrainTests.swift`

**Interfaces:**
- Produces: `AppleBrain(instructions:sessionStore:)` (bawaan `AplInstructions.text`),
  `ChatStore(brain:defaults:recentKey:now:)` (bawaan `ChatStore.recentKey`).

- [ ] **Step 1: Tulis test yang gagal**

```swift
import Foundation
import Testing
@testable import Apl

@MainActor
struct SecondBrainTests {

    private func isolatedDefaults(_ name: String) -> UserDefaults {
        let suite = "test.secondbrain.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    /// Dua percakapan dalam satu app harus menyimpan ke kunci berbeda; kalau
    /// tidak, riwayat Chat dan Code saling menimpa di disk.
    @Test func twoStoresDoNotSeeEachOther() async {
        let defaults = isolatedDefaults(#function)
        let chat = ChatStore(brain: nil, defaults: defaults)
        let code = ChatStore(brain: nil, defaults: defaults, recentKey: "code.chat.recent")

        chat.messages = [ChatMessage(role: .user, text: "halo")]
        code.messages = [ChatMessage(role: .user, text: "explain A.swift")]
        chat.persistForTesting()
        code.persistForTesting()

        #expect(ChatStore(brain: nil, defaults: defaults).messages.first?.text == "halo")
        #expect(ChatStore(brain: nil, defaults: defaults, recentKey: "code.chat.recent")
                    .messages.first?.text == "explain A.swift")
    }

    @Test func brainKeepsItsDefaultInstructions() {
        #expect(AppleBrain().instructionsText == AplInstructions.text)
    }

    @Test func brainCanBeGivenCodeInstructions() {
        #expect(AppleBrain(instructions: CodeInstructions.text).instructionsText == CodeInstructions.text)
    }
}
```

- [ ] **Step 2: Jalankan dan pastikan gagal**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' -only-testing:DinoPocketTests/SecondBrainTests 2>&1 | grep -E "error:" | head -3`
Expected: `extra argument 'recentKey' in call`.

- [ ] **Step 3: Jadikan kunci penyimpanan parameter di `ChatStore`**

Ganti `nonisolated static let recentKey` tetap seperti apa adanya (nilai bawaan), lalu
tambahkan properti dan parameter:

```swift
    /// Kunci penyimpanan percakapan INI. Sisi Code memakai kunci lain supaya dua
    /// percakapan dalam satu app tidak saling menimpa di disk (spec E §2 #3).
    private let storageKey: String

    init(brain: Brain?, defaults: UserDefaults = .standard,
         recentKey: String = ChatStore.recentKey,
         now: @escaping () -> Date = { .now }) {
        self.brain = brain
        self.defaults = defaults
        self.storageKey = recentKey
        self.now = now
        if let data = defaults.data(forKey: recentKey),
           let restored = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            messages = restored
        }
    }
```

Ganti SETIAP pemakaian `Self.recentKey` di dalam kelas menjadi `storageKey` —
`resetConversationState()` dan `persistRecent()`. Tambahkan juga pintu untuk test:

```swift
    #if DEBUG
    /// Hanya untuk test: memaksa penyimpanan tanpa melalui `send`.
    func persistForTesting() { persistRecent() }
    #endif
```

- [ ] **Step 4: Jadikan instructions parameter di `AppleBrain`**

```swift
    private let instructions: String

    init(instructions: String = AplInstructions.text, sessionStore: (any Sendable)? = nil) {
        self.instructions = instructions
        self.sessions = sessionStore
    }

    /// Dibaca test; sesi sungguhan tidak bisa diperiksa dari luar.
    var instructionsText: String { instructions }
```

dan ganti `LanguageModelSession(instructions: AplInstructions.text)` menjadi
`LanguageModelSession(instructions: instructions)`.

- [ ] **Step 5: Jalankan dan pastikan lulus, lalu seluruh suite**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' 2>&1 | grep -E "error:|Test run with|TEST"`
Expected: seluruh suite lulus — termasuk `ChatStoreTests` lama yang tidak diubah sama sekali.

- [ ] **Step 6: Commit**

```bash
git add SharedCore/Infrastructure/Services/AppleBrain.swift DinoPocketMac/Presentation/ViewModels/ChatStore.swift DinoPocketTests/SecondBrainTests.swift
git commit -m "$(cat <<'EOF'
feat(e): otak dan penyimpanan kedua, tanpa mengubah yang pertama

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Tampilan sisi Code

**Files:**
- Create: `DinoPocketMac/Presentation/Code/FileChip.swift`,
  `DinoPocketMac/Presentation/Code/CodeView.swift`
- Test: tidak ada test unit (SwiftUI murni); diverifikasi di Task 10.

**Interfaces:**
- Consumes: semua unit Task 1–7, `MessageRow`, `Composer`, `ReminderChip` (sebagai idiom).
- Produces: `CodeView(workspace:chat:writer:)`.

- [ ] **Step 1: Tulis chip berkas**

```swift
//
//  FileChip.swift
//  Apl
//
//  Satu berkas yang sedang ditunjuk, beserta cara melepasnya (spec E §7).
//

import SwiftUI

struct FileChip: View {
    let file: WorkspaceFile
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Text(file.name)
                .lineLimit(1)
            Text("\(ContextBudget.tokens(for: file))t")
                .foregroundStyle(.secondary)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(file.name)")
        }
        .font(.callout)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 4)
        .background(AppColor.controlFill, in: Capsule())
    }
}
```

- [ ] **Step 2: Tulis `CodeView`**

```swift
//
//  CodeView.swift
//  Apl
//
//  Ruang kedua di jendela utama (spec E §7).
//
//  Yang paling penting di layar ini bukan percakapannya, melainkan pengukur
//  token: ia satu-satunya yang memberi tahu kapan jawaban akan mulai memburuk,
//  dan tanpa itu penurunannya terjadi diam-diam.
//

import AppKit
import SwiftUI

struct CodeView: View {
    let workspace: CodeWorkspace
    let chat: ChatStore
    let writer: FileWriter

    @State private var attached: [WorkspaceFile] = []
    @State private var draft = ""
    @State private var availability: BrainAvailability?
    @State private var isPickingFile = false
    @State private var notice: String?

    var body: some View {
        VStack(spacing: 0) {
            if workspace.url == nil {
                empty
            } else {
                fileBar
                Divider()
                conversation
            }
        }
        .task { availability = await chat.availability() }
        .announcesAnswers(from: chat, priority: .medium)
    }

    private var empty: some View {
        ContentUnavailableView {
            Label("Pick a folder to talk about code", systemImage: "folder")
        } description: {
            Text("Apl only reads the files you point at, and only inside this folder.")
        } actions: {
            Button("Choose Folder…", action: chooseFolder)
        }
    }

    private var fileBar: some View {
        HStack(spacing: Spacing.sm) {
            Button(action: chooseFolder) {
                Label(workspace.url?.lastPathComponent ?? "", systemImage: "folder")
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            .help("Change folder")

            ForEach(attached) { file in
                FileChip(file: file) { attached.removeAll { $0 == file } }
            }

            Button { isPickingFile = true } label: { Image(systemName: "plus") }
                .buttonStyle(.plain)
                .accessibilityLabel("Attach a file")
                .popover(isPresented: $isPickingFile) { filePicker }

            Spacer(minLength: Spacing.sm)

            Text("\(ContextBudget.used(attached)) / \(ContextBudget.limit) tokens")
                .font(.caption.monospacedDigit())
                .foregroundStyle(ContextBudget.remaining(after: attached) == 0 ? AppColor.statusWarning : .secondary)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    private var filePicker: some View {
        let files = workspace.files()
        return List(files) { file in
            Button {
                add(file)
            } label: {
                HStack {
                    Text(file.relativePath).lineLimit(1)
                    Spacer()
                    Text("\(ContextBudget.tokens(for: file))t").foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .disabled(attached.contains(file) || !ContextBudget.canAdd(file, to: attached))
        }
        .frame(width: 420, height: 320)
    }

    private var conversation: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                    ForEach(chat.messages) { message in
                        MessageRow(message: message, reminders: .preview(),
                                   canRetry: false, onRetry: {})
                    }
                }
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .defaultScrollAnchor(.bottom)

            if let notice {
                Label(notice, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(AppColor.statusWarning)
                    .padding(.horizontal, Spacing.lg)
            }

            Composer(draft: $draft,
                     state: .current(availability: availability, isStreaming: chat.isStreaming),
                     onSend: send,
                     onStop: { chat.stopStreaming() })
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.lg)
        }
    }

    // MARK: - Tindakan

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        try? workspace.choose(folder)
        attached = []
    }

    private func add(_ file: WorkspaceFile) {
        guard ContextBudget.canAdd(file, to: attached) else {
            notice = "\(file.name) needs \(ContextBudget.tokens(for: file)) tokens; only \(ContextBudget.remaining(after: attached)) left."
            return
        }
        attached.append(file)
        notice = nil
        isPickingFile = false
    }

    private func send() {
        let question = draft
        draft = ""
        let files = attached.compactMap { file -> (WorkspaceFile, String)? in
            guard let contents = workspace.contents(of: file.relativePath) else { return nil }
            return (file, contents)
        }
        Task { await ask(question, with: files) }
    }
}
```

- [ ] **Step 3: Build**

Run: `xcodegen generate && xcodebuild build -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' 2>&1 | grep -E "error:|BUILD"`
Expected: gagal dengan `cannot find 'ask' in scope` — fungsinya ditulis di Task 9, tempat
penulisan berkas disambungkan. Biarkan gagal di sini; jangan menambal sementara.

---

### Task 9: Menyambungkan pertanyaan, jawaban, dan penulisan

**Files:**
- Modify: `DinoPocketMac/Presentation/Code/CodeView.swift`,
  `DinoPocketMac/Presentation/Window/MainWindow.swift`,
  `DinoPocketMac/App/AppDependencies.swift`, `DinoPocketMac/App/AplApp.swift`

**Interfaces:**
- Produces: `CodeView.ask(_:with:)`, `MainWindow` dengan pemilih Chat | Code,
  `AppDependencies.makeCodeChatStore()`, `AppDependencies.codeWorkspace`,
  `AppDependencies.fileWriter`.

- [ ] **Step 1: Tulis `ask` di `CodeView`**

```swift
    /// Satu giliran sisi Code: berkas yang ditunjuk dan pertanyaannya masuk
    /// sebagai satu pesan, lalu jawabannya diperiksa sebelum menyentuh disk.
    private func ask(_ question: String, with files: [(WorkspaceFile, String)]) async {
        let attachments = files.map { file, contents in
            "File: \(file.relativePath)\n```\n\(contents)\n```"
        }.joined(separator: "\n\n")
        let prompt = attachments.isEmpty ? question : attachments + "\n\n" + question

        await chat.send(prompt)

        // Menulis hanya bila tepat SATU berkas ditunjuk: dengan dua berkas,
        // tidak ada cara aman menebak yang mana yang dimaksud jawaban itu.
        guard files.count == 1, let (file, contents) = files.first,
              let answer = chat.messages.last, answer.role == .assistant,
              answer.status != .failed else { return }

        switch CodeAnswer.fileContents(from: answer.text, originalCharacters: contents.count) {
        case .failure(let reason):
            notice = Self.explain(reason)
        case .success(let updated):
            applyWrite(updated, to: file)
        }
    }

    private func applyWrite(_ contents: String, to file: WorkspaceFile) {
        guard let root = workspace.url,
              let expected = try? FileWriter.snapshot(of: file.relativePath, in: root) else { return }
        do {
            let receipt = try writer.write(contents, to: file.relativePath,
                                           in: root, expecting: expected)
            chat.appendAssistantNote("Wrote \(file.name) · \(receipt.changedLines) lines changed")
            lastReceipt = receipt
            notice = nil
        } catch FileWriter.Failure.staleOnDisk {
            notice = "\(file.name) changed on disk since you attached it. Nothing was written."
        } catch {
            notice = "Couldn't write \(file.name)."
        }
    }

    private static func explain(_ reason: CodeAnswer.Rejection) -> String {
        switch reason {
        case .noCodeBlock: "No file was written — the answer has no code block."
        case .manyCodeBlocks: "No file was written — the answer has more than one code block."
        case .empty: "No file was written — the code block is empty."
        case .sizeOutOfBand: "No file was written — the answer looks truncated."
        }
    }
```

Tambahkan `@State private var lastReceipt: FileWriter.Receipt?` dan, di bawah chip catatan
penulisan, tombol Undo yang memanggil `writer.undo(receipt, in: root)` lalu mengosongkan
`lastReceipt`; kegagalannya memakai kalimat yang sama seperti di atas.

- [ ] **Step 2: Tambahkan pemilih Chat | Code di `MainWindow`**

```swift
    enum Side: String, CaseIterable { case chat = "Chat", code = "Code" }
    @State private var side: Side = .chat
```

Di kolom kanan, di atas percakapan:

```swift
                    Picker("", selection: $side) {
                        ForEach(Side.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(.horizontal, Spacing.xl)
                    .padding(.top, Spacing.sm)

                    switch side {
                    case .chat:
                        ConversationView(chat: chat, reminders: reminders, availability: availability,
                                         showsDateHeader: !isCompact, composerFocus: composerFocus,
                                         onOpenIntelligenceSettings: { _ = launcher.open(.appleIntelligence) })
                    case .code:
                        CodeView(workspace: codeWorkspace, chat: codeChat, writer: fileWriter)
                    }
```

dengan tiga properti baru di `MainWindow`: `codeWorkspace`, `codeChat`, `fileWriter`.

- [ ] **Step 3: Sediakan di `AppDependencies`**

```swift
    let codeWorkspace = CodeWorkspace()
    let fileWriter = FileWriter(backups: AppDependencies.backupsFolder())

    func makeCodeChatStore() -> ChatStore {
        ChatStore(brain: AppleBrain(instructions: CodeInstructions.text,
                                    sessionStore: FileChatSessionStore(fileName: "code-transcript.json")),
                  recentKey: "code.chat.recent")
    }

    /// Cadangan tinggal di container app, bukan di folder pengguna (spec E §6 #4).
    static func backupsFolder() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Apl/CodeBackups", isDirectory: true)
    }
```

Masukkan `codeWorkspace` ke daftar `erasableStores` bila ia menyimpan kunci —
`code.workspace` dan `code.chat.recent` harus ikut hilang saat Erase All Data.

- [ ] **Step 4: Teruskan dari `AplApp`**

Tambahkan `@State private var codeChat = deps.makeCodeChatStore()` dan teruskan
`codeWorkspace`, `codeChat`, `fileWriter` ke `MainWindow`.

- [ ] **Step 5: Build, seluruh suite, pemeriksa, dan entitlements**

Run: `xcodegen generate && xcodebuild test -project DinoPocket.xcodeproj -scheme DinoPocketMac -destination 'platform=macOS' 2>&1 | grep -E "error:|Test run with|TEST"`
Expected: seluruh suite lulus.

Run: `./scripts/verify-boundaries.sh && ./scripts/verify-release.sh 2>&1 | tail -3`
Expected: keduanya hijau.

Run: `git diff --stat project.yml | grep -i entitle; echo "exit=$?"`
Expected: tidak ada baris entitlement baru (spec §9).

- [ ] **Step 6: Commit**

```bash
git add DinoPocketMac/Presentation/Code DinoPocketMac/Presentation/Window/MainWindow.swift DinoPocketMac/App/AppDependencies.swift DinoPocketMac/App/AplApp.swift
git commit -m "$(cat <<'EOF'
feat(e): sisi Code tersambung — bertanya, menjawab, menulis, membatalkan

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 10: Verifikasi manual dan catatan

- [ ] **Step 1: Jalankan app dan kerjakan daftar periksa spec §8**

1. Pilih folder — panel Open muncul sekali; tutup app, buka lagi, folder masih ada.
2. Lampirkan dua berkas; pengukur token naik sesuai perkiraan.
3. Lampirkan berkas yang tidak muat; penolakannya menyebut kebutuhan dan sisa ruang.
4. Ajukan pertanyaan tentang berkas yang dilampirkan; jawabannya menyebut nama berkas.
5. Minta perubahan pada satu berkas; chip penulisan dan Undo muncul; isi berkas berubah.
6. Tekan Undo; isi berkas kembali persis seperti semula.
7. Sunting berkas di Xcode lalu minta perubahan lagi; **ditolak** dengan alasan basi.
8. Tutup app, buka lagi, tekan Undo pada penulisan sebelumnya — masih bekerja.
9. Regresi: sisi Chat, bubble ⌥Space, klik robot, dan balon proaktif tidak berubah.

- [ ] **Step 2: Perbaiki temuan, satu commit per temuan**

- [ ] **Step 3: Tulis hasilnya**

Tambahkan "Catatan eksekusi" di plan ini, tandai DoD di spec §9, dan catat penyesuaian apa
pun di bagian baru spec.

---

## Self-review

**Cakupan spec:** §2 #1 → tidak ada panggilan jaringan di seluruh plan; #2 → Task 9 Step 2;
#3 → Task 7; #4 → Task 6 dan Task 8; #5 → ingatan dua giliran dibawa `ChatStore` apa adanya
lewat riwayatnya sendiri; #6 → Task 5 dan Task 9; #7 → Task 9 Step 5 memeriksa entitlements.
§4 → Task 2. §5 → Task 1. §6 → Task 5. §7 → Task 8. §8 → Task 1–7 dan Task 10. §9 → Task 10.

**Placeholder:** tidak ada. Satu-satunya langkah yang sengaja gagal adalah Task 8 Step 3,
dan kegagalannya dinyatakan beserta alasannya.

**Konsistensi tipe:** `WorkspaceFile` dipakai Task 1, 2, 6, 8 dengan bentuk sama.
`ContextBudget.limit` dipakai Task 2, 4, 8. `FileWriter.Snapshot` dibuat Task 5 dan dibaca
Task 9. `CodeAnswer.Rejection` didefinisikan Task 3 dan dijelaskan ke pengguna di Task 9.
`ChatStore(recentKey:)` ditambahkan Task 7 dan dipakai Task 9.

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

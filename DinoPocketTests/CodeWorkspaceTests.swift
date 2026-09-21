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
final class FailingBookmarks: BookmarkStoring {
    struct Nope: Error {}
    func save(_ url: URL, for key: String) throws { throw Nope() }
    func resolve(_ key: String) -> URL? { nil }
}

@MainActor
struct CodeWorkspaceTests {

    private func tempFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("apl.workspace.\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Bookmark yang gagal tidak boleh membatalkan folder yang sudah dipilih:
    /// aksesnya datang dari panel Open, bukan dari bookmark.
    @Test func keepsTheFolderEvenWhenTheBookmarkCannotBeSaved() throws {
        let failing = FailingBookmarks()
        let workspace = CodeWorkspace(bookmarks: failing)
        workspace.choose(try tempFolder())
        #expect(workspace.url != nil)
        #expect(workspace.bookmarkFailure != nil)
    }

    @Test func remembersTheChosenFolder() throws {
        let folder = try tempFolder()
        let bookmarks = FakeBookmarks()
        let workspace = CodeWorkspace(bookmarks: bookmarks)
        workspace.choose(folder)

        #expect(workspace.url == folder)
        #expect(CodeWorkspace(bookmarks: bookmarks).url == folder)
    }

    @Test func forgettingClearsIt() throws {
        let workspace = CodeWorkspace(bookmarks: FakeBookmarks())
        workspace.choose(try tempFolder())
        workspace.forget()
        #expect(workspace.url == nil)
    }

    @Test func listsOnlyFilesWorthTalkingAbout() throws {
        let folder = try tempFolder()
        try "let a = 1".write(to: folder.appendingPathComponent("A.swift"),
                              atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(
            at: folder.appendingPathComponent(".git"), withIntermediateDirectories: true)
        try "noise".write(to: folder.appendingPathComponent(".git/config"),
                          atomically: true, encoding: .utf8)

        let workspace = CodeWorkspace(bookmarks: FakeBookmarks())
        workspace.choose(folder)
        #expect(workspace.files().map(\.name) == ["A.swift"])
    }

    @Test func readsContentsOfAListedFile() throws {
        let folder = try tempFolder()
        try "let a = 1".write(to: folder.appendingPathComponent("A.swift"),
                              atomically: true, encoding: .utf8)
        let workspace = CodeWorkspace(bookmarks: FakeBookmarks())
        workspace.choose(folder)
        #expect(workspace.contents(of: "A.swift") == "let a = 1")
    }

    /// Membaca di luar folder kerja ditolak di lapisan yang sama dengan menulis.
    @Test func refusesToReadOutsideTheWorkspace() throws {
        let workspace = CodeWorkspace(bookmarks: FakeBookmarks())
        workspace.choose(try tempFolder())
        #expect(workspace.contents(of: "../../etc/hosts") == nil)
    }
}

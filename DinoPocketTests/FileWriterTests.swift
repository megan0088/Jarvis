import Foundation
import Testing
@testable import Apl

@MainActor
struct FileWriterTests {

    private func sandbox(_ name: String) throws -> (workspace: URL, backups: URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("apl.filewriter.\(UUID().uuidString)")
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

    /// Undo yang menimpa pekerjaan lebih baru sama buruknya dengan tulis yang
    /// menimpa: keduanya menghapus sesuatu yang tidak pernah dilihat.
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

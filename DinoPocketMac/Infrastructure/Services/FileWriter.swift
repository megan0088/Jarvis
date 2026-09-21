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
//  Keadaan berkas dikenali lewat SIDIK ISI, bukan tanggal ubah. Tanggal ubah
//  hanya berketelitian satu detik pada banyak filesystem: suntingan berukuran
//  sama di detik yang sama akan lolos, dan justru itu bentuk suntingan yang
//  paling sering terjadi saat orang mengganti satu nama di Xcode.
//

import CryptoKit
import Foundation

@MainActor
final class FileWriter {

    struct Snapshot: Equatable {
        let byteCount: Int
        let digest: String
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
        guard let data = FileManager.default.contents(atPath: url.path) else { throw Failure.missing }
        return snapshot(of: data)
    }

    nonisolated static func snapshot(of data: Data) -> Snapshot {
        Snapshot(byteCount: data.count,
                 digest: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined())
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

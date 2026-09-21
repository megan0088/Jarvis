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
    /// Folder terpakai untuk sesi ini, tetapi tidak bisa diingat sampai
    /// peluncuran berikutnya. Ditampilkan apa adanya alih-alih didiamkan.
    private(set) var bookmarkFailure: String?
    private let bookmarks: any BookmarkStoring

    init(bookmarks: any BookmarkStoring = UserDefaultsBookmarkStore()) {
        self.bookmarks = bookmarks
        url = bookmarks.resolve(Self.key)
    }

    /// Akses berlaku begitu pengguna memilih di panel Open — itu pemberian dari
    /// sistem, bukan dari bookmark. Menyimpan bookmark hanya membuat pilihan itu
    /// bertahan sampai peluncuran berikutnya, jadi kegagalannya tidak boleh
    /// membatalkan folder yang sudah dipilih: ia dicatat dan dikatakan.
    func choose(_ folder: URL) {
        url = folder
        do {
            try bookmarks.save(folder, for: Self.key)
            bookmarkFailure = nil
        } catch {
            bookmarkFailure = "Apl can use this folder now, but will ask again next launch. (\(error.localizedDescription))"
        }
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
        let root = url.standardizedFileURL.path + "/"
        var entries: [WorkspaceListing.Entry] = []
        for case let item as URL in walker {
            let values = try? item.resourceValues(forKeys: Set(keys))
            let relative = item.standardizedFileURL.path.replacingOccurrences(of: root, with: "")
            entries.append(WorkspaceListing.Entry(relativePath: relative,
                                                  byteCount: values?.fileSize ?? 0,
                                                  isDirectory: values?.isDirectory ?? false))
        }
        return WorkspaceListing.filter(entries)
    }

    /// Membaca lewat penjaga yang sama dengan menulis: path yang keluar dari
    /// workspace ditolak sebelum menyentuh disk.
    func contents(of relativePath: String) -> String? {
        guard let url, let file = try? FileWriter.resolved(relativePath, in: url) else { return nil }
        return try? String(contentsOf: file, encoding: .utf8)
    }
}

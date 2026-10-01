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

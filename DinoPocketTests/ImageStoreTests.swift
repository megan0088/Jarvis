import Foundation
import Testing
@testable import Apl

@MainActor
struct ImageStoreTests {

    /// Direktori sementara, bukan container app — test host-nya Apl.app.
    private func store() -> (ImageStore, URL) {
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
        let (store, _) = store()
        let name = try store.save(contentsOf: try sourceFile())
        #expect(name.hasSuffix(".png"))
        #expect(store.url(for: name) != nil)
    }

    /// Pesan menyimpan nama, bukan gambarnya. Berkas yang hilang harus
    /// menghasilkan nil, bukan URL yang menunjuk ke ketiadaan.
    @Test func missingFileIsNil() {
        let (store, _) = store()
        #expect(store.url(for: "tidak-ada.png") == nil)
    }

    @Test func pruneDropsWhatNoMessageReferences() throws {
        let (store, _) = store()
        let kept = try store.save(contentsOf: try sourceFile())
        let dropped = try store.save(contentsOf: try sourceFile())
        store.prune(keeping: [kept])
        #expect(store.url(for: kept) != nil)
        #expect(store.url(for: dropped) == nil)
    }

    /// Pagar keras: satu sesi yang penuh gambar tidak boleh menggelembung
    /// tanpa batas, bahkan bila semuanya masih dirujuk.
    ///
    /// Tanggal ubahnya dikarang, bukan ditunggu: beberapa berkas yang ditulis
    /// dalam detik yang sama akan membuat "yang terbaru" jadi undian.
    @Test func hardCapKeepsTheNewest() throws {
        let (store, _) = store()
        var names: [String] = []
        for _ in 0..<(ImageStore.limit + 3) {
            names.append(try store.save(contentsOf: try sourceFile()))
        }
        for (index, name) in names.enumerated() {
            let url = store.url(for: name)!
            try FileManager.default.setAttributes(
                [.modificationDate: Date(timeIntervalSince1970: 1_700_000_000 + Double(index))],
                ofItemAtPath: url.path)
        }
        store.prune(keeping: Set(names))
        let survivors = names.filter { store.url(for: $0) != nil }
        #expect(survivors.count == ImageStore.limit)
        #expect(survivors.contains(names.last!))
        #expect(survivors.contains(names.first!) == false)
    }

    @Test func eraseEmptiesTheFolder() throws {
        let (store, folder) = store()
        _ = try store.save(contentsOf: try sourceFile())
        store.eraseAllStoredData()
        #expect(FileManager.default.fileExists(atPath: folder.path) == false)
    }
}

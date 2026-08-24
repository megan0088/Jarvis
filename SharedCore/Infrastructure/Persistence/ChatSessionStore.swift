//
//  ChatSessionStore.swift
//  SharedCore
//
//  Menyimpan transcript sesi Foundation Models supaya percakapan bertahan
//  lintas peluncuran app.
//
//  Ini yang mengubah "tiap buka app kenalan ulang" jadi asisten yang benar-benar
//  ingat kemarin. Bisa sesederhana ini karena `Transcript` sudah `Codable`
//  (diverifikasi di .swiftinterface SDK, spec §3.3).
//
//  Application Support, bukan UserDefaults: transcript tumbuh seiring
//  percakapan, dan UserDefaults dimuat seluruhnya ke memori setiap peluncuran.
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

#if canImport(FoundationModels)

@available(macOS 26.0, iOS 26.0, *)
protocol ChatSessionStoring: Sendable {
    func loadTranscript() -> Transcript?
    func save(_ transcript: Transcript)
    func clear()
}

@available(macOS 26.0, iOS 26.0, *)
struct FileChatSessionStore: ChatSessionStoring {

    private let fileName: String

    init(fileName: String = "chat-transcript.json") {
        self.fileName = fileName
    }

    private var fileURL: URL? {
        guard let base = try? FileManager.default.url(for: .applicationSupportDirectory,
                                                      in: .userDomainMask,
                                                      appropriateFor: nil,
                                                      create: true) else { return nil }
        let folder = base.appendingPathComponent("DinoPocket", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent(fileName)
    }

    /// Kegagalan memuat sengaja dikembalikan sebagai `nil`, bukan dilempar.
    ///
    /// Transcript yang rusak atau berasal dari format versi lama tidak boleh
    /// menghalangi user mengobrol — konsekuensi terburuknya hanya kehilangan
    /// konteks percakapan lama, dan itu jauh lebih baik daripada chat yang
    /// menolak dibuka.
    func loadTranscript() -> Transcript? {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(Transcript.self, from: data)
    }

    func save(_ transcript: Transcript) {
        guard let fileURL, let data = try? JSONEncoder().encode(transcript) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func clear() {
        guard let fileURL else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }
}

@available(macOS 26.0, iOS 26.0, *)
extension FileChatSessionStore: LocallyErasable {
    /// Transcript berisi seluruh percakapan; ia data pribadi seperti yang lain.
    func eraseAllStoredData() { clear() }
}

@available(macOS 26.0, iOS 26.0, *)
enum TranscriptTrimmer {

    /// Memangkas transcript agar muat kembali di jendela konteks.
    ///
    /// Reaktif, bukan prediktif: tidak ada API publik untuk menghitung sisa
    /// token, jadi satu-satunya cara yang dijamin benar adalah menangkap
    /// `exceededContextWindowSize` lalu memangkas dan mengulang.
    ///
    /// `instructions` SELALU dipertahankan. Membuangnya akan menghapus persona
    /// — model tetap menjawab, tapi berhenti menjadi karakter yang sama, dan
    /// kegagalan seperti itu tidak terlihat sebagai error.
    static func trimmed(_ transcript: Transcript, keepingLast count: Int = 6) -> Transcript {
        let entries = Array(transcript)

        let instructions = entries.filter { if case .instructions = $0 { return true } else { return false } }
        let rest = entries.filter { if case .instructions = $0 { return false } else { return true } }

        return Transcript(entries: instructions + rest.suffix(count))
    }
}

#endif

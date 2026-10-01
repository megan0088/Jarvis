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

//
//  FocusRestorer.swift
//  Apl
//
//  Bubble harus mengambil fokus untuk bisa diketik, dan mengembalikannya saat
//  ditutup (spec C1 §4). Tanpa ini, menjawab satu pertanyaan berarti pengguna
//  harus mengklik kembali ke editor yang tadi dipakainya.
//

import AppKit

/// Bagian kecil `NSRunningApplication` yang benar-benar dipakai — supaya
/// pemulihan fokus bisa diuji tanpa app kedua.
protocol ActivatableApp: AnyObject {
    var isCurrent: Bool { get }
    var isTerminated: Bool { get }
    @discardableResult func activateNow() -> Bool
}

extension NSRunningApplication: ActivatableApp {
    var isCurrent: Bool { self == NSRunningApplication.current }

    @discardableResult
    func activateNow() -> Bool {
        activate(from: .current, options: [])
    }
}

@MainActor
final class FocusRestorer {

    private let frontmostApp: () -> (any ActivatableApp)?
    private var remembered: (any ActivatableApp)?

    init(frontmostApp: @escaping () -> (any ActivatableApp)? = { NSWorkspace.shared.frontmostApplication }) {
        self.frontmostApp = frontmostApp
    }

    /// Dipanggil TEPAT SEBELUM Apl mengambil fokus.
    func remember() {
        let app = frontmostApp()
        // Apl sendiri bukan tujuan pemulihan: mengaktifkannya lagi saat bubble
        // tutup akan merebut fokus dari jendela utama yang mungkin dibuka
        // pengguna di antaranya.
        remembered = (app?.isCurrent == true) ? nil : app
    }

    func restore() {
        defer { remembered = nil }
        guard let app = remembered, !app.isTerminated else { return }
        app.activateNow()
    }
}

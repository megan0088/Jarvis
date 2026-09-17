//
//  MainWindowLayout.swift
//  Apl
//
//  Ukuran jendela utama dan ambang mode compact (spec B §5).
//

import AppKit

enum MainWindowLayout {
    static let defaultSize = CGSize(width: 1000, height: 680)
    static let minimumSize = CGSize(width: 720, height: 520)
    /// Di bawah lebar ini stage diganti `CompactStageHeader`.
    static let compactThreshold: CGFloat = 820
    static let stageInset: CGFloat = 8

    static func isCompact(width: CGFloat) -> Bool {
        width < compactThreshold
    }

    /// Minimum untuk konten SwiftUI, agar JENDELA-nya 720×520.
    ///
    /// Dengan judul tersembunyi, SwiftUI tetap menambahkan tinggi area judul ke
    /// minimum konten: `minHeight: 520` menghasilkan jendela minimal 552pt.
    /// Tingginya dibaca dari AppKit, bukan ditulis tangan, karena berbeda
    /// antar versi macOS (28pt dulu, 32pt di macOS 26).
    @MainActor
    static var minimumContentSize: CGSize {
        let probe = NSRect(x: 0, y: 0, width: 100, height: 100)
        let titleBar = NSWindow.frameRect(forContentRect: probe, styleMask: [.titled]).height - probe.height
        return CGSize(width: minimumSize.width, height: minimumSize.height - titleBar)
    }
}

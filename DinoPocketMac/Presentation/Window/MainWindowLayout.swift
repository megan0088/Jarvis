//
//  MainWindowLayout.swift
//  Apl
//
//  Ukuran jendela utama dan ambang mode compact (spec B §5).
//

import CoreGraphics

enum MainWindowLayout {
    static let defaultSize = CGSize(width: 1000, height: 680)
    static let minimumSize = CGSize(width: 720, height: 520)
    /// Di bawah lebar ini stage diganti `CompactStageHeader`.
    static let compactThreshold: CGFloat = 820
    static let stageInset: CGFloat = 8

    static func isCompact(width: CGFloat) -> Bool {
        width < compactThreshold
    }
}

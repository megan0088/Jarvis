// Kembaran dari DinoPocketMac/Presentation/DesignSystem/AppFont.swift @ 580b3e9 (spec H §3.1).
// Perbaikan di satu sisi tidak sampai ke sisi lain — periksa keduanya.
//
//  AppFont.swift
//  Apl
//
//  Tipografi (spec B §7). Teks biasa memakai text style sistem; hanya judul
//  dan kode yang punya gaya sendiri.
//

import SwiftUI

enum AppFont {
    /// Judul berkarakter: SF Pro Rounded, semibold.
    static func title(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static var code: Font {
        .system(.body, design: .monospaced)
    }
}

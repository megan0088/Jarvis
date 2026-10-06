// Kembaran dari DinoPocketMac/Presentation/DesignSystem/Radius.swift @ 580b3e9 (spec H §3.1).
// Perbaikan di satu sisi tidak sampai ke sisi lain — periksa keduanya.
//
//  Radius.swift
//  Apl
//
//  Skala radius sudut (spec B §7). Composer memakai kapsul, bukan token ini.
//

import CoreGraphics

enum Radius {
    /// Tombol ikon.
    static let iconButton: CGFloat = 7
    /// Kontrol dan blok kode.
    static let control: CGFloat = 8
    /// Bubble, card, dan stage.
    static let card: CGFloat = 12
}

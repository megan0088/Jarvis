//
//  AppColors.swift
//  Apl
//
//  Token warna (spec B §7). Warna semantik sistem dipakai di mana pun bisa;
//  token custom hanya turunan aksen merek dan warna status.
//

import AppKit
import SwiftUI

enum AppColor {

    /// Aksen merek dari asset catalog.
    ///
    /// SENGAJA bukan `Color.accentColor`: di macOS, accent yang dipilih pengguna
    /// di System Settings › Appearance menimpa accent app, sehingga bubble,
    /// glow, dan tombol kirim bisa berubah ungu. Kontrol sistem tetap mengikuti
    /// pilihan pengguna — itu memang benar.
    static var accent: Color { Color("AccentColor") }

    /// Bubble pengguna: aksen 16% (dark) / 12% (light).
    static var userBubbleNSColor: NSColor { accentTint(dark: 0.16, light: 0.12) }
    static var userBubble: Color { Color(nsColor: userBubbleNSColor) }

    /// Glow di belakang robot: aksen 20% (dark) / 12% (light).
    static var stageGlowNSColor: NSColor { accentTint(dark: 0.20, light: 0.12) }
    static var stageGlow: Color { Color(nsColor: stageGlowNSColor) }

    static var statusOK: Color { Color(nsColor: .systemGreen) }
    static var statusWarning: Color { Color(nsColor: .systemOrange) }

    /// Panel stage: sedikit berbeda dari latar jendela di kedua tampilan.
    static var raisedSurface: Color { Color(nsColor: .underPageBackgroundColor) }
    /// Isi kontrol ringan: composer, chip, blok kode.
    static var controlFill: Color { Color(nsColor: .quaternarySystemFill) }
    static var card: Color { Color(nsColor: .controlBackgroundColor) }

    /// Aksen dengan alpha berbeda per tampilan. Provider dipanggil ulang setiap
    /// kali sistem me-resolve warna, jadi hasilnya ikut berganti saat
    /// light/dark berubah. Aksen di-resolve di dalam `appearance` yang diminta,
    /// bukan tampilan yang kebetulan sedang aktif.
    private static func accentTint(dark: CGFloat, light: CGFloat) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            var base = NSColor.controlAccentColor
            appearance.performAsCurrentDrawingAppearance {
                if let brand = NSColor(named: "AccentColor")?.usingColorSpace(.sRGB) {
                    base = brand
                }
            }
            return base.withAlphaComponent(isDark ? dark : light)
        }
    }
}

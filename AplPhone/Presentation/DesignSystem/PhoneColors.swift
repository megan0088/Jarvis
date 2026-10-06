//
//  PhoneColors.swift
//  Apl (iPhone)
//
//  Token warna iPhone (spec H §4.5). Nama-namanya sama dengan `AppColor` di
//  Mac; isinya warna semantik UIKit dan aksen merek dari asset catalog.
//  Satu-satunya berkas Presentation yang mengimpor UIKit.
//

import SwiftUI
import UIKit

enum PhoneColor {

    /// Aksen merek, teal yang sama dengan Mac.
    static var accent: Color { Color("AccentColor") }

    /// Bubble pengguna: aksen 16% (dark) / 12% (light).
    static var userBubble: Color { Color(uiColor: accentTint(dark: 0.16, light: 0.12)) }

    /// Glow di belakang robot: aksen 20% (dark) / 12% (light).
    static var stageGlow: Color { Color(uiColor: accentTint(dark: 0.20, light: 0.12)) }

    static var statusOK: Color { Color(uiColor: .systemGreen) }
    static var statusWarning: Color { Color(uiColor: .systemOrange) }

    /// Isi kontrol ringan: composer, chip, blok kode.
    static var controlFill: Color { Color(uiColor: .tertiarySystemFill) }
    static var card: Color { Color(uiColor: .secondarySystemBackground) }
    /// Ikon di atas tombol beraksen: kontras di teal gelap maupun terang.
    static var onAccent: Color { Color(uiColor: .systemBackground) }

    /// Di-resolve per tampilan, jadi ikut berganti saat terang/gelap berubah.
    private static func accentTint(dark: CGFloat, light: CGFloat) -> UIColor {
        UIColor { traits in
            let base = UIColor(named: "AccentColor")?.resolvedColor(with: traits) ?? .tintColor
            return base.withAlphaComponent(traits.userInterfaceStyle == .dark ? dark : light)
        }
    }
}

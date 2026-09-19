//
//  BubblePlacement.swift
//  Apl
//
//  Di mana bubble berdiri terhadap robot (spec C1 §4).
//
//  Fungsi murni, tanpa NSWindow dan tanpa NSScreen: semua yang dibutuhkan
//  masuk lewat parameter, sehingga sisi-mana dan jepitan tepi bisa diuji tanpa
//  menyalakan app.
//

import CoreGraphics

enum BubblePlacement {

    static let width: CGFloat = 360
    /// Batas area jawaban sebelum ia mulai digulir. Inilah batas yang benar-benar
    /// dirasakan pengguna.
    static let answerMaxHeight: CGFloat = 200
    /// Langit-langit seluruh bubble: area jawaban ditambah pertanyaan, tautan,
    /// composer, dan padding — diukur 318pt pada jawaban terpanjang, dibulatkan
    /// ke atas sebagai jaring pengaman.
    ///
    /// Bukan angka yang memotong isi: tinggi panel ditentukan
    /// `NSHostingView.intrinsicContentSize`, dan yang membatasinya adalah
    /// `answerMaxHeight` di dalam SwiftUI. Nilai ini dipakai untuk menghitung
    /// posisi, jadi ia harus TIDAK lebih kecil dari tinggi sebenarnya — kalau
    /// tidak, bubble bisa dihitung muat padahal tepi atasnya keluar layar.
    static let maxHeight: CGFloat = 360
    static let gap: CGFloat = 12

    /// - Parameters:
    ///   - robot: frame karakter dalam koordinat layar.
    ///   - screen: `visibleFrame` layar tempat karakter berada.
    ///   - contentHeight: tinggi yang diminta isi bubble.
    static func frame(robot: CGRect, screen: CGRect, contentHeight: CGFloat) -> CGRect {
        let height = min(max(contentHeight, 0), maxHeight)

        let roomRight = screen.maxX - robot.maxX
        let roomLeft = robot.minX - screen.minX
        // Kanan lebih disukai, tapi hanya kalau muat. Kalau dua-duanya sempit,
        // sisi yang lebih lega yang menang dan jepitan di bawah yang merapikan.
        let prefersRight = roomRight >= width + gap || roomRight >= roomLeft

        let rawX = prefersRight ? robot.maxX + gap : robot.minX - gap - width
        let x = clamp(rawX, lower: screen.minX + gap, upper: screen.maxX - gap - width)

        // Sejajar kepala: tepi atas bubble bertemu tepi atas karakter.
        let rawY = robot.maxY - height
        let y = clamp(rawY, lower: screen.minY + gap, upper: screen.maxY - gap - height)

        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Batas bawah menang saat layar lebih sempit dari bubble — lebih baik
    /// menempel di tepi kiri daripada melayang di luar layar.
    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        max(lower, min(value, max(lower, upper)))
    }
}

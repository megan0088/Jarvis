//
//  HomeHeaderMode.swift
//  Apl (iPhone)
//
//  Header robot: penuh atau ringkas (spec H §4.1).
//
//  Fungsi murni supaya satu jebakan bisa dites: percakapan yang hanya meluber
//  selama header besar. Meringkas memberi ruang, isinya muat lagi, gulirnya
//  kembali nol, header membesar — dan berulang selamanya.
//

import Foundation

enum HomeHeaderMode: Equatable {
    case full
    case compact

    /// Ruang yang didapat percakapan saat header meringkas, dalam point.
    /// Harus sama dengan selisih tinggi dua bentuk di `PhoneHomeHeader`.
    static let collapseGain: Double = 150
    /// Jarak gulir dari atas yang mulai meringkas header.
    static let collapseDistance: Double = 24

    /// - Parameters:
    ///   - distanceFromTop: seberapa jauh percakapan digulir dari puncaknya;
    ///     negatif saat ditarik melewati puncak.
    ///   - viewportHeight: tinggi daftar SAAT INI, dalam bentuk `current`.
    static func resolve(current: HomeHeaderMode,
                        distanceFromTop: Double,
                        contentHeight: Double,
                        viewportHeight: Double,
                        isAccessibilitySize: Bool,
                        isKeyboardVisible: Bool) -> HomeHeaderMode {
        if isAccessibilitySize || isKeyboardVisible { return .compact }

        switch current {
        case .compact:
            return distanceFromTop <= 0 ? .full : .compact
        case .full:
            // Hanya meringkas bila isinya tetap meluber SETELAH meringkas.
            let overflowsWhenCompact = contentHeight > viewportHeight + collapseGain
            return overflowsWhenCompact && distanceFromTop > collapseDistance ? .compact : .full
        }
    }
}

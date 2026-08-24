//
//  BuddySettingsStore.swift
//  DinoPocketMac
//
//  Preferensi tampilan Buddy Mode, dipersist ke UserDefaults.
//
//  Hanya `size` yang ada sekarang. Opacity, keep-on-top, dan strolling menyusul
//  di Wave 1 sesuai spec — ditambahkan saat benar-benar dipakai, bukan sebelumnya.
//

import Foundation

@Observable
final class BuddySettingsStore {

    /// Rentang yang diizinkan untuk sisi kotak karakter, dalam poin.
    ///
    /// Batas bawah dipilih agar karakter masih terbaca: robotnya hanya mengisi
    /// ~73% lebar kotak (extents 1.096 × 1.012 dinormalisasi ke sisi terpanjang),
    /// jadi kotak 120pt berarti robot yang benar-benar terlihat hanya ~87pt.
    static let sizeRange: ClosedRange<Double> = 120...400

    private enum Keys {
        static let size = "buddy.size"
    }

    private let defaults: UserDefaults

    /// Sisi kotak karakter dalam poin. Selalu di-clamp ke `sizeRange`.
    var size: Double {
        didSet {
            let clamped = Self.clamp(size)
            if clamped != size {
                size = clamped          // memicu didSet sekali lagi, lalu berhenti
                return
            }
            defaults.set(size, forKey: Keys.size)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.object(forKey: Keys.size) as? Double
        self.size = Self.clamp(stored ?? Self.defaultSize)
    }

    /// Default sengaja jauh di bawah 260pt yang dipakai demo — pada ukuran itu
    /// karakter mendominasi desktop alih-alih menemani.
    static let defaultSize: Double = 180

    static func clamp(_ value: Double) -> Double {
        min(max(value, sizeRange.lowerBound), sizeRange.upperBound)
    }
}

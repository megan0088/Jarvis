//
//  BuddySettingsStore.swift
//  AplMac
//
//  Preferensi tampilan Buddy Mode, dipersist ke UserDefaults.
//
//  Empat preferensi sesuai spec Fase A §4.1: ukuran, opacity, keep-on-top,
//  dan strolling.
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

    /// Rentang opacity. Batas bawah 0.3 supaya karakter tidak bisa dibuat
    /// nyaris tak terlihat lalu dikira hilang — Buddy Mode yang menyala tapi
    /// tak kasatmata adalah bug dari sudut pandang user.
    static let opacityRange: ClosedRange<Double> = 0.3...1.0

    private enum Keys {
        static let size = "buddy.size"
        static let opacity = "buddy.opacity"
        static let keepOnTop = "buddy.keepOnTop"
        static let strolling = "buddy.strolling"
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

    var opacity: Double {
        didSet {
            let clamped = Self.clampOpacity(opacity)
            if clamped != opacity { opacity = clamped; return }
            defaults.set(opacity, forKey: Keys.opacity)
        }
    }

    var keepOnTop: Bool {
        didSet { defaults.set(keepOnTop, forKey: Keys.keepOnTop) }
    }

    /// Berkeliaran pelan di desktop. Default MATI: perilaku yang bergerak
    /// sendiri di atas jendela kerja mudah terasa mengganggu, jadi user yang
    /// menyalakannya, bukan sebaliknya (spec §10, mitigasi risiko).
    var strolling: Bool {
        didSet { defaults.set(strolling, forKey: Keys.strolling) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedSize = defaults.object(forKey: Keys.size) as? Double
        self.size = Self.clamp(storedSize ?? Self.defaultSize)

        let storedOpacity = defaults.object(forKey: Keys.opacity) as? Double
        self.opacity = Self.clampOpacity(storedOpacity ?? 1.0)

        // `object(forKey:)` membedakan "belum pernah diset" dari "diset false";
        // `bool(forKey:)` tidak, dan itu akan mematikan default keepOnTop.
        self.keepOnTop = (defaults.object(forKey: Keys.keepOnTop) as? Bool) ?? true
        self.strolling = (defaults.object(forKey: Keys.strolling) as? Bool) ?? false
    }

    /// Default sengaja jauh di bawah 260pt yang dipakai demo — pada ukuran itu
    /// karakter mendominasi desktop alih-alih menemani.
    static let defaultSize: Double = 180

    static func clamp(_ value: Double) -> Double {
        min(max(value, sizeRange.lowerBound), sizeRange.upperBound)
    }

    static func clampOpacity(_ value: Double) -> Double {
        min(max(value, opacityRange.lowerBound), opacityRange.upperBound)
    }
}

extension BuddySettingsStore: LocallyErasable {
    /// Preferensi kembali ke bawaan, dan kuncinya ikut dibuang. Mengeset nilai
    /// memicu `didSet` yang menulis ulang kunci, jadi penghapusan kunci harus
    /// terjadi SETELAH nilai dikembalikan.
    @MainActor
    func eraseAllStoredData() {
        size = Self.defaultSize
        opacity = 1.0
        keepOnTop = true
        strolling = false
        for key in [Keys.size, Keys.opacity, Keys.keepOnTop, Keys.strolling] {
            defaults.removeObject(forKey: key)
        }
    }
}

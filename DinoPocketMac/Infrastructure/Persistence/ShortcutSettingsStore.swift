//
//  ShortcutSettingsStore.swift
//  Apl
//
//  Satu pilihan, satu kunci (spec C1 §5). Perubahan diteruskan lewat `onChange`
//  supaya pendaftar hotkey tidak perlu mengamati UserDefaults.
//

import Foundation
import Observation

@MainActor
@Observable
final class ShortcutSettingsStore {

    nonisolated static let presetKey = "shortcut.quickAsk"

    var preset: ShortcutPreset {
        didSet {
            guard preset != oldValue else { return }
            defaults.set(preset.rawValue, forKey: Self.presetKey)
            // Dipaksa turun ke disk; lihat catatan di `ProfileStore`.
            defaults.synchronize()
            onChange?(preset)
        }
    }

    /// Disetel pendaftar saat macOS menolak kombinasinya. Settings membacanya
    /// untuk satu baris peringatan; tidak pernah disimpan ke disk.
    var registrationFailed = false

    var onChange: ((ShortcutPreset) -> Void)?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.string(forKey: Self.presetKey)
        self.preset = stored.flatMap(ShortcutPreset.init(rawValue:)) ?? .default
    }
}

extension ShortcutSettingsStore: LocallyErasable {
    /// Urutannya disengaja: `preset` disetel lebih dulu supaya `onChange`
    /// mendaftarkan ulang tombol bawaan, baru kuncinya dibuang dari disk.
    func eraseAllStoredData() {
        preset = .default
        defaults.removeObject(forKey: Self.presetKey)
        defaults.synchronize()
    }
}

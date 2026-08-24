//
//  SystemMood.swift
//  SharedCore
//
//  Kondisi mesin yang diterjemahkan jadi suasana hati karakter.
//

import Foundation

enum SystemMood: String, CaseIterable, Codable, Equatable {
    /// Semuanya wajar.
    case normal
    /// Mesin bekerja keras — karakter ikut tampak sibuk.
    case busy
    /// Panas. Karakter lesu, dan animasi sebaiknya diperlambat.
    case hot
    /// Baterai menipis atau low power mode aktif.
    case lowBattery

    var label: String {
        switch self {
        case .normal:     "Normal"
        case .busy:       "Busy"
        case .hot:        "Warm"
        case .lowBattery: "Low battery"
        }
    }

    /// Pemetaan murni: menerima nilai, tidak membaca sistem.
    ///
    /// Dipisah dari `SystemStatusService` justru supaya bisa diuji tanpa
    /// memanaskan Mac atau menghabiskan baterai sungguhan — persis alasan §8
    /// spec meminta fungsi murni di sini.
    ///
    /// Urutan prioritas disengaja: panas kritis mengalahkan segalanya karena ia
    /// satu-satunya kondisi yang bisa merusak perangkat; baterai kritis
    /// berikutnya karena ia memaksa keputusan user; beban kerja paling akhir
    /// karena ia normal dan berlalu sendiri.
    static func from(thermalState: ProcessInfo.ThermalState,
                     isLowPowerMode: Bool,
                     batteryPercent: Int?,
                     isOnACPower: Bool) -> SystemMood {

        if thermalState == .serious || thermalState == .critical {
            return .hot
        }

        if isLowPowerMode {
            return .lowBattery
        }

        // Baterai rendah hanya berarti sesuatu saat tidak sedang dicas.
        if !isOnACPower, let percent = batteryPercent, percent <= 20 {
            return .lowBattery
        }

        if thermalState == .fair {
            return .busy
        }

        return .normal
    }
}

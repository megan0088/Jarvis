//
//  SystemStatusService.swift
//  AplMac
//
//  Membaca kondisi mesin dan menerjemahkannya jadi `SystemMood`.
//
//  Semua sinyal di sini sudah diverifikasi lolos App Sandbox (spec §3.4):
//  thermalState, isLowPowerModeEnabled, dan IOPSCopyPowerSourcesInfo semuanya
//  mengembalikan nilai nyata dari dalam app ber-entitlement app-sandbox.
//

import Foundation
import IOKit.ps

protocol SystemStatusProviding: Sendable {
    func currentMood() -> SystemMood
}

struct SystemStatusService: SystemStatusProviding {

    func currentMood() -> SystemMood {
        let info = ProcessInfo.processInfo
        let power = Self.readPowerSource()
        return SystemMood.from(
            thermalState: info.thermalState,
            isLowPowerMode: info.isLowPowerModeEnabled,
            batteryPercent: power.percent,
            isOnACPower: power.isOnAC
        )
    }

    /// Mac desktop tanpa baterai mengembalikan daftar kosong; itu diperlakukan
    /// sebagai "tersambung listrik, tanpa persentase" — bukan baterai 0%.
    static func readPowerSource() -> (percent: Int?, isOnAC: Bool) {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef],
              let first = sources.first,
              let desc = IOPSGetPowerSourceDescription(blob, first)?.takeUnretainedValue() as? [String: Any]
        else {
            return (nil, true)
        }

        let state = desc[kIOPSPowerSourceStateKey] as? String
        let isOnAC = state == kIOPSACPowerValue

        let current = desc[kIOPSCurrentCapacityKey] as? Int
        let max = desc[kIOPSMaxCapacityKey] as? Int
        let percent: Int? = {
            guard let current, let max, max > 0 else { return current }
            return Int((Double(current) / Double(max) * 100).rounded())
        }()

        return (percent, isOnAC)
    }
}

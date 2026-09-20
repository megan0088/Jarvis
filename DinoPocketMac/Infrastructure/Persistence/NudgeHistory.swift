//
//  NudgeHistory.swift
//  Apl
//
//  Apa yang sudah dikatakan dan kapan (spec C2 §4).
//
//  Dicatat SEBELUM balon tampil: kalau app berhenti di tengah, kuota tetap
//  terpakai. Satu sapaan yang hilang lebih baik daripada sapaan yang sama
//  muncul lagi setiap kali app dibuka.
//

import Foundation
import Observation

@MainActor
@Observable
final class NudgeHistory {

    nonisolated static let key = "nudge.history"

    struct Snapshot: Codable, Equatable {
        /// Kunci kejadian reminder yang sudah disapa → waktu kemunculannya.
        var shownReminderKeys: [String: Date] = [:]
        var lastMachineAt: Date?
        var machineCountToday = 0
        /// Hari yang sedang dihitung `machineCountToday`.
        var machineDay: Date?
        /// Balon terakhir yang lewat tanpa diklik.
        var lastIgnoredAt: Date?
    }

    private(set) var snapshot: Snapshot
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let restored = try? JSONDecoder().decode(Snapshot.self, from: data) {
            snapshot = restored
        } else {
            snapshot = Snapshot()
        }
    }

    func record(_ nudge: Nudge, at now: Date, calendar: Calendar = .current) {
        if let occurrence = nudge.occurrence {
            snapshot.shownReminderKeys[nudge.key] = occurrence
        }
        if nudge.isMachine {
            rollOverIfNeeded(now: now, calendar: calendar)
            snapshot.machineCountToday += 1
            snapshot.lastMachineAt = now
            snapshot.machineDay = calendar.startOfDay(for: now)
        }
        save()
    }

    func markIgnored(at now: Date) {
        snapshot.lastIgnoredAt = now
        save()
    }

    /// Dipanggil tiap detak sebelum aturan ditanya.
    func prune(now: Date, calendar: Calendar = .current) {
        rollOverIfNeeded(now: now, calendar: calendar)
        // Kejadian yang belum lewat TIDAK dibuang: kalau dibuang, reminder yang
        // sama akan disapa lagi beberapa menit kemudian.
        snapshot.shownReminderKeys = snapshot.shownReminderKeys.filter { $0.value > now }
        save()
    }

    private func rollOverIfNeeded(now: Date, calendar: Calendar) {
        let today = calendar.startOfDay(for: now)
        guard snapshot.machineDay != today else { return }
        snapshot.machineCountToday = 0
        snapshot.machineDay = today
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Self.key)
        // Dipaksa turun ke disk; lihat catatan di `ProfileStore`.
        defaults.synchronize()
    }
}

extension NudgeHistory: LocallyErasable {
    func eraseAllStoredData() {
        snapshot = Snapshot()
        defaults.removeObject(forKey: Self.key)
        defaults.synchronize()
    }
}

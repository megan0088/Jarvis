//
//  ReminderStore.swift
//  SharedCore
//
//  Penyimpanan reminder, terpisah dari wellness (spec A §4).
//
//  `UserDefaults.standard`, bukan suite app group: tidak ada widget di v1,
//  jadi tidak ada proses lain yang perlu membaca data ini.
//

import Foundation
import Observation

@MainActor
protocol ReminderStoring: AnyObject, LocallyErasable {
    var reminders: [Reminder] { get }
    func add(_ reminder: Reminder)
    func update(_ reminder: Reminder)
    func remove(id: Reminder.ID)
}

@MainActor
@Observable
final class ReminderStore: ReminderStoring {

    nonisolated static let storageKey = "apl.reminders"

    /// Reminder `.once` yang lewat lebih lama dari ini dibuang saat dimuat.
    nonisolated static let pruneAge: TimeInterval = 24 * 60 * 60

    private(set) var reminders: [Reminder]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard, now: Date = .now) {
        self.defaults = defaults
        let stored = defaults.data(forKey: Self.storageKey)
            .flatMap { try? JSONDecoder().decode([Reminder].self, from: $0) } ?? []
        self.reminders = Self.pruned(stored, now: now)
        if reminders.count != stored.count {
            save()
        }
    }

    nonisolated static func pruned(_ reminders: [Reminder], now: Date) -> [Reminder] {
        reminders.filter { reminder in
            guard case .once(let date) = reminder.rule else { return true }
            return now.timeIntervalSince(date) <= pruneAge
        }
    }

    func add(_ reminder: Reminder) {
        reminders.append(reminder)
        save()
    }

    func update(_ reminder: Reminder) {
        guard let index = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        reminders[index] = reminder
        save()
    }

    func remove(id: Reminder.ID) {
        reminders.removeAll { $0.id == id }
        save()
    }

    func eraseAllStoredData() {
        reminders = []
        defaults.removeObject(forKey: Self.storageKey)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(reminders) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

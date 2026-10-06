import Foundation
@testable import Apl

@MainActor
final class InMemoryReminderStore: ReminderStoring {
    private(set) var reminders: [Reminder] = []

    func add(_ reminder: Reminder) {
        reminders.append(reminder)
    }

    func update(_ reminder: Reminder) {
        guard let index = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        reminders[index] = reminder
    }

    func remove(id: Reminder.ID) {
        reminders.removeAll { $0.id == id }
    }

    func eraseAllStoredData() {
        reminders = []
    }
}

final class SpyReminderScheduler: ReminderScheduling, @unchecked Sendable {
    private(set) var syncCallCount = 0
    private(set) var lastSynced: [Reminder] = []
    private(set) var cancelAllCallCount = 0
    var authorizationAnswer = true
    var notificationsAllowedAnswer = true

    func requestAuthorization() async -> Bool { authorizationAnswer }

    func notificationsAllowed() async -> Bool { notificationsAllowedAnswer }

    func sync(_ reminders: [Reminder], now: Date) async {
        syncCallCount += 1
        lastSynced = reminders
    }

    func cancelAll() async {
        cancelAllCallCount += 1
    }
}

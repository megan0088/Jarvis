import Foundation
import Testing
@testable import Apl

@MainActor
struct EditReminderUseCaseTests {

    @Test func cancelRemovesTheReminderAndReschedulesTheRest() async {
        let store = InMemoryReminderStore()
        let scheduler = SpyReminderScheduler()
        let keep = Reminder(title: "Stretch", rule: .daily(hour: 9, minute: 0), createdAt: TestTime.now)
        let drop = Reminder(title: "Call mom", rule: .once(TestTime.date(2026, 9, 16, 15, 0)), createdAt: TestTime.now)
        store.add(keep)
        store.add(drop)

        await CancelReminderUseCase(store: store, notifications: scheduler, now: { TestTime.now })
            .execute(id: drop.id)

        #expect(store.reminders == [keep])
        #expect(scheduler.syncCallCount == 1)
        #expect(scheduler.lastSynced == [keep])
    }

    @Test func updateReplacesTheReminderAndReschedules() async {
        let store = InMemoryReminderStore()
        let scheduler = SpyReminderScheduler()
        var reminder = Reminder(title: "Call mom", rule: .once(TestTime.date(2026, 9, 16, 15, 0)),
                                createdAt: TestTime.now)
        store.add(reminder)

        reminder.title = "Call dad"
        reminder.rule = .daily(hour: 20, minute: 0)
        await UpdateReminderUseCase(store: store, notifications: scheduler, now: { TestTime.now })
            .execute(reminder)

        #expect(store.reminders == [reminder])
        #expect(scheduler.syncCallCount == 1)
        #expect(scheduler.lastSynced == [reminder])
    }
}

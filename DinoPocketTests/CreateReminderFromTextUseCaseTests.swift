import Foundation
import Testing
@testable import Apl

@MainActor
struct CreateReminderFromTextUseCaseTests {

    private func makeUseCase(store: InMemoryReminderStore,
                             scheduler: SpyReminderScheduler) -> CreateReminderFromTextUseCase {
        CreateReminderFromTextUseCase(store: store, notifications: scheduler, now: { TestTime.now },
                                      calendar: TestTime.calendar, locale: TestTime.locale)
    }

    @Test func reminderRequestIsSavedAndScheduled() async {
        let store = InMemoryReminderStore()
        let scheduler = SpyReminderScheduler()

        let output = await makeUseCase(store: store, scheduler: scheduler)
            .execute(text: "remind me to call mom at 3pm")

        guard case .created(let reminder, let confirmation) = output else {
            Issue.record("expected .created, got \(output)")
            return
        }
        #expect(reminder.title == "Call mom")
        #expect(reminder.rule == .once(TestTime.date(2026, 9, 16, 15, 0)))
        #expect(store.reminders == [reminder])
        #expect(scheduler.syncCallCount == 1)
        #expect(scheduler.lastSynced == [reminder])
        #expect(confirmation.hasPrefix("Done — I'll remind you to call mom today at"))
    }

    @Test func missingTimeAsksWithoutSaving() async {
        let store = InMemoryReminderStore()
        let scheduler = SpyReminderScheduler()

        let output = await makeUseCase(store: store, scheduler: scheduler)
            .execute(text: "remind me to drink water")

        #expect(output == .needsTime(title: "Drink water",
                                     question: "What time should I remind you to drink water?"))
        #expect(store.reminders.isEmpty)
        #expect(scheduler.syncCallCount == 0)
    }

    @Test func ordinaryChatIsNotAReminder() async {
        let store = InMemoryReminderStore()
        let scheduler = SpyReminderScheduler()

        let output = await makeUseCase(store: store, scheduler: scheduler)
            .execute(text: "what should I eat at 3pm?")

        #expect(output == .notAReminder)
        #expect(store.reminders.isEmpty)
    }

    @Test func completingWithATimeCreatesTheReminder() async {
        let store = InMemoryReminderStore()
        let scheduler = SpyReminderScheduler()

        let output = await makeUseCase(store: store, scheduler: scheduler)
            .complete(title: "Drink water", timeText: "5pm")

        guard case .created(let reminder, _)? = output else {
            Issue.record("expected .created, got \(String(describing: output))")
            return
        }
        #expect(reminder.title == "Drink water")
        #expect(reminder.rule == .once(TestTime.date(2026, 9, 16, 17, 0)))
        #expect(store.reminders.count == 1)
        #expect(scheduler.syncCallCount == 1)
    }

    @Test func completingWithoutATitleUsesTheDefault() async {
        let store = InMemoryReminderStore()

        let output = await makeUseCase(store: store, scheduler: SpyReminderScheduler())
            .complete(title: nil, timeText: "in 10 minutes")

        guard case .created(let reminder, _)? = output else {
            Issue.record("expected .created, got \(String(describing: output))")
            return
        }
        #expect(reminder.title == ReminderParser.defaultTitle)
    }

    @Test func completingWithSomethingElseReturnsNil() async {
        let store = InMemoryReminderStore()
        let scheduler = SpyReminderScheduler()

        let output = await makeUseCase(store: store, scheduler: scheduler)
            .complete(title: "Drink water", timeText: "tell me a joke")

        #expect(output == nil)
        #expect(store.reminders.isEmpty)
        #expect(scheduler.syncCallCount == 0)
    }
}

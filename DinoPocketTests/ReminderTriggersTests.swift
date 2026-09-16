import Foundation
import Testing
@testable import Apl

struct ReminderTriggersTests {

    @Test func onceBecomesAFullDateThatDoesNotRepeat() {
        let reminder = Reminder(title: "Call mom", rule: .once(TestTime.date(2026, 9, 16, 15, 0)),
                                createdAt: TestTime.now)

        let trigger = ReminderTriggers.trigger(for: reminder, calendar: TestTime.calendar)

        #expect(trigger.identifier == "apl.reminder.\(reminder.id.uuidString)")
        #expect(trigger.title == "Call mom")
        let c = trigger.components
        #expect([c.year, c.month, c.day, c.hour, c.minute, c.second] == [2026, 9, 16, 15, 0, 0])
        #expect(trigger.repeats == false)
    }

    @Test func dailyBecomesHourAndMinuteThatRepeats() {
        let reminder = Reminder(title: "Stretch", rule: .daily(hour: 9, minute: 30), createdAt: TestTime.now)

        let trigger = ReminderTriggers.trigger(for: reminder, calendar: TestTime.calendar)

        #expect(trigger.components.hour == 9)
        #expect(trigger.components.minute == 30)
        #expect(trigger.components.day == nil)
        #expect(trigger.repeats)
    }

    @Test func passedOnceRemindersAreNotScheduled() {
        let past = Reminder(title: "Past", rule: .once(TestTime.date(2026, 9, 16, 9, 0)), createdAt: TestTime.now)
        let future = Reminder(title: "Future", rule: .once(TestTime.date(2026, 9, 16, 15, 0)), createdAt: TestTime.now)

        let plan = ReminderTriggers.plan(for: [past, future], now: TestTime.now, calendar: TestTime.calendar)

        #expect(plan.map(\.title) == ["Future"])
    }

    /// macOS membatasi jumlah notifikasi tertunda. Yang dijadwalkan harus yang
    /// TERDEKAT, bukan yang kebetulan pertama di daftar.
    @Test func onlyTheNearestSixtyAreScheduled() {
        let reminders = (1...70).reversed().map { minutes in
            Reminder(title: "R\(minutes)",
                     rule: .once(TestTime.now.addingTimeInterval(TimeInterval(minutes * 60))),
                     createdAt: TestTime.now)
        }

        let plan = ReminderTriggers.plan(for: reminders, now: TestTime.now, calendar: TestTime.calendar)

        #expect(plan.count == ReminderTriggers.maxScheduled)
        #expect(plan.map(\.title) == (1...60).map { "R\($0)" })
    }
}

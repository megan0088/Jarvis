import Foundation
import Testing
@testable import Apl

struct ReminderTests {

    private let calendar = TestTime.calendar

    @Test func onceInTheFutureIsItsOwnDate() {
        let at = TestTime.date(2026, 9, 16, 15, 0)
        let reminder = Reminder(title: "Call mom", rule: .once(at))
        #expect(reminder.nextOccurrence(after: TestTime.now, calendar: calendar) == at)
    }

    @Test func onceInThePastHasNoNextOccurrence() {
        let reminder = Reminder(title: "Call mom", rule: .once(TestTime.date(2026, 9, 16, 9, 0)))
        #expect(reminder.nextOccurrence(after: TestTime.now, calendar: calendar) == nil)
    }

    @Test func dailyLaterTodayIsToday() {
        let reminder = Reminder(title: "Stretch", rule: .daily(hour: 15, minute: 30))
        #expect(reminder.nextOccurrence(after: TestTime.now, calendar: calendar)
                == TestTime.date(2026, 9, 16, 15, 30))
    }

    @Test func dailyAlreadyPassedIsTomorrow() {
        let reminder = Reminder(title: "Stretch", rule: .daily(hour: 9, minute: 0))
        #expect(reminder.nextOccurrence(after: TestTime.now, calendar: calendar)
                == TestTime.date(2026, 9, 17, 9, 0))
    }

    /// Tepat di menit yang sama berarti kemunculan hari ini sudah terjadi.
    @Test func dailyAtTheCurrentMinuteIsTomorrow() {
        let reminder = Reminder(title: "Stretch", rule: .daily(hour: 10, minute: 0))
        #expect(reminder.nextOccurrence(after: TestTime.now, calendar: calendar)
                == TestTime.date(2026, 9, 17, 10, 0))
    }

    @Test func dailyCrossesMidnight() {
        let lateNight = TestTime.date(2026, 9, 16, 23, 30)
        let reminder = Reminder(title: "Sleep", rule: .daily(hour: 0, minute: 15))
        #expect(reminder.nextOccurrence(after: lateNight, calendar: calendar)
                == TestTime.date(2026, 9, 17, 0, 15))
    }

    @Test func bothRulesRoundTripThroughCodable() throws {
        let reminders = [
            Reminder(title: "Call mom", rule: .once(TestTime.date(2026, 9, 16, 15, 0)), createdAt: TestTime.now),
            Reminder(title: "Stretch", rule: .daily(hour: 9, minute: 0), createdAt: TestTime.now),
        ]
        let data = try JSONEncoder().encode(reminders)
        #expect(try JSONDecoder().decode([Reminder].self, from: data) == reminders)
    }
}

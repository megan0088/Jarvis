import Foundation
import Testing
@testable import Apl

struct ReminderDraftTests {

    private let calendar = TestTime.calendar

    private func stretch(at date: Date) -> Reminder {
        Reminder(title: "Stretch", rule: .once(date), createdAt: TestTime.now)
    }

    @Test func onceReminderKeepsItsDateAndTime() {
        let date = TestTime.date(2026, 9, 18, 15, 30)

        let draft = ReminderDraft(stretch(at: date), now: TestTime.now, calendar: calendar)

        #expect(draft.title == "Stretch")
        #expect(draft.frequency == .once)
        #expect(draft.time == date)
    }

    @Test func dailyReminderIsShownAsTodayAtItsTime() {
        let water = Reminder(title: "Water", rule: .daily(hour: 9, minute: 15), createdAt: TestTime.now)

        let draft = ReminderDraft(water, now: TestTime.now, calendar: calendar)

        #expect(draft.frequency == .daily)
        #expect(draft.time == TestTime.date(2026, 9, 16, 9, 15))
    }

    @Test func applyingSwitchesBetweenOnceAndDaily() {
        let original = stretch(at: TestTime.date(2026, 9, 16, 15, 0))
        var draft = ReminderDraft(original, now: TestTime.now, calendar: calendar)

        draft.frequency = .daily
        draft.time = TestTime.date(2026, 9, 16, 16, 45)
        let daily = draft.applied(to: original, now: TestTime.now, calendar: calendar)
        #expect(daily?.rule == .daily(hour: 16, minute: 45))
        #expect(daily?.id == original.id)

        // DatePicker membawa detik dari nilai awal; reminder tetap tepat di menitnya.
        draft.frequency = .once
        draft.time = TestTime.date(2026, 9, 17, 8, 0).addingTimeInterval(42)
        #expect(draft.applied(to: original, now: TestTime.now, calendar: calendar)?.rule
                == .once(TestTime.date(2026, 9, 17, 8, 0)))
    }

    @Test func emptyTitlesAndPastTimesAreRejected() {
        let original = stretch(at: TestTime.date(2026, 9, 16, 15, 0))
        var draft = ReminderDraft(original, now: TestTime.now, calendar: calendar)

        draft.title = "   "
        #expect(draft.applied(to: original, now: TestTime.now, calendar: calendar) == nil)

        draft.title = "  Stretch  "
        draft.time = TestTime.date(2026, 9, 16, 9, 0)
        #expect(draft.applied(to: original, now: TestTime.now, calendar: calendar) == nil)

        // Jam yang sudah lewat sah untuk reminder harian: ia berbunyi besok.
        draft.frequency = .daily
        #expect(draft.applied(to: original, now: TestTime.now, calendar: calendar)?.title == "Stretch")
    }
}

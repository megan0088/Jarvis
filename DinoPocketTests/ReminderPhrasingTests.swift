import Foundation
import Testing
@testable import Apl

/// "Sekarang" = Rabu 16 Sep 2026 10.00 WIB. Jam dibandingkan lewat
/// `ReminderPhrasing.time` karena format sistem memakai spasi sempit
/// (U+202F) sebelum AM/PM, yang tidak terlihat bila ditulis literal.
struct ReminderPhrasingTests {

    private func time(_ day: Int, _ hour: Int, _ minute: Int) -> String {
        ReminderPhrasing.time(TestTime.date(2026, 9, day, hour, minute),
                              calendar: TestTime.calendar, locale: TestTime.locale)
    }

    private func confirm(_ title: String, _ rule: Reminder.Rule) -> String {
        ReminderPhrasing.confirmation(title: title, rule: rule, now: TestTime.now,
                                      calendar: TestTime.calendar, locale: TestTime.locale)
    }

    @Test func timeUsesTheLocaleClock() {
        let text = time(16, 15, 0)
        #expect(text.contains("3:00"))
        #expect(text.contains("PM"))
    }

    @Test func sameDayIsToday() {
        #expect(confirm("Call mom", .once(TestTime.date(2026, 9, 16, 15, 0)))
                == "Done — I'll remind you to call mom today at \(time(16, 15, 0)).")
    }

    @Test func nextDayIsTomorrow() {
        #expect(confirm("Send the report", .once(TestTime.date(2026, 9, 17, 9, 0)))
                == "Done — I'll remind you to send the report tomorrow at \(time(17, 9, 0)).")
    }

    @Test func withinAnHourCountsMinutes() {
        #expect(confirm("Check the oven", .once(TestTime.now.addingTimeInterval(20 * 60)))
                == "Done — I'll remind you to check the oven in 20 minutes (\(time(16, 10, 20))).")
    }

    @Test func oneMinuteIsSingular() {
        #expect(confirm("Breathe", .once(TestTime.now.addingTimeInterval(60)))
                == "Done — I'll remind you to breathe in 1 minute (\(time(16, 10, 1))).")
    }

    @Test func dailySaysEveryDay() {
        #expect(confirm("Stretch", .daily(hour: 9, minute: 0))
                == "Done — I'll remind you to stretch every day at \(time(16, 9, 0)).")
    }

    @Test func defaultTitleOmitsTheSubject() {
        #expect(confirm("Reminder", .once(TestTime.date(2026, 9, 16, 15, 0)))
                == "Done — I'll remind you today at \(time(16, 15, 0)).")
    }

    @Test func innerCapitalsAreKept() {
        #expect(confirm("Call Mom", .once(TestTime.date(2026, 9, 16, 15, 0))).contains("to call Mom today"))
    }

    @Test func timeQuestionMentionsTheTitleWhenThereIsOne() {
        #expect(ReminderPhrasing.timeQuestion(title: "Call mom") == "What time should I remind you to call mom?")
        #expect(ReminderPhrasing.timeQuestion(title: nil) == "What time should I remind you?")
    }
}

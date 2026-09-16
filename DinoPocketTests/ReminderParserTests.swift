import Foundation
import Testing
@testable import Apl

struct ReminderParseCase: Sendable, CustomTestStringConvertible {
    let input: String
    let expected: ReminderParseResult
    var testDescription: String { input }

    init(_ input: String, _ expected: ReminderParseResult) {
        self.input = input
        self.expected = expected
    }
}

struct TimeOnlyCase: Sendable, CustomTestStringConvertible {
    let input: String
    let expected: Reminder.Rule?
    var testDescription: String { input }

    init(_ input: String, _ expected: Reminder.Rule?) {
        self.input = input
        self.expected = expected
    }
}

/// "Sekarang" = Rabu 16 Sep 2026 10.00 WIB (`TestTime.now`).
struct ReminderParserTests {

    private static func on(_ day: Int, _ hour: Int, _ minute: Int) -> Date {
        TestTime.date(2026, 9, day, hour, minute)
    }

    private static func fromNow(_ seconds: TimeInterval) -> Date {
        TestTime.now.addingTimeInterval(seconds)
    }

    static let reminderCases: [ReminderParseCase] = [
        .init("remind me to call mom at 3pm", .reminder(title: "Call mom", rule: .once(on(16, 15, 0)))),
        .init("Remind me to call Mom at 3:30 PM", .reminder(title: "Call Mom", rule: .once(on(16, 15, 30)))),
        .init("remind me to call mom at 15:00", .reminder(title: "Call mom", rule: .once(on(16, 15, 0)))),
        .init("remind me to stretch at 9am", .reminder(title: "Stretch", rule: .once(on(17, 9, 0)))),
        .init("remind me today at 9am to stretch", .reminder(title: "Stretch", rule: .once(on(17, 9, 0)))),
        .init("remind me tomorrow at 9 to send the report",
              .reminder(title: "Send the report", rule: .once(on(17, 9, 0)))),
        .init("remind me in 20 minutes to check the oven",
              .reminder(title: "Check the oven", rule: .once(fromNow(20 * 60)))),
        .init("remind me in an hour to take a break",
              .reminder(title: "Take a break", rule: .once(fromNow(3600)))),
        .init("remind me in 1 minute to breathe", .reminder(title: "Breathe", rule: .once(fromNow(60)))),
        .init("remind me in a minute to stand up", .reminder(title: "Stand up", rule: .once(fromNow(60)))),
        .init("remind me in 2 hours to call dad", .reminder(title: "Call dad", rule: .once(fromNow(7200)))),
        .init("remind me every day at 9am to stretch", .reminder(title: "Stretch", rule: .daily(hour: 9, minute: 0))),
        .init("remind me daily at 21:30 to journal", .reminder(title: "Journal", rule: .daily(hour: 21, minute: 30))),
        .init("remind me at 8pm every day to read", .reminder(title: "Read", rule: .daily(hour: 20, minute: 0))),
        .init("set a reminder to stretch at 09:30", .reminder(title: "Stretch", rule: .once(on(17, 9, 30)))),
        .init("remind me to drink water at 12am", .reminder(title: "Drink water", rule: .once(on(17, 0, 0)))),
        .init("remind me to eat lunch at 12pm", .reminder(title: "Eat lunch", rule: .once(on(16, 12, 0)))),
        .init("Can you remind me to call mom at 3pm?", .reminder(title: "Call mom", rule: .once(on(16, 15, 0)))),
        .init("I want you to remind me to call mom at 3pm",
              .reminder(title: "Call mom", rule: .once(on(16, 15, 0)))),
        .init("at 5pm remind me to stretch", .reminder(title: "Stretch", rule: .once(on(16, 17, 0)))),
        .init("remind me to go to the gym at 6pm", .reminder(title: "Go to the gym", rule: .once(on(16, 18, 0)))),
        .init("remind me at 3pm", .reminder(title: "Reminder", rule: .once(on(16, 15, 0)))),
        .init("remind me to meet at the cafe at 5pm",
              .reminder(title: "Meet at the cafe", rule: .once(on(16, 17, 0)))),
    ]

    static let missingTimeCases: [ReminderParseCase] = [
        .init("remind me to drink water", .missingTime(title: "Drink water")),
        .init("remind me", .missingTime(title: nil)),
        .init("remind me tomorrow to call mom", .missingTime(title: "Call mom")),
        .init("remind me to call at 25:00", .missingTime(title: "Call at 25:00")),
    ]

    static let ordinaryChatCases: [ReminderParseCase] = [
        .init("what should I eat at 3pm?", .notAReminder),
        .init("I need to remember my keys", .notAReminder),
        .init("reminders are annoying", .notAReminder),
    ]

    static let timeOnlyCases: [TimeOnlyCase] = [
        .init("5pm", .once(on(16, 17, 0))),
        .init("at 5pm", .once(on(16, 17, 0))),
        .init("5pm.", .once(on(16, 17, 0))),
        .init("17:00", .once(on(16, 17, 0))),
        .init("in 10 minutes", .once(fromNow(600))),
        .init("tomorrow at 9", .once(on(17, 9, 0))),
        .init("every day at 9am", .daily(hour: 9, minute: 0)),
    ]

    static let notTimeOnlyCases: [TimeOnlyCase] = [
        .init("5", nil),
        .init("tell me a joke", nil),
        .init("5pm please", nil),
    ]

    @Test(arguments: ReminderParserTests.reminderCases)
    func parsesReminders(_ c: ReminderParseCase) {
        #expect(ReminderParser.parse(c.input, now: TestTime.now, calendar: TestTime.calendar) == c.expected)
    }

    @Test(arguments: ReminderParserTests.missingTimeCases)
    func detectsMissingTime(_ c: ReminderParseCase) {
        #expect(ReminderParser.parse(c.input, now: TestTime.now, calendar: TestTime.calendar) == c.expected)
    }

    @Test(arguments: ReminderParserTests.ordinaryChatCases)
    func ignoresOrdinaryChat(_ c: ReminderParseCase) {
        #expect(ReminderParser.parse(c.input, now: TestTime.now, calendar: TestTime.calendar) == c.expected)
    }

    @Test(arguments: ReminderParserTests.timeOnlyCases)
    func parsesTimeOnlyAnswers(_ c: TimeOnlyCase) {
        #expect(ReminderParser.parseTimeOnly(c.input, now: TestTime.now, calendar: TestTime.calendar) == c.expected)
    }

    @Test(arguments: ReminderParserTests.notTimeOnlyCases)
    func rejectsAnswersThatAreNotJustATime(_ c: TimeOnlyCase) {
        #expect(ReminderParser.parseTimeOnly(c.input, now: TestTime.now, calendar: TestTime.calendar) == nil)
    }
}

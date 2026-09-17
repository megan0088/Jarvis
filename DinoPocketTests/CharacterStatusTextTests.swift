import Foundation
import Testing
@testable import Apl

struct CharacterStatusTextTests {

    private func text(_ behavior: CharacterBehavior, at hour: Int = 10, minute: Int = 0,
                      available: Bool = true, celebrated: Date? = nil) -> String {
        CharacterStatusText.text(for: behavior, now: TestTime.date(2026, 9, 16, hour, minute),
                                 calendar: TestTime.calendar, locale: TestTime.locale,
                                 intelligenceAvailable: available, celebratedTime: celebrated)
    }

    @Test func greetingFollowsTheClock() {
        #expect(text(.greet, at: 0) == "Good morning!")
        #expect(text(.greet, at: 11, minute: 59) == "Good morning!")
        #expect(text(.greet, at: 12) == "Good afternoon!")
        #expect(text(.greet, at: 17, minute: 59) == "Good afternoon!")
        #expect(text(.greet, at: 18) == "Good evening!")
    }

    /// Format jam diambil dari ReminderPhrasing, supaya sama dengan kalimat
    /// konfirmasi di chat (en_US memakai spasi sempit sebelum "PM").
    @Test func celebrationNamesTheReminderTime() {
        let threePM = TestTime.date(2026, 9, 16, 15, 0)
        let clock = ReminderPhrasing.time(threePM, calendar: TestTime.calendar, locale: TestTime.locale)
        #expect(text(.celebrate, celebrated: threePM) == "Reminder set for \(clock)")
    }

    @Test func celebrationWithoutATimeStaysGeneric() {
        #expect(text(.celebrate) == "Reminder set")
    }

    @Test func sleepyExplainsWhy() {
        #expect(text(.sleepy, available: false) == "Apple Intelligence is off")
        #expect(text(.sleepy, available: true) == "Something went wrong")
    }

    @Test func idleAndThinkingUseFixedCopy() {
        #expect(text(.idle) == "Here when you need me")
        #expect(text(.thinking) == "Thinking…")
    }

    @Test func voiceOverLabelNamesTheCharacterAndItsState() {
        #expect(CharacterStatusText.accessibilityLabel(for: .thinking) == "Apl, thinking")
        let labels = Set(CharacterBehavior.allCases.map { CharacterStatusText.accessibilityLabel(for: $0) })
        #expect(labels.count == CharacterBehavior.allCases.count)
    }
}

import Foundation
import Testing
@testable import Jarvis

struct ReminderIntentTests {
    @Test func parsesWaterWithPM() {
        let s = ReminderIntent.parse("remind me to drink water at 3pm")
        #expect(s?.kind == .water); #expect(s?.hour == 15); #expect(s?.minute == 0)
    }
    @Test func parsesStretchWith24hColon() {
        let s = ReminderIntent.parse("set a reminder to stretch at 09:30")
        #expect(s?.kind == .stretch); #expect(s?.hour == 9); #expect(s?.minute == 30)
    }
    @Test func parsesMealWith12pm() {
        let s = ReminderIntent.parse("reminder: eat lunch at 12:30pm")
        #expect(s?.kind == .meal); #expect(s?.hour == 12); #expect(s?.minute == 30)
    }
    @Test func nilWhenNoReminderKeyword() {
        #expect(ReminderIntent.parse("what should I eat at 3pm?") == nil)
    }
    @Test func nilWhenNoTime() {
        #expect(ReminderIntent.parse("remind me to drink water") == nil)
    }
    @Test func nilWhenNoKind() {
        #expect(ReminderIntent.parse("remind me at 3pm") == nil)
    }
    @Test func parses12amToMidnight() {
        let s = ReminderIntent.parse("remind me to drink water at 12am")
        #expect(s?.hour == 0); #expect(s?.minute == 0)
    }
}

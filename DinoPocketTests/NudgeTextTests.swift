import Foundation
import Testing
@testable import Apl

struct NudgeTextTests {

    /// Kalimatnya pasti, bukan acak: sapaan acak dihapus di C1 justru karena
    /// tidak punya aturan.
    @Test func reminderShowsTitleAndTime() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Jakarta")!
        let at = calendar.date(from: DateComponents(year: 2026, month: 9, day: 20,
                                                    hour: 15, minute: 0))!
        let text = NudgeText.reminderSoon(title: "Stretch", at: at,
                                          locale: Locale(identifier: "en_US"),
                                          timeZone: calendar.timeZone)
        #expect(text.hasPrefix("Stretch · "))
        #expect(text.contains("3:00"))
    }

    @Test func machineSpeaksOnlyWhenSomethingIsWrong() {
        #expect(NudgeText.machine(.hot) != nil)
        #expect(NudgeText.machine(.lowBattery) != nil)
        #expect(NudgeText.machine(.normal) == nil)
        #expect(NudgeText.machine(.busy) == nil)
    }

    @Test func machineSentencesDiffer() {
        #expect(NudgeText.machine(.hot) != NudgeText.machine(.lowBattery))
    }
}

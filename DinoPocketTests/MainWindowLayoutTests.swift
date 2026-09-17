import Foundation
import Testing
@testable import Apl

struct MainWindowLayoutTests {

    @Test func stageCollapsesBelowEightHundredTwentyPoints() {
        #expect(MainWindowLayout.isCompact(width: 819.5))
        #expect(!MainWindowLayout.isCompact(width: 820))
        #expect(!MainWindowLayout.isCompact(width: MainWindowLayout.defaultSize.width))
        #expect(MainWindowLayout.isCompact(width: MainWindowLayout.minimumSize.width))
    }

    @MainActor @Test func dateHeaderIsRelativeToToday() {
        let calendar = TestTime.calendar

        #expect(ConversationView.dayLabel(for: TestTime.now, now: TestTime.now, calendar: calendar) == "Today")
        #expect(ConversationView.dayLabel(for: TestTime.date(2026, 9, 15, 20, 0), now: TestTime.now,
                                          calendar: calendar) == "Yesterday")
    }
}

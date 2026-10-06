import Testing
@testable import Apl

struct BellBadgeTests {

    @Test func noRemindersMeansNoNumber() {
        #expect(BellBadge.text(upcomingCount: 0) == nil)
        #expect(BellBadge.text(upcomingCount: -1) == nil)
    }

    @Test func countsAreShownAsTheyAre() {
        #expect(BellBadge.text(upcomingCount: 1) == "1")
        #expect(BellBadge.text(upcomingCount: 99) == "99")
    }

    /// Tiga digit tidak muat di lencana, dan angka pastinya tidak berguna.
    @Test func largeCountsAreCapped() {
        #expect(BellBadge.text(upcomingCount: 100) == "99+")
        #expect(BellBadge.text(upcomingCount: 5000) == "99+")
    }

    @Test func voiceOverHearsTheCount() {
        #expect(BellBadge.accessibilityLabel(upcomingCount: 0) == "Reminders")
        #expect(BellBadge.accessibilityLabel(upcomingCount: 1) == "Reminders, 1 upcoming")
        #expect(BellBadge.accessibilityLabel(upcomingCount: 3) == "Reminders, 3 upcoming")
    }
}

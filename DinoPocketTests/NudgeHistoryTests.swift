import Foundation
import Testing
@testable import Apl

@MainActor
struct NudgeHistoryTests {

    private func isolatedDefaults(_ name: String) -> UserDefaults {
        let suite = "test.nudge.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func reminderNudgesAreRememberedByOccurrence() {
        let history = NudgeHistory(defaults: isolatedDefaults(#function))
        let at = now.addingTimeInterval(300)
        history.record(Nudge(kind: .reminderSoon(UUID(), at: at), text: "x"), at: now)
        #expect(history.snapshot.shownReminderKeys.count == 1)
    }

    @Test func machineNudgesCountTowardTheDay() {
        let history = NudgeHistory(defaults: isolatedDefaults(#function))
        history.record(Nudge(kind: .machine(.hot), text: "x"), at: now)
        #expect(history.snapshot.machineCountToday == 1)
        #expect(history.snapshot.lastMachineAt == now)
    }

    @Test func survivesRelaunch() {
        let defaults = isolatedDefaults(#function)
        NudgeHistory(defaults: defaults).record(Nudge(kind: .machine(.hot), text: "x"), at: now)
        #expect(NudgeHistory(defaults: defaults).snapshot.machineCountToday == 1)
    }

    /// Hitungan harian berganti hari; catatan kejadian yang sudah lewat dibuang
    /// supaya kunci tidak menumpuk selamanya.
    @Test func pruningResetsTheDayAndDropsOldKeys() {
        let history = NudgeHistory(defaults: isolatedDefaults(#function))
        history.record(Nudge(kind: .machine(.hot), text: "x"), at: now)
        history.record(Nudge(kind: .reminderSoon(UUID(), at: now), text: "x"), at: now)

        history.prune(now: now.addingTimeInterval(86_400))
        #expect(history.snapshot.machineCountToday == 0)
        #expect(history.snapshot.shownReminderKeys.isEmpty)
    }

    /// Kejadian yang BELUM lewat tidak boleh dibuang, walau harinya berganti:
    /// kalau dibuang, reminder yang sama disapa dua kali.
    @Test func pruningKeepsOccurrencesThatHaveNotHappenedYet() {
        let history = NudgeHistory(defaults: isolatedDefaults(#function))
        let soon = now.addingTimeInterval(120)
        history.record(Nudge(kind: .reminderSoon(UUID(), at: soon), text: "x"), at: now)
        history.prune(now: now.addingTimeInterval(60))
        #expect(history.snapshot.shownReminderKeys.count == 1)
    }

    @Test func ignoringIsRemembered() {
        let history = NudgeHistory(defaults: isolatedDefaults(#function))
        history.markIgnored(at: now)
        #expect(history.snapshot.lastIgnoredAt == now)
    }

    @Test func eraseLeavesNoKeyBehind() {
        let defaults = isolatedDefaults(#function)
        let history = NudgeHistory(defaults: defaults)
        history.record(Nudge(kind: .machine(.hot), text: "x"), at: now)
        history.eraseAllStoredData()
        #expect(defaults.data(forKey: NudgeHistory.key) == nil)
        #expect(history.snapshot.machineCountToday == 0)
    }
}

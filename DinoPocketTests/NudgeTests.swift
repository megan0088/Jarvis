import Foundation
import Testing
@testable import Apl

struct NudgeTests {

    /// Kunci kuota memuat WAKTU kemunculan, bukan hanya id: reminder harian
    /// punya kejadian berbeda tiap hari dan masing-masing boleh disapa sekali.
    @Test func reminderKeyIncludesTheOccurrence() {
        let id = UUID()
        let monday = Date(timeIntervalSince1970: 1_000_000)
        let tuesday = monday.addingTimeInterval(86_400)
        let first = Nudge(kind: .reminderSoon(id, at: monday), text: "x")
        let second = Nudge(kind: .reminderSoon(id, at: tuesday), text: "x")
        #expect(first.key != second.key)
    }

    @Test func sameOccurrenceHasTheSameKey() {
        let id = UUID()
        let at = Date(timeIntervalSince1970: 1_000_000)
        #expect(Nudge(kind: .reminderSoon(id, at: at), text: "a").key
                == Nudge(kind: .reminderSoon(id, at: at), text: "b").key)
    }

    @Test func machineNudgesAreMarkedAsSuch() {
        #expect(Nudge(kind: .machine(.hot), text: "x").isMachine)
        #expect(!Nudge(kind: .reminderSoon(UUID(), at: .now), text: "x").isMachine)
    }

    @Test func onlyReminderNudgesCarryAnOccurrence() {
        let at = Date(timeIntervalSince1970: 1_000_000)
        #expect(Nudge(kind: .reminderSoon(UUID(), at: at), text: "x").occurrence == at)
        #expect(Nudge(kind: .machine(.hot), text: "x").occurrence == nil)
    }
}

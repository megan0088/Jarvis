import Foundation
import Testing
@testable import Apl

struct NudgeRulesTests {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func reminder(in seconds: TimeInterval, title: String = "Stretch") -> Reminder {
        Reminder(title: title, rule: .once(now.addingTimeInterval(seconds)))
    }

    private func next(reminders: [Reminder] = [],
                      mood: SystemMood = .normal,
                      moodSince: Date? = nil,
                      history: NudgeHistory.Snapshot = .init(),
                      signals: QuietSignals = QuietSignals()) -> Nudge? {
        NudgeRules.next(now: now, reminders: reminders, mood: mood, moodSince: moodSince,
                        history: history, signals: signals)
    }

    // MARK: - Reminder

    @Test func reminderWithinTheLeadWindowIsAnnounced() {
        let nudge = next(reminders: [reminder(in: 4 * 60)])
        #expect(nudge?.isMachine == false)
        #expect(nudge?.text.hasPrefix("Stretch") == true)
    }

    @Test func reminderFurtherOutIsNotAnnouncedYet() {
        #expect(next(reminders: [reminder(in: 20 * 60)]) == nil)
    }

    /// Yang sudah lewat tidak disapa: notifikasinya sudah berbunyi.
    @Test func reminderThatAlreadyPassedIsSilent() {
        #expect(next(reminders: [reminder(in: -60)]) == nil)
    }

    @Test func theSoonestReminderWins() {
        let nudge = next(reminders: [reminder(in: 280, title: "Later"),
                                     reminder(in: 60, title: "Sooner")])
        #expect(nudge?.text.hasPrefix("Sooner") == true)
    }

    @Test func anOccurrenceIsAnnouncedOnlyOnce() {
        let item = reminder(in: 120)
        var history = NudgeHistory.Snapshot()
        let announced = next(reminders: [item])!
        history.shownReminderKeys[announced.key] = now.addingTimeInterval(120)
        #expect(next(reminders: [item], history: history) == nil)
    }

    /// Kuota harian tidak berlaku untuk reminder: pengguna sendiri yang
    /// memintanya dengan membuat reminder itu.
    @Test func remindersIgnoreTheDailyQuota() {
        var history = NudgeHistory.Snapshot()
        history.machineCountToday = 99
        history.lastMachineAt = now.addingTimeInterval(-60)
        #expect(next(reminders: [reminder(in: 120)], history: history) != nil)
    }

    // MARK: - Mesin

    @Test func machineNudgeNeedsThePoorStateToPersist() {
        #expect(next(mood: .hot, moodSince: now.addingTimeInterval(-60)) == nil)
        #expect(next(mood: .hot, moodSince: now.addingTimeInterval(-11 * 60)) != nil)
    }

    @Test func normalMachineStateSaysNothing() {
        #expect(next(mood: .normal, moodSince: now.addingTimeInterval(-3600)) == nil)
        #expect(next(mood: .busy, moodSince: now.addingTimeInterval(-3600)) == nil)
    }

    @Test func machineNudgesWaitFourHours() {
        var history = NudgeHistory.Snapshot()
        history.lastMachineAt = now.addingTimeInterval(-3600)
        history.machineDay = Calendar.current.startOfDay(for: now)
        history.machineCountToday = 1
        #expect(next(mood: .hot, moodSince: now.addingTimeInterval(-3600), history: history) == nil)
    }

    @Test func machineNudgesStopAtTwoPerDay() {
        var history = NudgeHistory.Snapshot()
        history.lastMachineAt = now.addingTimeInterval(-5 * 3600)
        history.machineDay = Calendar.current.startOfDay(for: now)
        history.machineCountToday = 2
        #expect(next(mood: .hot, moodSince: now.addingTimeInterval(-3600), history: history) == nil)
    }

    /// Balon yang diabaikan membuat balon mesin mundur satu jam — tapi tidak
    /// menahan reminder, yang memang diminta.
    @Test func ignoredBalloonBacksOffMachineNudgesOnly() {
        var history = NudgeHistory.Snapshot()
        history.lastIgnoredAt = now.addingTimeInterval(-600)
        #expect(next(mood: .hot, moodSince: now.addingTimeInterval(-3600), history: history) == nil)
        #expect(next(reminders: [reminder(in: 120)], history: history) != nil)
    }

    // MARK: - Peredam

    @Test func everyQuietSignalSilencesOnItsOwn() {
        let mutations: [(inout QuietSignals) -> Void] = [
            { $0.otherAppIsFullScreen = true },
            { $0.screenIsAsleepOrLocked = true },
            { $0.aplIsFrontmost = true },
            { $0.quickAskIsOpen = true },
            { $0.buddyIsRunning = false },
            { $0.aNudgeIsOnScreen = true },
            { $0.aGameIsOnScreen = true },
        ]
        for mutate in mutations {
            var signals = QuietSignals()
            mutate(&signals)
            #expect(signals.allowsSpeaking == false)
            #expect(next(reminders: [reminder(in: 120)], signals: signals) == nil)
        }
    }

    @Test func defaultSignalsAllowSpeaking() {
        #expect(QuietSignals().allowsSpeaking)
    }

    /// Reminder didahulukan: ia punya waktu, keadaan mesin tidak.
    @Test func reminderOutranksMachine() {
        let nudge = next(reminders: [reminder(in: 120)], mood: .hot,
                         moodSince: now.addingTimeInterval(-3600))
        #expect(nudge?.isMachine == false)
    }
}

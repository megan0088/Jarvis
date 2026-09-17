import Foundation
import Testing
@testable import Apl

/// Urutan prioritas spec B §6, satu cabang per test. `t0` adalah detik ke-0;
/// semua waktu lain dihitung darinya.
struct CharacterMoodResolverTests {

    private typealias Resolution = CharacterMoodResolver.Resolution

    private let t0 = TestTime.now

    private func input(available: Bool = true, streaming: Bool = false,
                       event: ChatEvent.Kind? = nil, eventAt: TimeInterval = 0,
                       activatedAt: TimeInterval? = nil) -> CharacterMoodInput {
        CharacterMoodInput(
            intelligenceAvailable: available,
            isStreaming: streaming,
            lastEvent: event.map { ChatEvent(kind: $0, at: t0.addingTimeInterval(eventAt)) },
            windowActivatedAt: activatedAt.map { t0.addingTimeInterval($0) })
    }

    private func resolve(_ input: CharacterMoodInput, after seconds: TimeInterval) -> Resolution {
        CharacterMoodResolver.resolve(input, now: t0.addingTimeInterval(seconds))
    }

    private func moment(_ behavior: CharacterBehavior, until seconds: TimeInterval?) -> Resolution {
        Resolution(behavior: behavior, reevaluateAt: seconds.map { t0.addingTimeInterval($0) })
    }

    @Test func nothingRecentIsIdleWithoutATimer() {
        #expect(resolve(input(), after: 60) == moment(.idle, until: nil))
    }

    @Test func appleIntelligenceOffIsSleepyEvenWhileStreaming() {
        #expect(resolve(input(available: false, streaming: true), after: 0) == moment(.sleepy, until: nil))
    }

    @Test func recentFailureIsSleepyForThreeSeconds() {
        let failed = input(event: .failed)
        #expect(resolve(failed, after: 2.9) == moment(.sleepy, until: 3))
        #expect(resolve(failed, after: 3).behavior == .idle)
    }

    @Test func failureOutranksStreaming() {
        #expect(resolve(input(streaming: true, event: .failed), after: 1).behavior == .sleepy)
    }

    @Test func streamingIsThinkingWithoutATimer() {
        #expect(resolve(input(streaming: true), after: 0) == moment(.thinking, until: nil))
    }

    @Test func oldFailureNoLongerBlocksThinking() {
        #expect(resolve(input(streaming: true, event: .failed), after: 10).behavior == .thinking)
    }

    @Test func newReminderCelebratesForThreeSeconds() {
        let created = input(event: .reminderCreated(UUID()))
        #expect(resolve(created, after: 0) == moment(.celebrate, until: 3))
        #expect(resolve(created, after: 3).behavior == .idle)
    }

    @Test func streamingOutranksCelebration() {
        #expect(resolve(input(streaming: true, event: .reminderCreated(UUID())), after: 1).behavior == .thinking)
    }

    @Test func celebrationOutranksGreeting() {
        #expect(resolve(input(event: .reminderCreated(UUID()), activatedAt: 0), after: 1).behavior == .celebrate)
    }

    @Test func activatedWindowGreetsForThreeSeconds() {
        let activated = input(activatedAt: 5)
        #expect(resolve(activated, after: 6) == moment(.greet, until: 8))
        #expect(resolve(activated, after: 8).behavior == .idle)
    }

    /// Jam yang mundur (kejadian "di masa depan") tidak boleh membuat momen abadi.
    @Test func eventsFromTheFutureAreIgnored() {
        #expect(resolve(input(event: .failed, eventAt: 10), after: 0).behavior == .idle)
    }
}

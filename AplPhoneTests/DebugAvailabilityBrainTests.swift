#if DEBUG
import Foundation
import Testing
@testable import Apl

private struct FixedBrain: Brain {
    let value: BrainAvailability
    func availability() async -> BrainAvailability { value }
    func reply(to history: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}

/// Override khusus DEBUG untuk menguji state AI mati tanpa menyentuh
/// pengaturan sistem (spec B §8, §10).
struct DebugAvailabilityBrainTests {

    private func isolatedDefaults(_ name: String) -> UserDefaults {
        let suite = "test.debugbrain.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func withoutAnOverrideTheSystemAnswers() async {
        let brain = DebugAvailabilityBrain(base: FixedBrain(value: .ready), defaults: isolatedDefaults(#function))

        #expect(await brain.availability() == .ready)
    }

    @Test func overrideWins() async {
        let defaults = isolatedDefaults(#function)
        defaults.set(ForcedAvailability.notEnabled.rawValue, forKey: ForcedAvailability.defaultsKey)
        let brain = DebugAvailabilityBrain(base: FixedBrain(value: .ready), defaults: defaults)

        #expect(await brain.availability() == .unavailable("Enable Apple Intelligence in System Settings."))
    }

    @Test func unknownStoredValueFallsBackToTheSystem() async {
        let defaults = isolatedDefaults(#function)
        defaults.set("banana", forKey: ForcedAvailability.defaultsKey)
        let brain = DebugAvailabilityBrain(base: FixedBrain(value: .needsSetup("x")), defaults: defaults)

        #expect(await brain.availability() == .needsSetup("x"))
    }
}
#endif

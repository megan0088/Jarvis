import Testing
@testable import Apl

@MainActor
struct OnboardingStepTests {

    /// Tiga langkah, tanpa akun (spec B §8). Start di langkah terakhir,
    /// bukan langkah keempat.
    @Test func stepsRunWelcomeRemindersIntelligence() {
        typealias Step = OnboardingView.Step

        #expect(Step.allCases == [.welcome, .reminders, .intelligence])
        #expect(Step.welcome.next == .reminders)
        #expect(Step.intelligence.next == nil)
        #expect(Step.welcome.previous == nil)
        #expect(Step.intelligence.previous == .reminders)
    }
}

import Testing
@testable import Apl

struct PhoneOnboardingStepTests {

    /// Tiga langkah, tanpa akun. Start di langkah terakhir, bukan langkah keempat.
    @Test func stepsRunWelcomeRemindersIntelligence() {
        #expect(PhoneOnboardingStep.allCases == [.welcome, .reminders, .intelligence])
        #expect(PhoneOnboardingStep.welcome.next == .reminders)
        #expect(PhoneOnboardingStep.intelligence.next == nil)
        #expect(PhoneOnboardingStep.welcome.previous == nil)
        #expect(PhoneOnboardingStep.intelligence.previous == .reminders)
    }

    @Test func onlyTheLastStepSaysStart() {
        #expect(PhoneOnboardingStep.welcome.primaryTitle == "Continue")
        #expect(PhoneOnboardingStep.reminders.primaryTitle == "Continue")
        #expect(PhoneOnboardingStep.intelligence.primaryTitle == "Start")
    }

    @Test func positionIsReadableByVoiceOver() {
        #expect(PhoneOnboardingStep.welcome.position == "Step 1 of 3")
        #expect(PhoneOnboardingStep.intelligence.position == "Step 3 of 3")
    }
}

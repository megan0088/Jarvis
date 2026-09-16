import Foundation
import Testing
@testable import Apl

@Suite("Ketersediaan Apple Intelligence untuk layar chat")
struct ChatAvailabilityTests {

    @MainActor
    @Test func chatReportsWhyAppleIntelligenceIsUnavailable() async {
        let chat = ChatStore(brain: StubBrain(availability: .unavailable("Enable Apple Intelligence in System Settings.")))

        #expect(await chat.availability() == .unavailable("Enable Apple Intelligence in System Settings."))
    }

    @MainActor
    @Test func chatWithoutABrainIsUnavailable() async {
        let chat = ChatStore(brain: nil)

        let availability = await chat.availability()

        guard case .unavailable = availability else {
            Issue.record("expected .unavailable, got \(availability)")
            return
        }
    }
}

private struct StubBrain: Brain {
    let stubbed: BrainAvailability

    init(availability: BrainAvailability) {
        self.stubbed = availability
    }

    func availability() async -> BrainAvailability { stubbed }

    func reply(to history: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}

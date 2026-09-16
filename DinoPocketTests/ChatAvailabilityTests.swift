import Foundation
import Testing
@testable import Apl

@Suite("Ketersediaan otak untuk layar chat")
struct ChatAvailabilityTests {

    @MainActor
    @Test func chatIsUsableWhenAppleIsDownButAnotherBrainIsReady() async {
        let chat = ChatStore(brains: [
            .apple: StubBrain(kind: .apple, availability: .unavailable("Enable Apple Intelligence in System Settings.")),
            .ollama: StubBrain(kind: .ollama, availability: .ready)
        ])

        #expect(await chat.bestAvailability() == .ready)
    }

    @MainActor
    @Test func chatReportsAppleReasonWhenNoBrainIsReady() async {
        let chat = ChatStore(brains: [
            .apple: StubBrain(kind: .apple, availability: .unavailable("Enable Apple Intelligence in System Settings.")),
            .ollama: StubBrain(kind: .ollama, availability: .needsSetup("Ollama isn't running."))
        ])

        #expect(await chat.bestAvailability() == .unavailable("Enable Apple Intelligence in System Settings."))
    }
}

private struct StubBrain: Brain {
    let kind: BrainKind
    let stubbed: BrainAvailability

    init(kind: BrainKind, availability: BrainAvailability) {
        self.kind = kind
        self.stubbed = availability
    }

    func availability() async -> BrainAvailability { stubbed }

    func reply(to history: [ChatMessage], persona: Persona) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}

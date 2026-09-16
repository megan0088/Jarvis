import Foundation
import Testing
@testable import Apl

struct AppleBrainTests {
    @Test func buildPromptThreadsFullHistoryEndingWithAssistantCue() {
        let history: [ChatMessage] = [
            ChatMessage(id: UUID(), role: .user, text: "halo", date: .init()),
            ChatMessage(id: UUID(), role: .assistant, text: "hai Ega", date: .init()),
            ChatMessage(id: UUID(), role: .user, text: "aku capek", date: .init())
        ]
        let prompt = AppleBrain.buildPrompt(from: history)
        #expect(prompt == "User: halo\nApl: hai Ega\nUser: aku capek\nApl:")
    }

    @Test func buildPromptEmptyHistoryIsJustCue() {
        #expect(AppleBrain.buildPrompt(from: []) == "Apl:")
    }
}

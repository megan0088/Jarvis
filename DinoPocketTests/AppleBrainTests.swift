import Foundation
import Testing
@testable import Jarvis

struct AppleBrainTests {
    @Test func buildPromptThreadsFullHistoryEndingWithJarvisCue() {
        let history: [ChatMessage] = [
            ChatMessage(id: UUID(), role: .user, text: "halo", date: .init()),
            ChatMessage(id: UUID(), role: .assistant, text: "hai Ega", date: .init()),
            ChatMessage(id: UUID(), role: .user, text: "aku capek", date: .init())
        ]
        let prompt = AppleBrain.buildPrompt(from: history)
        #expect(prompt == "User: halo\nJarvis: hai Ega\nUser: aku capek\nJarvis:")
    }

    @Test func buildPromptEmptyHistoryIsJustCue() {
        #expect(AppleBrain.buildPrompt(from: []) == "Jarvis:")
    }

    @Test func kindIsApple() {
        #expect(AppleBrain().kind == .apple)
    }
}

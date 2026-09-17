import Foundation
import FoundationModels
import Testing
@testable import Apl

private final class SpySessionStore: ChatSessionStoring, @unchecked Sendable {
    private(set) var clearCount = 0
    func loadTranscript() -> Transcript? { nil }
    func save(_ transcript: Transcript) {}
    func clear() { clearCount += 1 }
}

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

    /// Clear Conversation harus membuat model lupa, bukan hanya layar kosong:
    /// tanpa ini transcript lama dimuat lagi saat pesan berikutnya dikirim.
    @MainActor @Test func resetConversationClearsTheSavedTranscript() async {
        let sessions = SpySessionStore()
        let brain = AppleBrain(sessionStore: sessions)

        await brain.resetConversation()

        #expect(sessions.clearCount == 1)
    }
}

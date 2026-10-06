import Foundation
import Testing
@testable import Apl

struct AnswerAnnouncementTextTests {

    private func user(_ text: String) -> ChatMessage { ChatMessage(role: .user, text: text) }
    private func apl(_ text: String, status: ChatMessage.Status = .complete) -> ChatMessage {
        ChatMessage(role: .assistant, text: text, status: status)
    }

    @Test func finishedAnswerIsAnnounced() {
        #expect(AnswerAnnouncementText.text(messages: [user("Hi"), apl("Hello!")], isStreaming: false) == "Hello!")
    }

    /// `nil` selama menjawab: perubahan dari `nil` ke teks itulah tanda
    /// "jawaban sudah utuh", sekali saja.
    @Test func nothingIsAnnouncedWhileStreaming() {
        #expect(AnswerAnnouncementText.text(messages: [user("Hi"), apl("Hel")], isStreaming: true) == nil)
    }

    @Test func theUsersOwnMessageIsNotAnnounced() {
        #expect(AnswerAnnouncementText.text(messages: [user("Hi")], isStreaming: false) == nil)
        #expect(AnswerAnnouncementText.text(messages: [], isStreaming: false) == nil)
    }

    /// Diam saat gagal lebih buruk daripada kabar buruk.
    @Test func failedAnswerAnnouncesThatItFailed() {
        #expect(AnswerAnnouncementText.text(messages: [user("Hi"), apl("Half", status: .failed)],
                                            isStreaming: false) == AnswerAnnouncementText.failureNotice)
    }
}

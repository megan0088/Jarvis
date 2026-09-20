import Foundation
import Testing
@testable import Apl

struct AnswerAnnouncementTests {

    private func user(_ text: String) -> ChatMessage { ChatMessage(role: .user, text: text) }
    private func apl(_ text: String, status: ChatMessage.Status = .complete) -> ChatMessage {
        ChatMessage(role: .assistant, text: text, status: status)
    }

    @Test func finishedAnswerIsAnnounced() {
        #expect(AnswerAnnouncement.text(messages: [user("Hi"), apl("Hello there")],
                                        isStreaming: false) == "Hello there")
    }

    /// Selama masih mengalir, jawabannya belum utuh; mengumumkan potongan
    /// berarti memotong dirinya sendiri setiap beberapa kata.
    @Test func nothingIsAnnouncedWhileStreaming() {
        #expect(AnswerAnnouncement.text(messages: [user("Hi"), apl("Hel")],
                                        isStreaming: true) == nil)
    }

    /// Cacat yang ditemukan pemilik produk: jawaban reminder TIDAK PERNAH
    /// streaming — `ChatStore` menjawabnya secara lokal tanpa model — sehingga
    /// pemicu lama yang menunggu "streaming selesai" tidak pernah menyala.
    @Test func localReminderReplyIsAnnouncedToo() {
        let messages = [user("remind me to stretch at 3 PM"),
                        apl("Done — I'll remind you to stretch today at 15.00.")]
        #expect(AnswerAnnouncement.text(messages: messages, isStreaming: false)
                == "Done — I'll remind you to stretch today at 15.00.")
    }

    @Test func nothingToAnnounceAfterOwnQuestion() {
        #expect(AnswerAnnouncement.text(messages: [user("Hi")], isStreaming: false) == nil)
    }

    @Test func emptyAnswerSaysNothing() {
        #expect(AnswerAnnouncement.text(messages: [user("Hi"), apl("")],
                                        isStreaming: false) == nil)
    }

    @Test func emptyConversationSaysNothing() {
        #expect(AnswerAnnouncement.text(messages: [], isStreaming: false) == nil)
    }

    /// Diam saat gagal lebih buruk daripada kabar buruk: pengguna VoiceOver
    /// tidak punya cara lain tahu bahwa jawabannya berhenti di tengah.
    @Test func failedAnswerAnnouncesThatItFailed() {
        let text = AnswerAnnouncement.text(messages: [user("Hi"), apl("Half", status: .failed)],
                                           isStreaming: false)
        #expect(text == AnswerAnnouncement.failureNotice)
    }

    @Test func stoppedAnswerAnnouncesWhatWasWritten() {
        #expect(AnswerAnnouncement.text(messages: [user("Hi"), apl("Half", status: .stopped)],
                                        isStreaming: false) == "Half")
    }
}

import Foundation
import Testing
@testable import Apl

struct QuickAskTurnTests {

    @Test func emptyConversationHasNoTurn() {
        #expect(QuickAskTurn.latest(in: []) == nil)
    }

    @Test func questionWithoutAnswerYet() {
        let turn = QuickAskTurn.latest(in: [ChatMessage(role: .user, text: "Hi")])
        #expect(turn?.question == "Hi")
        #expect(turn?.answer == nil)
    }

    @Test func questionWithItsAnswer() {
        let turn = QuickAskTurn.latest(in: [
            ChatMessage(role: .user, text: "Hi"),
            ChatMessage(role: .assistant, text: "Hello"),
        ])
        #expect(turn?.question == "Hi")
        #expect(turn?.answer?.text == "Hello")
    }

    /// Bubble menampilkan SATU giliran: yang lama tidak boleh ikut terbawa.
    @Test func onlyTheLastTurnSurvives() {
        let turn = QuickAskTurn.latest(in: [
            ChatMessage(role: .user, text: "First"),
            ChatMessage(role: .assistant, text: "One"),
            ChatMessage(role: .user, text: "Second"),
            ChatMessage(role: .assistant, text: "Two"),
        ])
        #expect(turn?.question == "Second")
        #expect(turn?.answer?.text == "Two")
    }

    /// Pertanyaan baru mengosongkan jawaban, bukan menampilkan jawaban lama.
    @Test func newQuestionDropsThePreviousAnswer() {
        let turn = QuickAskTurn.latest(in: [
            ChatMessage(role: .user, text: "First"),
            ChatMessage(role: .assistant, text: "One"),
            ChatMessage(role: .user, text: "Second"),
        ])
        #expect(turn?.question == "Second")
        #expect(turn?.answer == nil)
    }

    @Test func failedAnswerIsStillTheAnswer() {
        let turn = QuickAskTurn.latest(in: [
            ChatMessage(role: .user, text: "Hi"),
            ChatMessage(role: .assistant, text: "", status: .failed),
        ])
        #expect(turn?.answer?.status == .failed)
    }
}

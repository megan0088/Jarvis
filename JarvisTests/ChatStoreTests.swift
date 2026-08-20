import Foundation
import Testing
@testable import Jarvis

private struct StubBrain: Brain {
    let kind: BrainKind
    var chunks: [String]
    var available: BrainAvailability = .ready
    func availability() async -> BrainAvailability { available }
    func reply(to history: [ChatMessage], persona: Persona) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { c in
            for chunk in chunks { c.yield(chunk) }
            c.finish()
        }
    }
}

struct ChatStoreTests {
    @MainActor @Test func sendAppendsUserAndStreamedAssistantMessage() async {
        let store = ChatStore(brains: [.ollama: StubBrain(kind: .ollama, chunks: ["A", "AB", "ABC"])])
        store.activeBrain = .ollama
        await store.send("halo")
        #expect(store.messages.count == 2)
        #expect(store.messages[0].role == .user)
        #expect(store.messages[1].role == .assistant)
        #expect(store.messages[1].text == "ABC")
        #expect(store.isStreaming == false)
    }

    @MainActor @Test func fallsBackWhenActiveBrainUnavailable() async {
        let apple = StubBrain(kind: .apple, chunks: ["X"], available: .unavailable("nope"))
        let ollama = StubBrain(kind: .ollama, chunks: ["dari ollama"], available: .ready)
        let store = ChatStore(brains: [.apple: apple, .ollama: ollama])
        store.activeBrain = .apple
        await store.send("tes")
        #expect(store.messages.last?.text == "dari ollama")
        #expect(store.noticeMessage != nil)
    }
}

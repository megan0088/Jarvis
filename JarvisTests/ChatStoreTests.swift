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

/// A Brain whose stream stays open until the test explicitly finishes it.
/// This lets a test deterministically overlap two `send()` calls: start
/// call N, wait until its stream has actually begun (no sleeps/polling —
/// `reply()` runs synchronously the moment the consuming Task reaches the
/// `for try await` line, which only happens after ChatStore has already
/// mutated all the shared state we want to assert on), then drive
/// completion of each call's stream at a time of the test's choosing.
private final class GatedBrain: Brain, @unchecked Sendable {
    let kind: BrainKind
    var available: BrainAvailability = .ready
    private var continuations: [AsyncThrowingStream<String, Error>.Continuation] = []
    private var starters: [CheckedContinuation<Void, Never>] = []
    private var startedCount = 0

    init(kind: BrainKind) { self.kind = kind }

    func availability() async -> BrainAvailability { available }

    func reply(to history: [ChatMessage], persona: Persona) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            self.continuations.append(continuation)
            self.startedCount += 1
            if !self.starters.isEmpty { self.starters.removeFirst().resume() }
        }
    }

    /// Suspends until the Nth (1-based) call to `reply` has begun.
    func waitUntilStreamStarted(_ n: Int) async {
        if startedCount >= n { return }
        await withCheckedContinuation { starters.append($0) }
    }

    /// Completes the Nth (1-based) call's stream, optionally yielding chunks first.
    func finishStream(_ n: Int, with chunks: [String] = []) {
        guard continuations.indices.contains(n - 1) else { return }
        for chunk in chunks { continuations[n - 1].yield(chunk) }
        continuations[n - 1].finish()
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

    /// Overlapping sends: a second `send()` arrives while the first is still
    /// streaming. Covers both cancellation findings deterministically:
    /// - FINDING 2: the first call's empty assistant placeholder must be
    ///   removed before the second user message is appended, and must not
    ///   appear in the history captured for the second `brain.reply(...)`.
    /// - FINDING 1: when the first (stale, cancelled) stream's completion
    ///   block finally runs — here, after the second stream has already
    ///   started — it must NOT flip `isStreaming` back to false or persist
    ///   a stale snapshot while the newer stream is still active.
    @MainActor @Test func overlappingSendFinalizesStalePlaceholderAndIgnoresStaleCleanup() async {
        let brain = GatedBrain(kind: .ollama)
        let store = ChatStore(brains: [.ollama: brain])
        store.activeBrain = .ollama

        let firstSend = Task { await store.send("pertama") }
        await brain.waitUntilStreamStarted(1)

        // Mid-first-stream: empty assistant placeholder present, streaming.
        #expect(store.messages.count == 2)
        #expect(store.messages[1].role == .assistant)
        #expect(store.messages[1].text == "")
        #expect(store.isStreaming == true)

        let secondSend = Task { await store.send("kedua") }
        await brain.waitUntilStreamStarted(2)

        // FINDING 2: stale empty placeholder from the first stream is gone;
        // history for the second call is [user "pertama", user "kedua"] only.
        #expect(store.messages.count == 3)
        #expect(store.messages[0].text == "pertama")
        #expect(store.messages[1].text == "kedua")
        #expect(store.messages[2].role == .assistant)
        #expect(store.messages[2].text == "")

        // Let the stale first stream complete now, after the second has begun.
        brain.finishStream(1)
        await firstSend.value

        // FINDING 1: stale cleanup must not clobber the still-active second stream.
        #expect(store.isStreaming == true)
        #expect(store.messages[2].text == "")

        // Finish the second stream for real and let it complete normally.
        brain.finishStream(2, with: ["OK"])
        await secondSend.value

        #expect(store.messages[2].text == "OK")
        #expect(store.isStreaming == false)
    }
}

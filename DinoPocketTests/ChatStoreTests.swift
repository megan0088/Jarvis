import Foundation
import Testing
@testable import Apl

private struct StubBrain: Brain {
    var chunks: [String]
    var available: BrainAvailability = .ready
    func availability() async -> BrainAvailability { available }
    func reply(to history: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
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
    var available: BrainAvailability = .ready
    private var continuations: [AsyncThrowingStream<String, Error>.Continuation] = []
    private var starters: [CheckedContinuation<Void, Never>] = []
    private var startedCount = 0

    func availability() async -> BrainAvailability { available }

    func reply(to history: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
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

    /// Fails the Nth (1-based) call's stream with an error, without yielding chunks.
    func throwStream(_ n: Int) {
        guard continuations.indices.contains(n - 1) else { return }
        continuations[n - 1].finish(throwing: StubStreamError())
    }
}

private struct StubStreamError: Error {}

/// Serial: setiap test membaca dan menulis `jarvis.chat.recent` di
/// `UserDefaults.standard`, jadi menjalankannya paralel membuat satu test
/// memuat pesan milik test lain.
@Suite(.serialized)
struct ChatStoreTests {
    @MainActor @Test func sendAppendsUserAndStreamedAssistantMessage() async {
        UserDefaults.standard.removeObject(forKey: "jarvis.chat.recent")
        let store = ChatStore(brain: StubBrain(chunks: ["A", "AB", "ABC"]))
        await store.send("halo")
        #expect(store.messages.count == 2)
        #expect(store.messages[0].role == .user)
        #expect(store.messages[1].role == .assistant)
        #expect(store.messages[1].text == "ABC")
        #expect(store.isStreaming == false)
    }

    @MainActor @Test func unavailableAppleIntelligenceLeavesANoticeAndNoReply() async {
        UserDefaults.standard.removeObject(forKey: "jarvis.chat.recent")
        let store = ChatStore(brain: StubBrain(chunks: ["X"], available: .unavailable("nope")))

        await store.send("tes")

        #expect(store.messages.map(\.role) == [.user])
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
        UserDefaults.standard.removeObject(forKey: "jarvis.chat.recent")
        let brain = GatedBrain()
        let store = ChatStore(brain: brain)

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

    /// Regression test for round 2: `finalizeInterruptedAssistant()` can
    /// remove a message, shifting every later index down by one. If a stale
    /// (superseded) stream's `catch` block writes to its captured `index`
    /// without checking generation, that write now lands on whatever
    /// message slid into that slot — here, the NEWER user's own message —
    /// instead of being silently discarded. The catch block must be gated
    /// by the same generation check as the success path.
    @MainActor @Test func staleStreamErrorAfterSupersessionDoesNotCorruptNewerMessage() async {
        UserDefaults.standard.removeObject(forKey: "jarvis.chat.recent")
        let brain = GatedBrain()
        let store = ChatStore(brain: brain)

        let firstSend = Task { await store.send("pertama") }
        await brain.waitUntilStreamStarted(1)

        let secondSend = Task { await store.send("kedua") }
        await brain.waitUntilStreamStarted(2)

        // messages == [user "pertama", user "kedua", assistant ""].
        // Stream 1's captured index (1) now points at the "kedua" user
        // message because finalizeInterruptedAssistant() removed stream 1's
        // own placeholder and shifted everything after it down by one.
        #expect(store.messages[1].role == .user)
        #expect(store.messages[1].text == "kedua")

        // Let the stale (superseded) first stream fail now.
        brain.throwStream(1)
        await firstSend.value

        // The catch block must be generation-gated: stream 1's error must
        // NOT land on messages[1], which is now the "kedua" user message.
        #expect(store.messages[1].role == .user)
        #expect(store.messages[1].text == "kedua")

        // isStreaming must still reflect only the newest (second) stream.
        #expect(store.isStreaming == true)

        // Finish the second stream normally; it should complete cleanly.
        brain.finishStream(2, with: ["OK"])
        await secondSend.value

        #expect(store.messages[1].text == "kedua")
        #expect(store.messages[2].text == "OK")
        #expect(store.isStreaming == false)
    }

    @MainActor
    private func chatHandlingReminders(now: Date = TestTime.now)
        -> (ChatStore, InMemoryReminderStore, SpyReminderScheduler) {
        UserDefaults.standard.removeObject(forKey: "jarvis.chat.recent")
        let chat = ChatStore(brain: nil)
        let reminders = InMemoryReminderStore()
        let scheduler = SpyReminderScheduler()
        chat.createReminder = CreateReminderFromTextUseCase(
            store: reminders, notifications: scheduler, now: { now },
            calendar: TestTime.calendar, locale: TestTime.locale)
        return (chat, reminders, scheduler)
    }

    /// Reminder ditangani lokal: tidak ada otak di test ini (`brains: [:]`),
    /// jadi pesan yang sampai ke jalur AI akan mengisi `noticeMessage`.
    @MainActor @Test func reminderRequestIsHandledWithoutTheBrain() async {
        let (chat, reminders, scheduler) = chatHandlingReminders()
        chat.noticeMessage = "stale banner"

        await chat.send("remind me to drink water at 3pm")

        #expect(reminders.reminders.map(\.title) == ["Drink water"])
        #expect(reminders.reminders.first?.rule == .once(TestTime.date(2026, 9, 16, 15, 0)))
        #expect(scheduler.syncCallCount == 1)
        #expect(chat.messages.map(\.role) == [.user, .assistant])
        #expect(chat.messages[1].text.hasPrefix("Done — I'll remind you to drink water today at"))
        #expect(chat.isStreaming == false)
        #expect(chat.noticeMessage == nil)
    }

    @MainActor @Test func missingTimeIsAskedThenCompletedOnTheNextTurn() async {
        let (chat, reminders, _) = chatHandlingReminders()

        await chat.send("remind me to call mom")

        #expect(reminders.reminders.isEmpty)
        #expect(chat.messages.last?.text == "What time should I remind you to call mom?")
        #expect(chat.noticeMessage == nil)

        await chat.send("5pm")

        #expect(reminders.reminders.map(\.title) == ["Call mom"])
        #expect(reminders.reminders.first?.rule == .once(TestTime.date(2026, 9, 16, 17, 0)))
        #expect(chat.messages.count == 4)
        #expect(chat.messages.last?.text.hasPrefix("Done — I'll remind you to call mom today at") == true)
    }

    /// Pertanyaan jam hanya berlaku satu giliran. Setelah pesan lain, "5pm"
    /// tidak boleh diam-diam menjadi reminder yang sudah dilupakan pengguna.
    @MainActor @Test func unansweredTimeQuestionExpiresAfterOneTurn() async {
        let (chat, reminders, _) = chatHandlingReminders()

        await chat.send("remind me to call mom")
        await chat.send("tell me a joke")
        #expect(chat.noticeMessage != nil)

        await chat.send("5pm")

        #expect(reminders.reminders.isEmpty)
    }

    @MainActor @Test func passedTimeIsConfirmedAsTomorrow() async {
        let (chat, reminders, _) = chatHandlingReminders(now: TestTime.date(2026, 9, 16, 16, 0))

        await chat.send("remind me to stretch at 3pm")

        #expect(reminders.reminders.first?.rule == .once(TestTime.date(2026, 9, 17, 15, 0)))
        #expect(chat.messages.last?.text.contains("tomorrow at") == true)
    }
}

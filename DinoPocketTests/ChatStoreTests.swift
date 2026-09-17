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
    private(set) var resetCount = 0
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

    func resetConversation() async {
        resetCount += 1
    }

    /// Suspends until the Nth (1-based) call to `reply` has begun.
    func waitUntilStreamStarted(_ n: Int) async {
        if startedCount >= n { return }
        await withCheckedContinuation { starters.append($0) }
    }

    /// Yields one cumulative chunk on the Nth (1-based) call's stream.
    func yield(_ n: Int, _ chunk: String) {
        guard continuations.indices.contains(n - 1) else { return }
        continuations[n - 1].yield(chunk)
    }

    /// Completes the Nth (1-based) call's stream, optionally yielding chunks first.
    func finishStream(_ n: Int, with chunks: [String] = []) {
        guard continuations.indices.contains(n - 1) else { return }
        for chunk in chunks { continuations[n - 1].yield(chunk) }
        continuations[n - 1].finish()
    }

    /// Fails the Nth (1-based) call's stream with an error, without yielding chunks.
    func throwStream(_ n: Int, error: Error = StubStreamError()) {
        guard continuations.indices.contains(n - 1) else { return }
        continuations[n - 1].finish(throwing: error)
    }
}

private struct StubStreamError: Error {}

/// Test host-nya Apl.app: tanpa suite sendiri, test menulis riwayat chat ke
/// data app sungguhan dan saling memuat pesan milik test lain.
private func isolatedDefaults(_ name: String) -> UserDefaults {
    let suite = "test.chat.\(name)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}

/// Menunggu kondisi yang dipenuhi task lain di MainActor. Batasnya satu
/// detik, supaya test yang salah gagal di `#expect`, bukan menggantung.
@MainActor
private func waitUntil(_ condition: () -> Bool) async {
    var attempts = 0
    while !condition(), attempts < 200 {
        attempts += 1
        try? await Task.sleep(for: .milliseconds(5))
    }
}

struct ChatStoreTests {
    @MainActor @Test func sendAppendsUserAndStreamedAssistantMessage() async {
        let store = ChatStore(brain: StubBrain(chunks: ["A", "AB", "ABC"]),
                              defaults: isolatedDefaults(#function))
        await store.send("halo")
        #expect(store.messages.count == 2)
        #expect(store.messages[0].role == .user)
        #expect(store.messages[1].role == .assistant)
        #expect(store.messages[1].text == "ABC")
        #expect(store.isStreaming == false)
    }

    @MainActor @Test func unavailableAppleIntelligenceLeavesANoticeAndNoReply() async {
        let store = ChatStore(brain: StubBrain(chunks: ["X"], available: .unavailable("nope")),
                              defaults: isolatedDefaults(#function))

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
        let brain = GatedBrain()
        let store = ChatStore(brain: brain, defaults: isolatedDefaults(#function))

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
        let brain = GatedBrain()
        let store = ChatStore(brain: brain, defaults: isolatedDefaults(#function))

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

    /// `suite` diisi `#function` milik pemanggil, jadi tiap test tetap
    /// mendapat UserDefaults-nya sendiri.
    @MainActor
    private func chatHandlingReminders(now: Date = TestTime.now, suite: String = #function)
        -> (ChatStore, InMemoryReminderStore, SpyReminderScheduler) {
        let chat = ChatStore(brain: nil, defaults: isolatedDefaults(suite), now: { now })
        let reminders = InMemoryReminderStore()
        let scheduler = SpyReminderScheduler()
        chat.createReminder = CreateReminderFromTextUseCase(
            store: reminders, notifications: scheduler, now: { now },
            calendar: TestTime.calendar, locale: TestTime.locale)
        return (chat, reminders, scheduler)
    }

    /// Reminder ditangani lokal: tidak ada otak di test ini (`brain: nil`),
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

    // MARK: - Kejadian dan lampiran (spec B §6)

    /// Chip di bawah konfirmasi dirender dari lampiran ini, bukan dari teks.
    @MainActor @Test func reminderConfirmationCarriesTheReminder() async throws {
        let (chat, reminders, _) = chatHandlingReminders()

        await chat.send("remind me to drink water at 3pm")

        let created = try #require(reminders.reminders.first)
        #expect(chat.messages[1].attachment == .reminder(created.id))
        #expect(chat.messages[0].attachment == nil)
    }

    @MainActor @Test func creatingAReminderRecordsTheEvent() async throws {
        let (chat, reminders, _) = chatHandlingReminders()

        await chat.send("remind me to drink water at 3pm")

        let created = try #require(reminders.reminders.first)
        #expect(chat.lastEvent == ChatEvent(kind: .reminderCreated(created.id), at: TestTime.now))
    }

    /// Pertanyaan balik bukan reminder: tidak ada chip dan karakter tidak merayakan apa pun.
    @MainActor @Test func timeQuestionIsPlainText() async {
        let (chat, _, _) = chatHandlingReminders()

        await chat.send("remind me to call mom")

        #expect(chat.messages.last?.attachment == nil)
        #expect(chat.lastEvent == nil)
    }

    @MainActor @Test func conversationIsSavedInItsOwnDefaults() async {
        let defaults = isolatedDefaults(#function)
        let first = ChatStore(brain: StubBrain(chunks: ["Hi!"]), defaults: defaults)

        await first.send("hello")
        let restored = ChatStore(brain: nil, defaults: defaults)

        #expect(defaults.data(forKey: ChatStore.recentKey) != nil)
        #expect(restored.messages == first.messages)
    }

    // MARK: - Gagal, stop, retry, clear (spec B §9)

    /// Guardrail bukan kesalahan pengguna maupun jaringan: jawabannya netral.
    @MainActor @Test func blockedRequestGetsANeutralReply() async {
        let brain = GatedBrain()
        let store = ChatStore(brain: brain, defaults: isolatedDefaults(#function))

        let sending = Task { await store.send("something") }
        await brain.waitUntilStreamStarted(1)
        brain.throwStream(1, error: AplError.requestBlocked)
        await sending.value

        #expect(store.messages.last?.text == ChatStore.blockedReply)
        #expect(store.messages.last?.status == .complete)
        #expect(store.lastEvent == nil)
    }

    @MainActor @Test func failedStreamIsMarkedFailedWithoutWarningText() async {
        let brain = GatedBrain()
        let store = ChatStore(brain: brain, defaults: isolatedDefaults(#function), now: { TestTime.now })

        let sending = Task { await store.send("hello") }
        await brain.waitUntilStreamStarted(1)
        brain.yield(1, "Half an ans")
        await waitUntil { store.messages.last?.text == "Half an ans" }
        brain.throwStream(1)
        await sending.value

        #expect(store.messages.last?.text == "Half an ans")
        #expect(store.messages.last?.status == .failed)
        #expect(store.lastEvent == ChatEvent(kind: .failed, at: TestTime.now))
        #expect(store.isStreaming == false)
    }

    /// Retry mengganti jawaban yang gagal di tempat, tanpa menggandakan pesan pengguna.
    @MainActor @Test func retryReplacesTheFailedReply() async {
        let brain = GatedBrain()
        let store = ChatStore(brain: brain, defaults: isolatedDefaults(#function))
        let first = Task { await store.send("hello") }
        await brain.waitUntilStreamStarted(1)
        brain.throwStream(1)
        await first.value
        let failedID = store.messages[1].id

        let retrying = Task { await store.retry(failedID) }
        await brain.waitUntilStreamStarted(2)
        brain.finishStream(2, with: ["Hi!"])
        await retrying.value

        #expect(store.messages.map(\.role) == [.user, .assistant])
        #expect(store.messages[0].text == "hello")
        #expect(store.messages[1].text == "Hi!")
        #expect(store.messages[1].status == .complete)
    }

    @MainActor @Test func stopKeepsWhatWasWrittenAndMarksItStopped() async {
        let brain = GatedBrain()
        let store = ChatStore(brain: brain, defaults: isolatedDefaults(#function))

        let sending = Task { await store.send("tell me a story") }
        await brain.waitUntilStreamStarted(1)
        brain.yield(1, "Once upon")
        await waitUntil { store.messages.last?.text == "Once upon" }

        store.stopStreaming()
        brain.finishStream(1, with: ["Once upon a time"])
        await sending.value

        #expect(store.isStreaming == false)
        #expect(store.messages.last?.text == "Once upon")
        #expect(store.messages.last?.status == .stopped)
    }

    /// Clear Conversation mengosongkan layar DAN ingatan model, tapi reminder
    /// tetap ada (spec B §4).
    @MainActor @Test func clearConversationForgetsTheChatButKeepsReminders() async {
        let defaults = isolatedDefaults(#function)
        let brain = GatedBrain()
        let chat = ChatStore(brain: brain, defaults: defaults, now: { TestTime.now })
        let reminders = InMemoryReminderStore()
        chat.createReminder = CreateReminderFromTextUseCase(
            store: reminders, notifications: SpyReminderScheduler(), now: { TestTime.now },
            calendar: TestTime.calendar, locale: TestTime.locale)
        await chat.send("remind me to stretch at 3pm")

        await chat.clearConversation()

        #expect(chat.messages.isEmpty)
        #expect(chat.lastEvent == nil)
        #expect(defaults.data(forKey: ChatStore.recentKey) == nil)
        #expect(brain.resetCount == 1)
        #expect(reminders.reminders.count == 1)
    }

    @MainActor @Test func eraseAlsoMakesTheModelForget() async {
        let brain = GatedBrain()
        let store = ChatStore(brain: brain, defaults: isolatedDefaults(#function))

        store.eraseAllStoredData()
        await waitUntil { brain.resetCount == 1 }

        #expect(brain.resetCount == 1)
    }
}

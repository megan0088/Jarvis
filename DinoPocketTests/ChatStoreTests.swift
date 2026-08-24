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

    /// Fails the Nth (1-based) call's stream with an error, without yielding chunks.
    func throwStream(_ n: Int) {
        guard continuations.indices.contains(n - 1) else { return }
        continuations[n - 1].finish(throwing: StubStreamError())
    }
}

private struct StubStreamError: Error {}

struct ChatStoreTests {
    @MainActor @Test func sendAppendsUserAndStreamedAssistantMessage() async {
        UserDefaults.standard.removeObject(forKey: "jarvis.chat.recent")
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
        UserDefaults.standard.removeObject(forKey: "jarvis.chat.recent")
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
        UserDefaults.standard.removeObject(forKey: "jarvis.chat.recent")
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

    /// Regression test for round 2: `finalizeInterruptedAssistant()` can
    /// remove a message, shifting every later index down by one. If a stale
    /// (superseded) stream's `catch` block writes to its captured `index`
    /// without checking generation, that write now lands on whatever
    /// message slid into that slot — here, the NEWER user's own message —
    /// instead of being silently discarded. The catch block must be gated
    /// by the same generation check as the success path.
    @MainActor @Test func staleStreamErrorAfterSupersessionDoesNotCorruptNewerMessage() async {
        UserDefaults.standard.removeObject(forKey: "jarvis.chat.recent")
        let brain = GatedBrain(kind: .ollama)
        let store = ChatStore(brains: [.ollama: brain])
        store.activeBrain = .ollama

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

    /// Natural-language reminder requests must be handled locally: no brain
    /// is consulted (brains: [:]), the closure fires exactly once with the
    /// parsed schedule, and exactly one user + one assistant confirmation
    /// message is appended. Also covers the reminder path clearing any
    /// stale `noticeMessage` (e.g. a leftover "brain not ready" banner)
    /// so it doesn't linger over a successful local reminder confirmation.
    @MainActor @Test func sendCreatesReminderWithoutCallingBrain() async {
        UserDefaults.standard.removeObject(forKey: "jarvis.chat.recent")
        let store = ChatStore(brains: [:])
        let wellness = FakeWellnessStore()
        let notifications = FakeNotificationScheduler()
        store.createReminder = CreateReminderFromTextUseCase(
            parser: ReminderIntentParser(),
            store: wellness,
            notifications: notifications
        )
        store.noticeMessage = "stale banner"

        await store.send("remind me to drink water at 3pm")

        #expect(wellness.added.count == 1)
        #expect(wellness.added.first?.kind == .water)
        #expect(wellness.added.first?.hour == 15)
        // Bukti pengingat benar-benar DIJADWALKAN, bukan sekadar disimpan —
        // pemisahan itu persis yang dulu membuatnya bisa senyap.
        #expect(notifications.scheduleCallCount == 1)
        #expect(store.messages.count == 2)
        #expect(store.messages[0].role == .user)
        #expect(store.messages[0].text == "remind me to drink water at 3pm")
        #expect(store.messages[1].role == .assistant)
        #expect(store.messages[1].text.contains("Drink water"))
        #expect(store.isStreaming == false)
        #expect(store.noticeMessage == nil)
    }
}

// MARK: - Fakes

@MainActor
final class FakeWellnessStore: WellnessStoring {
    private(set) var added: [ReminderSchedule] = []

    var goalProgress = WellnessGoalProgress(date: .now, water: 0, stretch: 0, meal: 0)
    var energy = 0
    var statusMessage = ""
    var todayScreenTime: TimeInterval = 0
    var screenTimeHistory: [ScreenTimeEntry] = []
    var recentScreenTimeHistory: [ScreenTimeEntry] = []
    var recentReminderHistory: [ReminderEvent] = []
    var reminderSchedules: [ReminderSchedule] { added }

    func addCustomSchedule(_ schedule: ReminderSchedule) { added.append(schedule) }
    func resumeScreenTime(at date: Date) {}
    func pauseScreenTime(at date: Date) {}
    func tick() {}
    func prepareWellness() async {}
    func syncReminderHistory() async {}
}

final class FakeNotificationScheduler: NotificationScheduling, @unchecked Sendable {
    private(set) var scheduleCallCount = 0
    private(set) var lastScheduled: [ReminderSchedule] = []

    func schedule(_ reminders: [ReminderSchedule]) async {
        scheduleCallCount += 1
        lastScheduled = reminders
    }
    func requestAuthorization() async -> Bool { true }
}

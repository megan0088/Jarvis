import Foundation
import Observation

@MainActor
@Observable
final class ChatStore {
    var messages: [ChatMessage] = []
    var isStreaming = false
    var noticeMessage: String?

    /// Pembuatan pengingat, disuntikkan sebagai UseCase.
    ///
    /// Dulu berupa closure `onCreateReminder` yang hanya menyimpan jadwal —
    /// pendaftaran notifikasi terjadi di tempat lain, sehingga apakah pengingat
    /// benar-benar berbunyi bergantung pada siapa yang memasang closure itu.
    /// UseCase menyatukan parse, simpan, dan jadwalkan jadi satu tanggung jawab.
    var createReminder: CreateReminderFromTextUseCase?

    /// Apple Intelligence — satu-satunya otak (spec A §2 #7). Opsional hanya
    /// supaya preview dan test bisa membuat ChatStore tanpa model.
    private let brain: Brain?
    private var streamTask: Task<Void, Never>?
    private var streamGeneration = 0

    /// Reminder yang sedang menunggu jawaban "jam berapa?". Hanya bertahan satu
    /// giliran: pesan berikutnya yang bukan ungkapan waktu membuangnya.
    private var reminderAwaitingTime: PendingReminder?

    private struct PendingReminder {
        let title: String?
    }

    init(brain: Brain?) {
        self.brain = brain
        if let data = UserDefaults.standard.data(forKey: "jarvis.chat.recent"),
           let restored = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            messages = restored
        }
    }

    /// Membuang riwayat percakapan yang tersimpan beserta yang ada di memori.
    func eraseAllStoredData() {
        messages = []
        noticeMessage = nil
        reminderAwaitingTime = nil
        UserDefaults.standard.removeObject(forKey: "jarvis.chat.recent")
    }

    /// Ketersediaan Apple Intelligence, tanpa efek samping — untuk gerbang
    /// layar chat, onboarding, dan baris status di Settings.
    func availability() async -> BrainAvailability {
        guard let brain else {
            return .unavailable("Apple Intelligence isn't available in this build.")
        }
        return await brain.availability()
    }

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        streamTask?.cancel()
        finalizeInterruptedAssistant()
        messages.append(ChatMessage(id: UUID(), role: .user, text: trimmed, date: .now))

        if let reply = await localReminderReply(to: trimmed) {
            noticeMessage = nil
            streamGeneration += 1
            messages.append(ChatMessage(id: UUID(), role: .assistant, text: reply, date: .now))
            persistRecent()
            return
        }

        guard let brain, await brain.availability() == .ready else {
            noticeMessage = "Apple Intelligence isn't available yet. Enable it in System Settings to chat."
            return
        }
        noticeMessage = nil

        let history = messages
        var assistant = ChatMessage(id: UUID(), role: .assistant, text: "", date: .now)
        messages.append(assistant)
        let index = messages.count - 1
        streamGeneration += 1
        let generation = streamGeneration
        isStreaming = true

        let task = Task {
            do {
                for try await cumulative in brain.reply(to: history) {
                    if Task.isCancelled { break }
                    assistant.text = cumulative
                    if messages.indices.contains(index) { messages[index] = assistant }
                }
            } catch {
                if generation == self.streamGeneration, messages.indices.contains(index) {
                    messages[index].text += (messages[index].text.isEmpty ? "" : "\n\n") + "⚠️ Connection lost."
                }
            }
            guard generation == self.streamGeneration else { return }
            isStreaming = false
            persistRecent()
        }
        streamTask = task
        await task.value
    }

    /// Jawaban reminder tanpa AI, atau nil bila pesan harus diteruskan ke otak.
    ///
    /// Selama ada "remind me", pesan TIDAK PERNAH sampai ke model: model bisa
    /// menjawab "Sure!" tanpa membuat apa pun, dan reminder yang dijanjikan
    /// tetapi tidak ada lebih buruk daripada pertanyaan balik.
    private func localReminderReply(to text: String) async -> String? {
        guard let createReminder else { return nil }

        if let pending = reminderAwaitingTime {
            reminderAwaitingTime = nil
            if case .created(_, let confirmation)? = await createReminder.complete(title: pending.title,
                                                                                 timeText: text) {
                return confirmation
            }
        }

        switch await createReminder.execute(text: text) {
        case .created(_, let confirmation):
            return confirmation
        case .needsTime(let title, let question):
            reminderAwaitingTime = PendingReminder(title: title)
            return question
        case .notAReminder:
            return nil
        }
    }

    /// Kalau stream sebelumnya diputus di tengah jalan, rapikan bubble asisten-nya
    /// supaya tidak nyangkut di UI dan tidak ikut ke history berikutnya.
    private func finalizeInterruptedAssistant() {
        guard isStreaming, let last = messages.indices.last,
              messages[last].role == .assistant else { return }
        if messages[last].text.isEmpty {
            messages.remove(at: last)
        } else {
            messages[last].text += " (cancelled)"
        }
        isStreaming = false
    }

    private func persistRecent() {
        let recent = Array(messages.suffix(20))
        if let data = try? JSONEncoder().encode(recent) {
            UserDefaults.standard.set(data, forKey: "jarvis.chat.recent")
        }
    }
}

extension ChatStore: LocallyErasable {}

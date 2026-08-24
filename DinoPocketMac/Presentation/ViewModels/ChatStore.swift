import Foundation
import Observation

@MainActor
@Observable
final class ChatStore {
    var messages: [ChatMessage] = []
    var isStreaming = false
    var persona: Persona = .jarvis
    var noticeMessage: String?

    /// Prompt yang dititipkan quick action di Home, diambil ChatPage saat muncul.
    /// Quick action sebelumnya hanya membuka panel kosong — tombol yang
    /// menjanjikan sesuatu lalu tidak melakukannya adalah sasaran Guideline 2.1.
    var pendingPrompt: String?

    func consumePendingPrompt() -> String? {
        defer { pendingPrompt = nil }
        return pendingPrompt
    }

    var activeBrain: BrainKind {
        didSet { UserDefaults.standard.set(activeBrain.rawValue, forKey: "jarvis.activeBrain") }
    }

    var onCreateReminder: ((PetStore.ReminderSchedule) -> Void)?

    private let brains: [BrainKind: Brain]
    private var streamTask: Task<Void, Never>?
    private var streamGeneration = 0

    init(brains: [BrainKind: Brain]) {
        self.brains = brains
        let saved = UserDefaults.standard.string(forKey: "jarvis.activeBrain")
        // Default Apple Intelligence: build rilis hanya menyertakan otak itu, dan
        // sandbox App Store memblokir jaringan sehingga Ollama tidak akan pernah siap.
        self.activeBrain = saved.flatMap(BrainKind.init(rawValue:)) ?? .apple
        if let data = UserDefaults.standard.data(forKey: "jarvis.chat.recent"),
           let restored = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            messages = restored
        }
    }

    /// Ketersediaan satu otak, tanpa efek samping — untuk baris status di Settings.
    /// `resolveBrain()` tidak dipakai di sana karena ia mengubah `noticeMessage`.
    func availability(of kind: BrainKind) async -> BrainAvailability? {
        guard let brain = brains[kind] else { return nil }
        return await brain.availability()
    }

    /// Pilih otak aktif kalau siap, jika tidak fallback ke otak lain yang siap.
    func resolveBrain() async -> Brain? {
        noticeMessage = nil
        if let active = brains[activeBrain], await active.availability() == .ready {
            return active
        }
        for (kind, brain) in brains where kind != activeBrain {
            if await brain.availability() == .ready {
                noticeMessage = "\(activeBrain.displayName) isn't ready yet — using \(brain.displayName) instead."
                return brain
            }
        }
        noticeMessage = "Apple Intelligence isn't available yet. Enable it in System Settings to chat."
        return nil
    }

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        streamTask?.cancel()
        finalizeInterruptedAssistant()
        messages.append(ChatMessage(id: UUID(), role: .user, text: trimmed, date: .now))

        if let schedule = ReminderIntent.parse(trimmed) {
            noticeMessage = nil
            streamGeneration += 1
            onCreateReminder?(schedule)
            messages.append(ChatMessage(id: UUID(), role: .assistant,
                text: "Done — I set a reminder: \(schedule.title) at \(schedule.timeLabel).", date: .now))
            persistRecent()
            return
        }

        guard let brain = await resolveBrain() else { return }

        let history = messages
        var assistant = ChatMessage(id: UUID(), role: .assistant, text: "", date: .now)
        messages.append(assistant)
        let index = messages.count - 1
        streamGeneration += 1
        let generation = streamGeneration
        isStreaming = true

        let task = Task {
            do {
                for try await cumulative in brain.reply(to: history, persona: persona) {
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

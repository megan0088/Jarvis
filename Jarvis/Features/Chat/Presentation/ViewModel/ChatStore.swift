import Foundation
import Observation

@MainActor
@Observable
final class ChatStore {
    var messages: [ChatMessage] = []
    var isStreaming = false
    var persona: Persona = .jarvis
    var noticeMessage: String?

    var activeBrain: BrainKind {
        didSet { UserDefaults.standard.set(activeBrain.rawValue, forKey: "jarvis.activeBrain") }
    }

    private let brains: [BrainKind: Brain]
    private var streamTask: Task<Void, Never>?
    private var streamGeneration = 0

    init(brains: [BrainKind: Brain]) {
        self.brains = brains
        let saved = UserDefaults.standard.string(forKey: "jarvis.activeBrain")
        self.activeBrain = saved.flatMap(BrainKind.init(rawValue:)) ?? .ollama
    }

    /// Pilih otak aktif kalau siap, jika tidak fallback ke otak lain yang siap.
    func resolveBrain() async -> Brain? {
        noticeMessage = nil
        if let active = brains[activeBrain], await active.availability() == .ready {
            return active
        }
        for (kind, brain) in brains where kind != activeBrain {
            if await brain.availability() == .ready {
                noticeMessage = "\(activeBrain.displayName) belum siap — memakai \(brain.displayName)."
                return brain
            }
        }
        noticeMessage = "Belum ada otak yang siap. Cek Ollama atau Apple Intelligence di Setelan."
        return nil
    }

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        streamTask?.cancel()
        finalizeInterruptedAssistant()
        messages.append(ChatMessage(id: UUID(), role: .user, text: trimmed, date: .now))

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
                    messages[index].text += (messages[index].text.isEmpty ? "" : "\n\n") + "⚠️ Koneksi terputus."
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
            messages[last].text += " (dibatalkan)"
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

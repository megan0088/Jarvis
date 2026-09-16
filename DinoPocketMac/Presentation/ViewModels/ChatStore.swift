import Foundation
import Observation

@MainActor
@Observable
final class ChatStore {
    var messages: [ChatMessage] = []
    var isStreaming = false
    var persona: Persona = .apl
    var noticeMessage: String?

    /// Prompt yang dititipkan quick action di Home, diambil ChatPage saat muncul.
    /// Quick action sebelumnya hanya membuka panel kosong — tombol yang
    /// menjanjikan sesuatu lalu tidak melakukannya adalah sasaran Guideline 2.1.
    var pendingPrompt: String?

    /// Membuang riwayat percakapan yang tersimpan beserta yang ada di memori.
    func eraseAllStoredData() {
        messages = []
        noticeMessage = nil
        pendingPrompt = nil
        reminderAwaitingTime = nil
        UserDefaults.standard.removeObject(forKey: "jarvis.chat.recent")
        UserDefaults.standard.removeObject(forKey: "jarvis.activeBrain")
    }

    func consumePendingPrompt() -> String? {
        defer { pendingPrompt = nil }
        return pendingPrompt
    }

    var activeBrain: BrainKind {
        didSet { UserDefaults.standard.set(activeBrain.rawValue, forKey: "jarvis.activeBrain") }
    }

    /// Pembuatan pengingat, disuntikkan sebagai UseCase.
    ///
    /// Dulu berupa closure `onCreateReminder` yang hanya menyimpan jadwal —
    /// pendaftaran notifikasi terjadi di tempat lain, sehingga apakah pengingat
    /// benar-benar berbunyi bergantung pada siapa yang memasang closure itu.
    /// UseCase menyatukan parse, simpan, dan jadwalkan jadi satu tanggung jawab.
    var createReminder: CreateReminderFromTextUseCase?

    private let brains: [BrainKind: Brain]
    private var streamTask: Task<Void, Never>?
    private var streamGeneration = 0

    /// Reminder yang sedang menunggu jawaban "jam berapa?". Hanya bertahan satu
    /// giliran: pesan berikutnya yang bukan ungkapan waktu membuangnya.
    private var reminderAwaitingTime: PendingReminder?

    private struct PendingReminder {
        let title: String?
    }

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

    /// Ketersediaan terbaik dari SELURUH otak yang terpasang.
    ///
    /// `ChatPage` dulu bertanya `availability(of: .apple)` saja, sehingga layar
    /// chat menutup diri saat Apple Intelligence mati — padahal `resolveBrain()`
    /// akan dengan senang hati memakai otak lain yang siap. Gerbang layar dan
    /// gerbang pengiriman jadi berbeda pendapat; ini menyamakannya.
    func bestAvailability() async -> BrainAvailability {
        let appleStatus = await availability(of: .apple)
        if appleStatus == .ready { return .ready }
        for kind in BrainKind.allCases where kind != .apple {
            if await availability(of: kind) == .ready { return .ready }
        }
        return appleStatus ?? .unavailable("No AI backend is configured in this build.")
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

        if let reply = await localReminderReply(to: trimmed) {
            noticeMessage = nil
            streamGeneration += 1
            messages.append(ChatMessage(id: UUID(), role: .assistant, text: reply, date: .now))
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

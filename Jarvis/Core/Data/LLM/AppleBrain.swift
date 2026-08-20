import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct AppleBrain: Brain {
    var kind: BrainKind { .apple }

    /// Gabungkan riwayat percakapan menjadi satu prompt untuk Foundation Models
    /// (streamResponse menerima satu String; persona sudah di-set via instructions).
    /// Meniru perilaku multi-turn OllamaBrain yang meneruskan seluruh history.
    static func buildPrompt(from history: [ChatMessage]) -> String {
        let turns = history.map { msg in
            let who = msg.role == .user ? "User" : "Jarvis"
            return "\(who): \(msg.text)"
        }
        return (turns + ["Jarvis:"]).joined(separator: "\n")
    }

    func availability() async -> BrainAvailability {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .ready
            case .unavailable(.appleIntelligenceNotEnabled):
                return .unavailable("Aktifkan Apple Intelligence di System Settings.")
            case .unavailable(.modelNotReady):
                return .needsSetup("Model on-device sedang diunduh. Coba lagi nanti.")
            case .unavailable:
                return .unavailable("Apple Intelligence tidak tersedia di perangkat ini.")
            }
        } else {
            return .unavailable("Butuh macOS 26 atau lebih baru.")
        }
        #else
        return .unavailable("FoundationModels tidak tersedia di build ini.")
        #endif
    }

    func reply(to history: [ChatMessage], persona: Persona) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            #if canImport(FoundationModels)
            if #available(macOS 26.0, *) {
                let task = Task {
                    do {
                        let session = LanguageModelSession(instructions: persona.systemPrompt)
                        let prompt = AppleBrain.buildPrompt(from: history)
                        for try await partial in session.streamResponse(to: prompt) {
                            if Task.isCancelled { break }
                            continuation.yield(partial.content) // snapshot kumulatif
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
                return
            }
            #endif
            continuation.finish(throwing: NSError(domain: "AppleBrain", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Apple Intelligence tidak tersedia."]))
        }
    }
}

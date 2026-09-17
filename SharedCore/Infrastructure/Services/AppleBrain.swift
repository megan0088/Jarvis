import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Otak on-device di atas Foundation Models.
///
/// `final class`, bukan `struct`: sesi percakapan harus BERTAHAN antar pesan.
/// Versi sebelumnya membuat `LanguageModelSession` baru setiap kali dipanggil
/// dan memipihkan seluruh riwayat jadi satu string — transcript milik model
/// dibuang tiap giliran, string terus tumbuh, dan cepat atau lambat menabrak
/// `exceededContextWindowSize` yang tidak ditangani siapa pun. "Ingat
/// percakapan" secara harfiah tidak ada: tiap pesan adalah sesi baru yang
/// pura-pura ingat.
@MainActor
final class AppleBrain: Brain {

    #if canImport(FoundationModels)
    /// Wadah sesi hidup. Instructions ditetapkan saat sesi dibuat dan tidak
    /// pernah berubah (`AplInstructions`), jadi satu sesi bertahan selama app hidup.
    ///
    /// Deployment target sudah macOS 26.2 sehingga `@available` wrapper tidak
    /// lagi diperlukan; stored property bisa dideklarasikan langsung.
    @available(macOS 26.0, iOS 26.0, *)
    final class SessionBox {
        var session: LanguageModelSession?
    }

    private var sessionBox = SessionBox()
    #endif

    private let sessions: (any Sendable)?

    /// - Parameter sessionStore: penyimpan transcript. `nil` berarti percakapan
    ///   tetap berjalan tetapi tidak bertahan setelah app ditutup.
    init(sessionStore: (any Sendable)? = nil) {
        self.sessions = sessionStore
    }

    /// Gabungkan riwayat percakapan menjadi satu prompt untuk Foundation Models
    /// (streamResponse menerima satu String; instructions sudah di-set saat sesi dibuat).
    nonisolated static func buildPrompt(from history: [ChatMessage]) -> String {
        let turns = history.map { msg in
            let who = msg.role == .user ? "User" : "Apl"
            return "\(who): \(msg.text)"
        }
        return (turns + ["Apl:"]).joined(separator: "\n")
    }

    nonisolated func availability() async -> BrainAvailability {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .ready
            case .unavailable(.appleIntelligenceNotEnabled):
                return .unavailable("Enable Apple Intelligence in System Settings.")
            case .unavailable(.modelNotReady):
                return .needsSetup("The on-device model is downloading. Try again later.")
            case .unavailable:
                return .unavailable("Apple Intelligence isn't available on this device.")
            }
        } else {
            return .unavailable("Requires macOS 26 or later.")
        }
        #else
        return .unavailable("FoundationModels isn't available in this build.")
        #endif
    }

    nonisolated func reply(to history: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            #if canImport(FoundationModels)
            if #available(macOS 26.0, *) {
                let task = Task { @MainActor in
                    do {
                        try await self.stream(history: history) { chunk in
                            continuation.yield(chunk)
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: Self.mapped(error))
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
                return
            }
            #endif
            continuation.finish(throwing: AplError.noBrainAvailable(
                reason: "Apple Intelligence isn't available."))
        }
    }

    nonisolated func resetConversation() async {
        await forgetSession()
    }

    /// Sesi di memori dibuang bersama transcript-nya. Stream yang masih
    /// berjalan tidak menyimpan ulang transcript lama: penyimpanan di akhir
    /// `stream` hanya terjadi bila `sessionBox.session` masih ada.
    private func forgetSession() {
        #if canImport(FoundationModels)
        sessionBox.session = nil
        (sessions as? any ChatSessionStoring)?.clear()
        #endif
    }

    #if canImport(FoundationModels)
    @available(macOS 26.0, iOS 26.0, *)
    private func stream(history: [ChatMessage],
                        onChunk: @escaping (String) -> Void) async throws {

        let store = sessions as? any ChatSessionStoring
        let box = sessionBox

        var isResumed = true
        if box.session == nil {
            if let transcript = store?.loadTranscript(), !transcript.isEmpty {
                box.session = LanguageModelSession(transcript: transcript)
            } else {
                box.session = LanguageModelSession(instructions: AplInstructions.text)
                isResumed = false
            }
        }
        guard let session = box.session else { return }

        // Sesi yang dilanjutkan sudah memegang riwayatnya sendiri, jadi cukup
        // kirim pesan terbaru. Sesi baru tanpa transcript belum tahu apa-apa,
        // jadi riwayat UI dipipihkan sekali untuk memulihkan konteks.
        let prompt = isResumed
            ? (history.last(where: { $0.role == .user })?.text ?? "")
            : Self.buildPrompt(from: history)

        do {
            for try await partial in session.streamResponse(to: prompt) {
                if Task.isCancelled { break }
                onChunk(partial.content)
            }
        } catch let error as LanguageModelSession.GenerationError {
            guard case .exceededContextWindowSize = error else { throw error }

            // Pangkas dan ulang SEKALI. Percakapan yang tetap tidak muat setelah
            // dipangkas berarti satu pesannya memang terlalu besar; mengulang
            // terus hanya menunda pesan kesalahan yang sama.
            let trimmed = TranscriptTrimmer.trimmed(session.transcript)
            let retry = LanguageModelSession(transcript: trimmed)
            box.session = retry
            for try await partial in retry.streamResponse(to: prompt) {
                if Task.isCancelled { break }
                onChunk(partial.content)
            }
        }

        if let session = box.session {
            store?.save(session.transcript)
        }
    }

    @available(macOS 26.0, iOS 26.0, *)
    private static func mapped(_ error: Error) -> Error {
        guard let generation = error as? LanguageModelSession.GenerationError else { return error }
        switch generation {
        case .exceededContextWindowSize: return AplError.conversationTooLong
        case .guardrailViolation:        return AplError.requestBlocked
        default:                         return error
        }
    }
    #endif
}

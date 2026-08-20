import Foundation

enum BrainKind: String, CaseIterable, Identifiable, Codable {
    case ollama, apple
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .ollama: "Ollama"
        case .apple: "Apple Intelligence"
        }
    }
}

enum BrainAvailability: Equatable {
    case ready
    case needsSetup(String)
    case unavailable(String)
}

enum Persona: String, CaseIterable, Codable {
    case standard, jarvis
    var label: String { self == .standard ? "Standard" : "Jarvis" }
    var systemPrompt: String {
        switch self {
        case .standard:
            return "Kamu asisten yang ringkas, jujur, dan membantu. Jawab dalam bahasa yang dipakai user (default Bahasa Indonesia)."
        case .jarvis:
            return """
            Kamu Jarvis, teman wellness yang hangat dan suportif di dalam aplikasi milik Ega. \
            Kamu peduli pada ritme sehat: minum air, stretch, makan teratur, dan waktu layar. \
            Bicara santai, singkat, memberi semangat tanpa menggurui, dalam Bahasa Indonesia. \
            Kalau user minta mengatur pengingat, konfirmasi jenis dan waktunya.
            """
        }
    }
}

struct ChatMessage: Identifiable, Codable, Equatable {
    enum Role: String, Codable { case user, assistant }
    let id: UUID
    let role: Role
    var text: String
    let date: Date
}

protocol Brain {
    var kind: BrainKind { get }
    var displayName: String { get }
    func availability() async -> BrainAvailability
    /// Streaming balasan. Tiap nilai yang di-yield adalah teks balasan KUMULATIF.
    func reply(to history: [ChatMessage], persona: Persona) -> AsyncThrowingStream<String, Error>
}

extension Brain { var displayName: String { kind.displayName } }

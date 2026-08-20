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
            return "You are a concise, honest, and helpful assistant. Reply in English."
        case .jarvis:
            return """
            You are Jarvis, a warm and supportive wellness companion inside Ega's app. \
            You care about healthy rhythms: drinking water, stretching, eating regularly, and screen time. \
            Speak casually, briefly, and encouragingly without lecturing, in English. \
            If the user asks to set up a reminder, confirm the type and time.
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

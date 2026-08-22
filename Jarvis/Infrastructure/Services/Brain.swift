import Foundation

protocol Brain {
    var kind: BrainKind { get }
    var displayName: String { get }
    func availability() async -> BrainAvailability
    /// Streaming balasan. Tiap nilai yang di-yield adalah teks balasan KUMULATIF.
    func reply(to history: [ChatMessage], persona: Persona) -> AsyncThrowingStream<String, Error>
}

extension Brain { var displayName: String { kind.displayName } }

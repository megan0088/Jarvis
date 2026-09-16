import Foundation
import Testing
@testable import Apl

struct BrainTypesTests {
    @Test func brainKindHasBothBackends() {
        #expect(BrainKind.allCases == [.ollama, .apple])
    }

    @Test func personasHaveNonEmptyDistinctPrompts() {
        #expect(!Persona.standard.systemPrompt.isEmpty)
        #expect(!Persona.apl.systemPrompt.isEmpty)
        #expect(Persona.standard.systemPrompt != Persona.apl.systemPrompt)
    }

    @Test func chatMessageRoundTripsThroughCodable() throws {
        let msg = ChatMessage(id: UUID(), role: .user, text: "halo", date: Date(timeIntervalSince1970: 0))
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)
        #expect(decoded == msg)
    }
}

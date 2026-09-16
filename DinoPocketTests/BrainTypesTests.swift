import Foundation
import Testing
@testable import Apl

struct BrainTypesTests {

    /// Reminder dibuat parser, bukan model. Instructions harus melarang model
    /// mengaku membuat reminder, supaya ia tidak menjawab "Sure!" tanpa bukti.
    @Test func instructionsForbidTheModelFromClaimingReminders() {
        #expect(AplInstructions.text.contains("cannot create, change, or cancel reminders"))
    }

    @Test func chatMessageRoundTripsThroughCodable() throws {
        let msg = ChatMessage(id: UUID(), role: .user, text: "halo", date: Date(timeIntervalSince1970: 0))
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)
        #expect(decoded == msg)
    }
}

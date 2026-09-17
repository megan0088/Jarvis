import Foundation
import Testing
@testable import Apl

struct ChatMessageTests {

    @Test func attachmentAndStatusSurviveARoundTrip() throws {
        let message = ChatMessage(role: .assistant, text: "Done", date: TestTime.now,
                                  attachment: .reminder(UUID()), status: .stopped)

        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)

        #expect(decoded == message)
    }

    /// Percakapan yang tersimpan sebelum B tidak punya kedua kunci baru.
    /// Kalau decoding-nya gagal, seluruh riwayat lenyap diam-diam saat app dibuka.
    @Test func messagesSavedBeforeAttachmentsStillDecode() throws {
        let stored = """
        [{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","role":"user","text":"hi","date":800000000}]
        """

        let decoded = try JSONDecoder().decode([ChatMessage].self, from: Data(stored.utf8))

        #expect(decoded.count == 1)
        #expect(decoded[0].text == "hi")
        #expect(decoded[0].attachment == nil)
        #expect(decoded[0].status == .complete)
    }
}

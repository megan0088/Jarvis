import Foundation
import Testing
@testable import Apl

struct MessageRowKindTests {

    /// Bentuk baris ditentukan data — peran, status, lampiran — bukan bunyi teks.
    @Test func kindFollowsRoleStatusAndAttachment() {
        let id = UUID()

        #expect(MessageRowKind.of(ChatMessage(role: .user, text: "hi")) == .user)
        #expect(MessageRowKind.of(ChatMessage(role: .assistant, text: "yo")) == .assistant(stopped: false))
        #expect(MessageRowKind.of(ChatMessage(role: .assistant, text: "yo", status: .stopped))
                == .assistant(stopped: true))
        #expect(MessageRowKind.of(ChatMessage(role: .assistant, text: "Done", attachment: .reminder(id)))
                == .reminderConfirmation(id))
    }

    /// Kegagalan menang atas apa pun: yang perlu dilihat adalah kegagalannya.
    @Test func failureWinsOverAttachmentAndEmptyText() {
        #expect(MessageRowKind.of(ChatMessage(role: .assistant, text: "", status: .failed)) == .failed)
        #expect(MessageRowKind.of(ChatMessage(role: .assistant, text: "Done",
                                              attachment: .reminder(UUID()), status: .failed)) == .failed)
    }

    /// Pesan Apl yang masih kosong adalah jawaban yang belum datang. Merender-
    /// nya sebagai teks berarti baris kosong di percakapan.
    @Test func emptyAssistantMessageIsAPlaceholder() {
        #expect(MessageRowKind.of(ChatMessage(role: .assistant, text: "")) == .placeholder)
    }

    /// Pesan pengguna tidak pernah jadi placeholder, sekosong apa pun.
    @Test func userMessagesAreAlwaysUser() {
        #expect(MessageRowKind.of(ChatMessage(role: .user, text: "")) == .user)
    }
}

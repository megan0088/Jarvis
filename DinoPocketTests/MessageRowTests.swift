import Foundation
import Testing
@testable import Apl

struct MessageRowTests {

    /// Cara pesan dirender ditentukan data (peran, status, lampiran), bukan bunyi teksnya.
    @Test func rowKindFollowsRoleStatusAndAttachment() {
        let id = UUID()

        #expect(MessageRow.kind(of: ChatMessage(role: .user, text: "hi")) == .user)
        #expect(MessageRow.kind(of: ChatMessage(role: .assistant, text: "yo")) == .assistant(stopped: false))
        #expect(MessageRow.kind(of: ChatMessage(role: .assistant, text: "yo", status: .stopped))
                == .assistant(stopped: true))
        #expect(MessageRow.kind(of: ChatMessage(role: .assistant, text: "Done", attachment: .reminder(id)))
                == .reminderConfirmation(id))
        #expect(MessageRow.kind(of: ChatMessage(role: .assistant, text: "", status: .failed)) == .failed)
    }

    @Test func pictureAttachmentPicksThePictureRow() {
        let message = ChatMessage(role: .assistant, text: "",
                                  attachment: .picture(name: "a.png", concept: "an orange cat"))
        #expect(MessageRow.kind(of: message) == .picture(name: "a.png", concept: "an orange cat"))
    }

    /// Gambar yang gagal tetap kalah oleh status gagal: yang perlu dilihat
    /// pengguna adalah kegagalannya.
    @Test func failureStillWins() {
        let message = ChatMessage(role: .assistant, text: "",
                                  attachment: .picture(name: "a.png", concept: "a cat"), status: .failed)
        #expect(MessageRow.kind(of: message) == .failed)
    }
}

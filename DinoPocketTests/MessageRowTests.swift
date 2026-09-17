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
}

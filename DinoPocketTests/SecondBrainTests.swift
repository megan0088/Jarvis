import Foundation
import Testing
@testable import Apl

@MainActor
struct SecondBrainTests {

    private func isolatedDefaults(_ name: String) -> UserDefaults {
        let suite = "test.secondbrain.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    /// Dua percakapan dalam satu app harus menyimpan ke kunci berbeda; kalau
    /// tidak, riwayat Chat dan Code saling menimpa di disk.
    @Test func twoStoresDoNotSeeEachOther() {
        let defaults = isolatedDefaults(#function)
        let chat = ChatStore(brain: nil, defaults: defaults)
        let code = ChatStore(brain: nil, defaults: defaults, recentKey: "code.chat.recent")

        chat.messages = [ChatMessage(role: .user, text: "halo")]
        code.messages = [ChatMessage(role: .user, text: "explain A.swift")]
        chat.persistForTesting()
        code.persistForTesting()

        #expect(ChatStore(brain: nil, defaults: defaults).messages.first?.text == "halo")
        #expect(ChatStore(brain: nil, defaults: defaults, recentKey: "code.chat.recent")
                    .messages.first?.text == "explain A.swift")
    }

    /// Menghapus percakapan sisi Code tidak boleh menyentuh riwayat Chat.
    @Test func clearingOneLeavesTheOther() {
        let defaults = isolatedDefaults(#function)
        let chat = ChatStore(brain: nil, defaults: defaults)
        let code = ChatStore(brain: nil, defaults: defaults, recentKey: "code.chat.recent")
        chat.messages = [ChatMessage(role: .user, text: "halo")]
        chat.persistForTesting()
        code.messages = [ChatMessage(role: .user, text: "explain A.swift")]
        code.persistForTesting()

        code.eraseAllStoredData()

        #expect(ChatStore(brain: nil, defaults: defaults).messages.first?.text == "halo")
        #expect(ChatStore(brain: nil, defaults: defaults, recentKey: "code.chat.recent").messages.isEmpty)
    }

    @Test func brainKeepsItsDefaultInstructions() {
        #expect(AppleBrain().instructionsText == AplInstructions.text)
    }

    @Test func brainCanBeGivenCodeInstructions() {
        #expect(AppleBrain(instructions: CodeInstructions.text).instructionsText == CodeInstructions.text)
    }
}

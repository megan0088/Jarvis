import Foundation
import Testing
@testable import Apl

@MainActor
struct PlayWithoutBrainTests {

    /// Janji spec F §2 #1: permainan tidak pernah menyentuh model. `brain: nil`
    /// membuat jalur model gagal keras, jadi kalau ronde tetap berjalan penuh,
    /// ia memang tidak lewat sana.
    @Test func aFullRoundRunsWithNoBrainAtAll() async {
        let defaults = UserDefaults(suiteName: "test.playnobrain.\(UUID())")!
        let chat = ChatStore(brain: nil, defaults: defaults)
        let game = SuitGame(score: GameScore(defaults: defaults), draw: { .scissors }, think: {})

        chat.playRequested = { game.start() }
        await chat.send("main suit")

        #expect(game.round != nil)
        await game.pick(.rock)
        #expect(game.round?.outcome == .youWin)
        #expect(chat.noticeMessage == nil)
    }
}

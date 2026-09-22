import Foundation
import Testing
@testable import Apl

@MainActor
struct SuitGameTests {

    /// `think` kosong: testnya tidak menunggu tiga perempat detik sungguhan.
    private func game(drawing next: Throw = .rock) -> SuitGame {
        SuitGame(score: GameScore(defaults: UserDefaults(suiteName: "test.suitgame.\(UUID())")!),
                 draw: { next }, think: {})
    }

    /// Lemparan robot dikunci saat ronde DIBUAT. Kalau ia diacak setelah
    /// pengguna memilih, tidak ada cara membuktikan ia tidak curang.
    @Test func aplCommitsBeforeYouChoose() {
        let g = game(drawing: .scissors)
        g.start()
        #expect(g.round?.aplThrow == .scissors)
        #expect(g.round?.isRevealed == false)
    }

    @Test func pickingResolvesTheRound() async {
        let g = game(drawing: .scissors)
        g.start()
        await g.pick(.rock)
        #expect(g.round?.yours == .rock)
        #expect(g.round?.outcome == .youWin)
        #expect(g.round?.isRevealed == true)
    }

    @Test func resultIsRecordedInTheScore() async {
        let g = game(drawing: .scissors)
        g.start()
        await g.pick(.rock)
        #expect(g.score.wins == 1)
    }

    /// Robot berpikir DULU, baru mengungkap. Diuji dengan mengintip keadaan
    /// dari dalam jeda yang disuntikkan, bukan dengan menunggu.
    @Test func robotThinksBeforeRevealing() async {
        let box = Box()
        let score = GameScore(defaults: UserDefaults(suiteName: "test.think.\(UUID())")!)
        let g = SuitGame(score: score, draw: { .rock },
                         think: { box.thinkingDuringPause = box.game?.round?.isThinking })
        box.game = g
        g.start()
        await g.pick(.paper)
        #expect(box.thinkingDuringPause == true)
        #expect(g.round?.isThinking == false)
        #expect(g.round?.isRevealed == true)
    }

    @MainActor final class Box { var game: SuitGame?; var thinkingDuringPause: Bool? }

    /// Menekan tombol dua kali tidak boleh menghitung dua kemenangan.
    @Test func pickingTwiceChangesNothing() async {
        let g = game(drawing: .scissors)
        g.start()
        await g.pick(.rock)
        await g.pick(.paper)
        #expect(g.round?.yours == .rock)
        #expect(g.score.wins == 1)
    }

    @Test func againStartsAFreshUnrevealedRound() async {
        let g = game(drawing: .rock)
        g.start()
        await g.pick(.paper)
        g.again()
        #expect(g.round?.isRevealed == false)
        #expect(g.round?.yours == nil)
    }

    @Test func finishClearsTheRound() {
        let g = game()
        g.start()
        g.finish()
        #expect(g.round == nil)
    }
}

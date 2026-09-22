import Foundation
import Testing
@testable import Apl

@MainActor
struct GameScoreTests {

    private func isolatedDefaults(_ name: String) -> UserDefaults {
        let suite = "test.score.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func countsEachOutcome() {
        let score = GameScore(defaults: isolatedDefaults(#function))
        score.record(.youWin)
        score.record(.youWin)
        score.record(.aplWins)
        score.record(.draw)
        #expect(score.wins == 2)
        #expect(score.losses == 1)
        #expect(score.draws == 1)
    }

    @Test func survivesRelaunch() {
        let defaults = isolatedDefaults(#function)
        GameScore(defaults: defaults).record(.youWin)
        #expect(GameScore(defaults: defaults).wins == 1)
    }

    @Test func eraseLeavesNoKeyBehind() {
        let defaults = isolatedDefaults(#function)
        let score = GameScore(defaults: defaults)
        score.record(.youWin)
        score.eraseAllStoredData()
        #expect(score.wins == 0)
        #expect(defaults.data(forKey: GameScore.key) == nil)
    }
}

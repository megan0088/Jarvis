import Testing
@testable import Apl

struct ThrowTests {

    /// Kesembilan kombinasi, satu per satu. Tabel kemenangan adalah tempat
    /// paling mudah membuat salah ketik yang tidak pernah ketahuan.
    @Test func everyCombination() {
        #expect(RoundOutcome.of(you: .rock, apl: .rock) == .draw)
        #expect(RoundOutcome.of(you: .rock, apl: .paper) == .aplWins)
        #expect(RoundOutcome.of(you: .rock, apl: .scissors) == .youWin)
        #expect(RoundOutcome.of(you: .paper, apl: .rock) == .youWin)
        #expect(RoundOutcome.of(you: .paper, apl: .paper) == .draw)
        #expect(RoundOutcome.of(you: .paper, apl: .scissors) == .aplWins)
        #expect(RoundOutcome.of(you: .scissors, apl: .rock) == .aplWins)
        #expect(RoundOutcome.of(you: .scissors, apl: .paper) == .youWin)
        #expect(RoundOutcome.of(you: .scissors, apl: .scissors) == .draw)
    }

    @Test func everyThrowHasAName() {
        for item in Throw.allCases {
            #expect(!item.name.isEmpty)
            #expect(!item.symbol.isEmpty)
        }
    }

    /// Acak harus benar-benar bisa menghasilkan ketiganya; undian yang selalu
    /// sama adalah lawan yang membosankan dan bug yang sunyi.
    @Test func randomEventuallyProducesAllThree() {
        var seen: Set<Throw> = []
        for _ in 0..<200 { seen.insert(Throw.random()) }
        #expect(seen.count == 3)
    }
}

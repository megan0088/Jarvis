//
//  SuitGame.swift
//  Apl
//
//  Keadaan satu permainan suit (spec F §3–§4).
//
//  Tidak tahu apa-apa soal balon, panel, maupun chat — seluruh aturannya bisa
//  dijalankan tanpa satu piksel pun. Undiannya disuntikkan supaya "robot
//  memilih lebih dulu" bisa dibuktikan, bukan sekadar dijanjikan.
//

import Foundation
import Observation

@MainActor
@Observable
final class SuitGame {

    struct Round: Equatable {
        /// Dikunci saat ronde dibuat, sebelum pengguna memilih (spec F §2 #2).
        let aplThrow: Throw
        var yours: Throw?
        var outcome: RoundOutcome?
        var isThinking = false
        var isRevealed: Bool { outcome != nil }
    }

    private(set) var round: Round?
    let score: GameScore
    private let draw: () -> Throw
    private let think: () async -> Void

    init(score: GameScore,
         draw: @escaping () -> Throw = Throw.random,
         think: @escaping () async -> Void = { try? await Task.sleep(for: .milliseconds(750)) }) {
        self.score = score
        self.draw = draw
        self.think = think
    }

    func start() {
        round = Round(aplThrow: draw())
    }

    /// Berpikir dulu, baru mengungkap — jeda itu yang membuat lemparan robot
    /// terasa seperti keputusan, bukan tabel.
    func pick(_ yours: Throw) async {
        guard var current = round, current.yours == nil else { return }
        current.yours = yours
        current.isThinking = true
        round = current

        await think()

        guard var revealing = round, revealing.yours == yours, revealing.outcome == nil else { return }
        let outcome = RoundOutcome.of(you: yours, apl: revealing.aplThrow)
        revealing.outcome = outcome
        revealing.isThinking = false
        round = revealing
        score.record(outcome)
    }

    func again() {
        start()
    }

    func finish() {
        round = nil
    }
}

#if DEBUG
extension SuitGame {
    static func previewFresh() -> SuitGame {
        SuitGame(score: GameScore(defaults: UserDefaults(suiteName: "apl.preview.game")!),
                 draw: { .paper }, think: {})
    }

    /// `think: {}` membuat hasilnya muncul pada giliran main actor berikutnya,
    /// jadi preview-nya sudah menampilkan ronde yang selesai.
    static func previewResolved() -> SuitGame {
        let game = previewFresh()
        game.start()
        Task { await game.pick(.scissors) }
        return game
    }
}
#endif

//
//  GameScore.swift
//  Apl
//
//  Tally suit yang bertahan (spec F §5).
//

import Foundation
import Observation

@MainActor
@Observable
final class GameScore {

    nonisolated static let key = "game.suit.score"

    private struct Tally: Codable, Equatable {
        var wins = 0, losses = 0, draws = 0
    }

    private var tally: Tally
    private let defaults: UserDefaults

    var wins: Int { tally.wins }
    var losses: Int { tally.losses }
    var draws: Int { tally.draws }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let restored = try? JSONDecoder().decode(Tally.self, from: data) {
            tally = restored
        } else {
            tally = Tally()
        }
    }

    func record(_ outcome: RoundOutcome) {
        switch outcome {
        case .youWin: tally.wins += 1
        case .aplWins: tally.losses += 1
        case .draw: tally.draws += 1
        }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(tally) else { return }
        defaults.set(data, forKey: Self.key)
        // Dipaksa turun ke disk; lihat catatan di `ProfileStore`.
        defaults.synchronize()
    }
}

extension GameScore: LocallyErasable {
    func eraseAllStoredData() {
        tally = Tally()
        defaults.removeObject(forKey: Self.key)
        defaults.synchronize()
    }
}

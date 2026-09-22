//
//  Throw.swift
//  Apl
//
//  Aturan suit (spec F §3). Murni, dan seluruhnya ada di satu tempat.
//

enum Throw: CaseIterable, Equatable, Hashable {
    case rock, paper, scissors

    var name: String {
        switch self {
        case .rock: "Rock"
        case .paper: "Paper"
        case .scissors: "Scissors"
        }
    }

    var symbol: String {
        switch self {
        case .rock: "circle.fill"
        case .paper: "rectangle.fill"
        case .scissors: "scissors"
        }
    }

    static func random() -> Throw {
        allCases.randomElement() ?? .rock
    }

    /// Apa yang dikalahkan lemparan ini.
    var beats: Throw {
        switch self {
        case .rock: .scissors
        case .paper: .rock
        case .scissors: .paper
        }
    }
}

enum RoundOutcome: Equatable {
    case youWin, aplWins, draw

    static func of(you: Throw, apl: Throw) -> RoundOutcome {
        if you == apl { return .draw }
        return you.beats == apl ? .youWin : .aplWins
    }
}

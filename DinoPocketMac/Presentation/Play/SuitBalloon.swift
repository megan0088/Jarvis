//
//  SuitBalloon.swift
//  Apl
//
//  Satu ronde suit di samping robot (spec F §4).
//
//  Dipakai dua tempat tanpa perubahan: di dalam balon saat robot ada, dan di
//  dalam chat saat Buddy Mode mati.
//

import SwiftUI

struct SuitBalloon: View {
    let game: SuitGame
    let onFinish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let round = game.round {
                if let outcome = round.outcome, let yours = round.yours {
                    result(yours: yours, apl: round.aplThrow, outcome: outcome)
                } else if round.isThinking {
                    Label("Thinking…", systemImage: "ellipsis")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Rock, paper, or scissors?")
                    choices
                }
            }
            score
        }
        .font(.callout)
        .padding(Spacing.md)
        .frame(maxWidth: 300, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(.separator))
        // Esc selalu menutup, juga sebelum memilih: balon yang tidak bisa
        // ditutup adalah balon yang menahan sandera.
        .onExitCommand(perform: onFinish)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Rock paper scissors")
    }

    private var choices: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(Array(Throw.allCases.enumerated()), id: \.element) { index, item in
                Button(item.name) { Task { await game.pick(item) } }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [])
                    .accessibilityHint("Press \(index + 1)")
            }
        }
    }

    private func result(yours: Throw, apl: Throw, outcome: RoundOutcome) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("You: \(yours.name) · Apl: \(apl.name)")
                .foregroundStyle(.secondary)
            Text(Self.headline(outcome)).fontWeight(.medium)
            HStack(spacing: Spacing.sm) {
                Button("Again") { game.again() }
                    .keyboardShortcut(.defaultAction)
                Button("Done", action: onFinish)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .onAppear { AnswerAnnouncement.post(Self.headline(outcome), priority: .medium) }
    }

    private var score: some View {
        Text("You \(game.score.wins) · Apl \(game.score.losses)"
             + (game.score.draws > 0 ? " · \(game.score.draws) drawn" : ""))
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
    }

    /// Kalimatnya pasti, bukan acak — alasan yang sama dengan C1 dan C2.
    static func headline(_ outcome: RoundOutcome) -> String {
        switch outcome {
        case .youWin: "You win."
        case .aplWins: "Apl wins."
        case .draw: "A draw."
        }
    }
}

#Preview("Balon suit · sebelum memilih") {
    SuitBalloon(game: SuitGame.previewFresh(), onFinish: {})
        .padding(Spacing.xl)
}

#Preview("Balon suit · hasil · Dark") {
    SuitBalloon(game: SuitGame.previewResolved(), onFinish: {})
        .padding(Spacing.xl)
        .preferredColorScheme(.dark)
}

//
//  PlayPanelController.swift
//  Apl
//
//  Balon permainan: boleh menerima fokus keyboard, karena pengguna sendiri
//  yang memulainya dengan mengetik (spec F §2 #4).
//

import AppKit
import SwiftUI

@MainActor
final class PlayPanelController {

    static let shared = PlayPanelController()

    private let panel: AnchoredPanel
    private let buddy: AplBuddyWindowController
    private var game: SuitGame?

    init(buddy: AplBuddyWindowController = .shared) {
        self.buddy = buddy
        panel = AnchoredPanel(canBecomeKey: true, buddy: buddy)
    }

    var isShowing: Bool { panel.isShowing }

    /// `false` berarti tidak ada robot; pemanggil memainkannya di chat.
    @discardableResult
    func show(game: SuitGame) -> Bool {
        self.game = game
        return render()
    }

    func dismiss() {
        // Ekspresi dikembalikan ke mood mesin begitu ronde selesai (spec F §8 #2).
        buddy.playExpression = nil
        game?.finish()
        game = nil
        panel.dismiss()
    }

    /// Balonnya memperbarui dirinya sendiri — `SuitGame` `@Observable`. Yang
    /// tidak bisa ia lakukan adalah mengubah wajah robot dan tinggi panel,
    /// jadi hanya dua hal itu yang diikat di sini.
    private func render() -> Bool {
        guard let game else { return false }
        buddy.playExpression = Self.expression(for: game.round)
        return panel.show(
            SuitBalloon(game: game, onFinish: { [weak self] in self?.dismiss() })
                .onChange(of: game.round) { [weak self] _, round in
                    self?.buddy.playExpression = PlayPanelController.expression(for: round)
                    self?.panel.reposition()
                }
        )
    }

    static func expression(for round: SuitGame.Round?) -> CharacterBehavior? {
        guard let round else { return nil }
        if round.isThinking { return .thinking }
        switch round.outcome {
        case .aplWins: return .celebrate
        case .youWin: return .sad
        case .draw: return .idle
        case nil: return .greet
        }
    }
}

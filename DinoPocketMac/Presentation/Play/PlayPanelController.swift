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

    /// - Parameter endingRound: `false` saat robot pergi di tengah ronde —
    ///   balonnya ditutup, tetapi rondenya pindah ke chat (spec F §2 #6), bukan
    ///   hilang begitu saja.
    func dismiss(endingRound: Bool = true) {
        // Ekspresi dikembalikan ke mood mesin begitu ronde selesai (spec F §8 #2).
        buddy.playExpression = nil
        if endingRound { game?.finish() }
        game = nil
        panel.dismiss()
    }

    /// Balonnya memperbarui dirinya sendiri — `SuitGame` `@Observable`. Yang
    /// tidak bisa ia lakukan adalah mengubah wajah robot dan tinggi panel,
    /// jadi hanya dua hal itu yang diikat lewat `PlayBalloonHost`.
    private func render() -> Bool {
        guard let game else { return false }
        return panel.show(
            PlayBalloonHost(game: game,
                            onFinish: { [weak self] in self?.dismiss() },
                            onRound: { [weak self] round in
                                self?.buddy.playExpression = PlayPanelController.expression(for: round)
                                self?.panel.repositionAfterLayout()
                            })
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

/// Pembawa efek samping balon: wajah robot dan tinggi panel.
///
/// Ada karena `onChange` yang dipasang dari luar SwiftUI tidak pernah menyala.
/// Observation hanya mencatat pembacaan yang terjadi DI DALAM `body`; ronde yang
/// dibaca saat view dibangun secara imperatif — di `render()` — tidak tercatat,
/// jadi tidak ada yang mengevaluasi ulang modifier itu. Ketahuan dari verifikasi
/// manual: balon menampilkan hasilnya dengan benar sementara wajah robot masih
/// tertinggal di `.greet`.
private struct PlayBalloonHost: View {
    let game: SuitGame
    let onFinish: () -> Void
    let onRound: (SuitGame.Round?) -> Void

    var body: some View {
        SuitBalloon(game: game, onFinish: onFinish)
            // `initial: true` menyetel wajah pertama sekalian, jadi tidak ada
            // dua tempat yang mengatur hal yang sama.
            .onChange(of: game.round, initial: true) { _, round in onRound(round) }
    }
}

//
//  PlayCommand.swift
//  Apl
//
//  Mengenali ajakan main suit dari kalimat biasa (spec F §2 #3).
//
//  Yang paling berbahaya bukan ajakan yang tidak dikenali — pengguna tinggal
//  mengetik ulang — melainkan kalimat yang DIKENALI padahal bukan. "Remind me
//  to play football" yang berubah jadi permainan berarti pengingat yang hilang.
//

import Foundation

enum PlayCommand {

    private static let phrases = [
        "main suit", "ayo suit", "suit yuk", "suitan",
        "rock paper scissors", "rock-paper-scissors", "play rps",
    ]

    static func matches(_ text: String) -> Bool {
        let lowered = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        // Kalimat yang meminta pengingat tidak pernah jadi ajakan main, apa pun
        // isinya sesudah itu.
        guard !lowered.contains("remind me") else { return false }
        return phrases.contains { lowered.contains($0) }
    }
}

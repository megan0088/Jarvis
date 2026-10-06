//
//  DrawCommand.swift
//  Apl
//
//  Mengenali ajakan menggambar dan memotong konsepnya (spec G §2 #2, §3).
//
//  "draw" adalah kata biasa di percakapan tentang koding, jadi unit ini lebih
//  berhati-hati daripada `PlayCommand`: kalimat tanya tidak pernah jadi ajakan,
//  dan ajakan tanpa konsep bukan ajakan sama sekali.
//

import Foundation

enum DrawCommand {

    /// Awalan yang dikenali, diperiksa dari yang paling panjang supaya
    /// "buatkan gambar" tidak keburu tertangkap "gambar".
    private static let prefixes = [
        "buatkan gambar", "bikin gambar", "tolong gambarkan",
        "gambarkan", "gambar", "draw me", "draw",
    ]

    private static let questionOpeners = [
        "how ", "what ", "why ", "when ", "where ", "which ", "apa ", "kenapa ", "bagaimana ",
    ]

    /// Konsep yang diminta, atau `nil` bila ini bukan ajakan menggambar.
    static func concept(in text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()

        // Pengingat tetap pengingat, apa pun isinya sesudah itu.
        guard !lowered.contains("remind me") else { return nil }
        // Pertanyaan tidak pernah jadi perintah menggambar.
        guard !lowered.hasSuffix("?") else { return nil }
        guard !questionOpeners.contains(where: { lowered.hasPrefix($0) }) else { return nil }

        guard let prefix = prefixes.first(where: { lowered.hasPrefix($0) }) else { return nil }
        let rest = trimmed.dropFirst(prefix.count)
        // Awalan harus kata utuh: "drawing a UI" dan "gambarnya bagus"
        // bukan ajakan, walau huruf-huruf depannya cocok.
        guard rest.first?.isWhitespace ?? true else { return nil }
        let concept = rest.trimmingCharacters(in: .whitespacesAndNewlines)
        // "draw a" tanpa apa-apa sesudahnya tidak punya yang bisa digambar.
        guard concept.count >= 3 else { return nil }
        return concept
    }
}

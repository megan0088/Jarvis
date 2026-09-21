//
//  ContextBudget.swift
//  Apl
//
//  Berapa yang muat, dan berapa sisanya (spec E §4).
//
//  Model on-device punya ~4.096 token untuk SEGALANYA: instructions, riwayat,
//  isi berkas, dan jawabannya. Jatah berkas 1.600 token adalah sisa setelah
//  ketiganya — dengan margin yang sengaja ditinggalkan, karena perkiraan ini
//  dihitung dari jumlah karakter dan tokenizer sebenarnya bisa meleset.
//

import Foundation

enum ContextBudget {

    static let limit = 1_600
    static let charactersPerToken = 3.5

    static func tokens(forCharacters count: Int) -> Int {
        Int((Double(count) / charactersPerToken).rounded(.up))
    }

    static func tokens(for file: WorkspaceFile) -> Int {
        tokens(forCharacters: file.byteCount)
    }

    static func used(_ attached: [WorkspaceFile]) -> Int {
        attached.reduce(0) { $0 + tokens(for: $1) }
    }

    static func remaining(after attached: [WorkspaceFile]) -> Int {
        max(0, limit - used(attached))
    }

    static func canAdd(_ file: WorkspaceFile, to attached: [WorkspaceFile]) -> Bool {
        tokens(for: file) <= remaining(after: attached)
    }
}

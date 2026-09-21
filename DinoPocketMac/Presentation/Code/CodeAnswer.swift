//
//  CodeAnswer.swift
//  Apl
//
//  Memeriksa jawaban model sebelum ia menyentuh berkas siapa pun (spec E §6 #3).
//
//  Model on-device kadang berhenti di tengah atau menjawab dengan potongan
//  alih-alih berkas utuh. Yang berbahaya bukan jawaban yang salah — itu bisa
//  dibaca dan diabaikan — melainkan jawaban setengah jadi yang terlanjur
//  ditulis ke berkas yang sedang jalan.
//

import Foundation

enum CodeAnswer {

    enum Rejection: Error, Equatable {
        case noCodeBlock
        case manyCodeBlocks
        case empty
        case sizeOutOfBand
    }

    static let minRatio = 0.5
    static let maxRatio = 2.0

    static func fileContents(from answer: String,
                             originalCharacters: Int) -> Result<String, Rejection> {
        let blocks = MarkdownBlocks.split(answer).compactMap { block -> String? in
            if case .code(_, let code, _) = block { return code }
            return nil
        }
        guard !blocks.isEmpty else { return .failure(.noCodeBlock) }
        guard blocks.count == 1 else { return .failure(.manyCodeBlocks) }

        let contents = blocks[0].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !contents.isEmpty else { return .failure(.empty) }

        guard originalCharacters > 0 else { return .success(contents) }
        let ratio = Double(contents.count) / Double(originalCharacters)
        guard ratio >= minRatio, ratio <= maxRatio else { return .failure(.sizeOutOfBand) }
        return .success(contents)
    }
}

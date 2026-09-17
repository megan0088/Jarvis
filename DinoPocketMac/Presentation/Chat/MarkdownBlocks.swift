//
//  MarkdownBlocks.swift
//  Apl
//
//  Memisahkan jawaban asisten menjadi teks dan blok kode berpagar (```).
//
//  `AttributedString(markdown:)` hanya dipakai untuk markup inline (tebal,
//  kode inline); blok kode butuh tampilannya sendiri. Pemisahan dibuat
//  toleran karena teks datang sepotong-sepotong: pagar yang belum ditutup
//  tetap menjadi blok kode sampai penutupnya tiba (spec B §9).
//

import Foundation

enum MarkdownBlock: Equatable {
    case text(String)
    case code(language: String?, code: String, isClosed: Bool)
}

enum MarkdownBlocks {

    static func split(_ source: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var textLines: [Substring] = []
        var codeLines: [Substring] = []
        var language: String?
        var inCode = false

        func flushText() {
            let text = textLines.joined(separator: "\n").trimmingCharacters(in: .newlines)
            if !text.isEmpty { blocks.append(.text(text)) }
            textLines.removeAll()
        }

        for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                if inCode {
                    blocks.append(.code(language: language, code: codeLines.joined(separator: "\n"),
                                        isClosed: true))
                    codeLines.removeAll()
                    language = nil
                    inCode = false
                } else {
                    flushText()
                    let tag = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
                    language = tag.isEmpty ? nil : tag
                    inCode = true
                }
            } else if inCode {
                codeLines.append(line)
            } else {
                textLines.append(line)
            }
        }

        if inCode {
            blocks.append(.code(language: language, code: codeLines.joined(separator: "\n"), isClosed: false))
        } else {
            flushText()
        }
        return blocks
    }
}

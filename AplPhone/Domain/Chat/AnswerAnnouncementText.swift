//
//  AnswerAnnouncementText.swift
//  Apl (iPhone)
//
//  Kalimat yang dikabarkan ke VoiceOver saat jawaban sudah utuh (spec H §6).
//
//  Pemicunya BUKAN "streaming selesai": jawaban reminder tidak pernah
//  streaming, jadi pemicu semacam itu melewatkan jawaban yang paling sering.
//

import Foundation

enum AnswerAnnouncementText {

    static let failureNotice = "Apl couldn't finish this reply."

    /// Nilainya `nil` selama menjawab; perubahan dari `nil` ke teks itulah
    /// tanda "jawaban sudah utuh", sekali saja, apa pun jalurnya.
    static func text(messages: [ChatMessage], isStreaming: Bool) -> String? {
        guard !isStreaming, let last = messages.last, last.role == .assistant else { return nil }
        if last.status == .failed { return failureNotice }
        return last.text.isEmpty ? nil : last.text
    }
}

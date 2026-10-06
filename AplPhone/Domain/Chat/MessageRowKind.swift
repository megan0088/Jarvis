//
//  MessageRowKind.swift
//  Apl (iPhone)
//
//  Bentuk satu baris percakapan, dipilih dari data pesan — peran, status,
//  lampiran — tidak pernah dari bunyi teksnya (spec H §4.1).
//

import Foundation

enum MessageRowKind: Equatable {
    case user
    case assistant(stopped: Bool)
    case reminderConfirmation(Reminder.ID)
    case failed
    /// Jawaban yang potongan pertamanya belum datang.
    case placeholder

    static func of(_ message: ChatMessage) -> MessageRowKind {
        if message.role == .user { return .user }
        if message.status == .failed { return .failed }
        if case .reminder(let id)? = message.attachment { return .reminderConfirmation(id) }
        if message.text.isEmpty { return .placeholder }
        return .assistant(stopped: message.status == .stopped)
    }
}

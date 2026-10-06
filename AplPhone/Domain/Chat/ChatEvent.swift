// Kembaran dari DinoPocketMac/Presentation/ViewModels/ChatEvent.swift @ 580b3e9 (spec H §3.1).
// Perbaikan di satu sisi tidak sampai ke sisi lain — periksa keduanya.
//
//  ChatEvent.swift
//  Apl
//
//  Kejadian di percakapan yang membuat karakter bereaksi sesaat (spec B §6).
//  ChatStore hanya mencatatnya; memilih ekspresi urusan CharacterMoodResolver.
//

import Foundation

struct ChatEvent: Equatable, Sendable {

    enum Kind: Equatable, Sendable {
        case reminderCreated(Reminder.ID)
        case failed
    }

    let kind: Kind
    let at: Date
}

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

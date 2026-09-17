//
//  ConversationCommands.swift
//  Apl
//
//  Menu bar Conversation › Clear Conversation… (spec B §4). Satu percakapan
//  berkelanjutan butuh jalan untuk mulai dari awal.
//

import SwiftUI

extension FocusedValues {
    /// Diisi jendela utama yang sedang aktif; nil saat percakapan kosong.
    @Entry var clearConversation: (() -> Void)?
}

struct ConversationCommands: Commands {
    @FocusedValue(\.clearConversation) private var clearConversation

    var body: some Commands {
        CommandMenu("Conversation") {
            Button("Clear Conversation…") {
                clearConversation?()
            }
            .keyboardShortcut("k", modifiers: .command)
            .disabled(clearConversation == nil)
        }
    }
}

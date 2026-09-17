//
//  ConversationCommands.swift
//  Apl
//
//  Menu bar Conversation › Clear Conversation… (spec B §4). Satu percakapan
//  berkelanjutan butuh jalan untuk mulai dari awal.
//

import SwiftUI

extension FocusedValues {
    /// Membuka konfirmasi Clear Conversation di jendela utama yang sedang
    /// aktif; nil saat percakapan kosong.
    ///
    /// Binding, bukan closure: closure tidak bisa dibandingkan, sehingga
    /// SwiftUI menganggap nilainya berubah di setiap render.
    @Entry var clearConversationRequest: Binding<Bool>?
}

struct ConversationCommands: Commands {
    @FocusedValue(\.clearConversationRequest) private var clearConversationRequest

    var body: some Commands {
        CommandMenu("Conversation") {
            Button("Clear Conversation…") {
                if let request = clearConversationRequest {
                    request.wrappedValue = true
                }
            }
            .keyboardShortcut("k", modifiers: .command)
            .disabled(clearConversationRequest == nil)
        }
    }
}

//
//  ComposerState.swift
//  Apl
//
//  Keadaan kolom tulis, diturunkan dari availability dan streaming (spec B §9).
//

import Foundation

enum ComposerState: Equatable {
    case ready
    case streaming
    /// Model sedang diunduh, atau availability belum selesai dicek.
    case preparing
    case unavailable(String)

    static func current(availability: BrainAvailability?, isStreaming: Bool) -> ComposerState {
        if isStreaming { return .streaming }
        switch availability {
        case .ready?:
            return .ready
        case .needsSetup?, nil:
            return .preparing
        case .unavailable(let reason)?:
            return .unavailable(reason)
        }
    }

    /// Saat Apple Intelligence mati, composer TETAP terbuka: reminder dibuat
    /// tanpa AI, dan pesan lain dijawab ChatStore dengan pemberitahuan.
    /// Selama streaming, pengguna boleh mengetik pesan berikutnya.
    var acceptsInput: Bool {
        self != .preparing
    }

    var placeholder: String {
        switch self {
        case .ready, .streaming: "Message Apl…"
        case .preparing: "Getting ready…"
        case .unavailable: "Ask Apl for a reminder…"
        }
    }
}

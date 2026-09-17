//
//  AplError.swift
//  SharedCore
//
//  Kesalahan domain yang perlu dibedakan oleh UI.
//
//  Sengaja sempit: hanya kondisi yang menghasilkan perilaku UI berbeda yang
//  layak jadi case. Error yang cuma diteruskan sebagai teks tidak perlu tipe
//  sendiri — itu menambah cabang tanpa menambah keputusan.
//

import Foundation

enum AplError: Error, Equatable, LocalizedError {

    /// Tidak ada otak yang siap. UI menampilkan `AIUnavailableBanner`.
    case noBrainAvailable(reason: String)

    /// Jendela konteks penuh dan pemangkasan pun tidak menolong.
    case conversationTooLong

    /// Permintaan diblokir guardrail model.
    case requestBlocked

    var errorDescription: String? {
        switch self {
        case .noBrainAvailable(let reason):
            reason
        case .conversationTooLong:
            "This conversation got too long for the on-device model."
        case .requestBlocked:
            "That request was blocked before it reached the model."
        }
    }
}

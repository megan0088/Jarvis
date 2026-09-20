//
//  AnswerAnnouncement.swift
//  Apl
//
//  Memberitahu VoiceOver bahwa jawaban sudah ada.
//
//  Pengguna VoiceOver tidak melihat teks yang tumbuh; tanpa pengumuman, satu-
//  satunya tanda bahwa Apl sudah menjawab adalah menelusuri sendiri ke bawah
//  dan menemukannya. Jendela utama diam seperti itu sampai 2026-09-20, dan
//  ketahuan hanya karena pemilik produk menyalakan VoiceOver dan mendengarnya.
//
//  Pemicunya BUKAN "streaming selesai". Jawaban reminder tidak pernah
//  streaming — `ChatStore` menjawabnya secara lokal tanpa memanggil model —
//  jadi pemicu semacam itu melewatkan justru jawaban yang paling sering muncul.
//

import AppKit
import SwiftUI

enum AnswerAnnouncement {

    /// Jawaban yang gagal tetap dikabarkan: diam saat gagal lebih buruk
    /// daripada kabar buruk.
    static let failureNotice = "Apl couldn't finish this reply."

    /// Kalimat yang layak diumumkan, atau `nil` bila belum ada yang baru.
    ///
    /// Nilainya sengaja berubah jadi `nil` selama menjawab: perubahan dari
    /// `nil` ke teks itulah yang menjadi tanda "jawaban sudah utuh", sekali
    /// saja, apa pun jalur yang menghasilkannya.
    static func text(messages: [ChatMessage], isStreaming: Bool) -> String? {
        guard !isStreaming, let last = messages.last, last.role == .assistant else { return nil }
        if last.status == .failed { return failureNotice }
        return last.text.isEmpty ? nil : last.text
    }

    static func post(_ text: String, priority: NSAccessibilityPriorityLevel) {
        NSAccessibility.post(element: NSApp as Any,
                             notification: .announcementRequested,
                             userInfo: [.announcement: text, .priority: priority.rawValue])
    }
}

extension View {
    /// Mengumumkan jawaban Apl begitu ia utuh.
    ///
    /// - Parameter priority: `.high` untuk bubble yang akan menghilang,
    ///   `.medium` untuk jendela utama yang tetap bisa ditelusuri ulang.
    func announcesAnswers(from chat: ChatStore,
                          priority: NSAccessibilityPriorityLevel) -> some View {
        onChange(of: AnswerAnnouncement.text(messages: chat.messages,
                                             isStreaming: chat.isStreaming)) { _, announcement in
            // Hanya saat Apl memang di depan: mengumumkan jawaban sementara
            // pengguna sudah pindah ke app lain berarti berbicara di atas
            // pekerjaan orang.
            guard let announcement, NSApp.isActive else { return }
            AnswerAnnouncement.post(announcement, priority: priority)
        }
    }
}

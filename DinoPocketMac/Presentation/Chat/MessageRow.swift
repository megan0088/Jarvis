//
//  MessageRow.swift
//  Apl
//
//  Satu baris percakapan. Bentuknya dipilih dari data pesan — peran, status,
//  lampiran — tidak pernah dari bunyi teksnya.
//

import SwiftUI

enum MessageRowKind: Equatable {
    case user
    case assistant(stopped: Bool)
    case reminderConfirmation(Reminder.ID)
    case picture(name: String, concept: String)
    case failed
}

struct MessageRow: View {
    let message: ChatMessage
    let reminders: ReminderListViewModel
    /// `nil` di tempat yang tidak menampilkan gambar (bubble ⌥Space, sisi
    /// Code): gambar hanya hidup di jendela utama (spec G §2 #3).
    var imageStore: ImageStore?
    /// Hanya jawaban gagal yang TERAKHIR yang bisa diulang (lihat `ChatStore.retry`).
    let canRetry: Bool
    let onRetry: () -> Void

    nonisolated static func kind(of message: ChatMessage) -> MessageRowKind {
        if message.role == .user { return .user }
        if message.status == .failed { return .failed }
        if case .reminder(let id)? = message.attachment { return .reminderConfirmation(id) }
        if case .picture(let name, let concept)? = message.attachment {
            return .picture(name: name, concept: concept)
        }
        return .assistant(stopped: message.status == .stopped)
    }

    var body: some View {
        switch Self.kind(of: message) {
        case .user:
            UserBubble(text: message.text)
        case .assistant(let stopped):
            // Placeholder kosong selama menunggu potongan pertama: yang tampil
            // TypingIndicator, bukan baris kosong.
            if !message.text.isEmpty {
                AssistantMessage(text: message.text, isStopped: stopped)
            }
        case .reminderConfirmation(let id):
            VStack(alignment: .leading, spacing: Spacing.sm) {
                AssistantMessage(text: message.text)
                ReminderChip(state: reminders.chipState(for: id, at: .now),
                             onUndo: { Task { await reminders.cancel(id) } })
            }
        case .picture(let name, let concept):
            if let imageStore {
                PictureBubble(name: name, concept: concept, store: imageStore)
            } else {
                AssistantMessage(text: AnswerAnnouncement.pictureLabel(concept: concept))
            }
        case .failed:
            FailedMessage(text: message.text, onRetry: canRetry ? onRetry : nil)
        }
    }
}

#Preview("Rows · Light") {
    let reminders = ReminderListViewModel.preview()
    let imageStore = ImageStore(folder: FileManager.default.temporaryDirectory.appendingPathComponent("apl.preview.images", isDirectory: true))
    VStack(spacing: Spacing.lg) {
        ForEach(PreviewData.messages) { message in
            MessageRow(message: message, reminders: reminders, imageStore: imageStore,
                       canRetry: false, onRetry: {})
        }
        MessageRow(message: ChatMessage(role: .assistant, text: "", status: .failed),
                   reminders: reminders, canRetry: true, onRetry: {})
    }
    .padding(Spacing.xl)
    .frame(width: 640)
}

#Preview("Rows · Dark") {
    let reminders = ReminderListViewModel.preview()
    let imageStore = ImageStore(folder: FileManager.default.temporaryDirectory.appendingPathComponent("apl.preview.images", isDirectory: true))
    VStack(spacing: Spacing.lg) {
        ForEach(PreviewData.messages) { message in
            MessageRow(message: message, reminders: reminders, imageStore: imageStore,
                       canRetry: false, onRetry: {})
        }
    }
    .padding(Spacing.xl)
    .frame(width: 640)
    .preferredColorScheme(.dark)
}

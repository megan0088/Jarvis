//
//  PhoneMessageRow.swift
//  Apl (iPhone)
//
//  Satu baris percakapan. Bentuknya diputuskan `MessageRowKind`; view ini
//  hanya merender hasilnya.
//

import SwiftUI

struct PhoneMessageRow: View {
    let message: ChatMessage
    let reminders: ReminderListViewModel
    /// Hanya jawaban gagal yang TERAKHIR yang bisa diulang (lihat `ChatStore.retry`).
    let canRetry: Bool
    let onRetry: () -> Void

    var body: some View {
        switch MessageRowKind.of(message) {
        case .user:
            PhoneUserBubble(text: message.text)
        case .assistant(let stopped):
            PhoneAssistantMessage(text: message.text, isStopped: stopped)
        case .reminderConfirmation(let id):
            VStack(alignment: .leading, spacing: Spacing.sm) {
                PhoneAssistantMessage(text: message.text)
                PhoneReminderChip(state: reminders.chipState(for: id, at: .now),
                                  onUndo: { Task { await reminders.cancel(id) } })
            }
        case .failed:
            PhoneFailedMessage(text: message.text, onRetry: canRetry ? onRetry : nil)
        case .placeholder:
            PhoneTypingIndicator()
        }
    }
}

#Preview("Rows") {
    let reminders = ReminderListViewModel.preview()
    ScrollView {
        VStack(spacing: Spacing.lg) {
            ForEach(PreviewData.messages) { message in
                PhoneMessageRow(message: message, reminders: reminders, canRetry: false, onRetry: {})
            }
            PhoneMessageRow(message: ChatMessage(role: .assistant, text: "", status: .failed),
                            reminders: reminders, canRetry: true, onRetry: {})
            PhoneMessageRow(message: ChatMessage(role: .assistant, text: ""),
                            reminders: reminders, canRetry: false, onRetry: {})
        }
        .padding(Spacing.lg)
    }
}

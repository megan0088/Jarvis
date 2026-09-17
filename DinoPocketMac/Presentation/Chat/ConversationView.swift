//
//  ConversationView.swift
//  Apl
//
//  Kolom kanan jendela utama: header tanggal, daftar pesan yang mengikuti
//  pesan terbaru, banner AI, dan composer (spec B §5–§6).
//

import SwiftUI

struct ConversationView: View {
    let chat: ChatStore
    let reminders: ReminderListViewModel
    let availability: BrainAvailability?
    var showsDateHeader = true
    let onOpenIntelligenceSettings: () -> Void

    @State private var draft = ""

    private var composerState: ComposerState {
        .current(availability: availability, isStreaming: chat.isStreaming)
    }

    /// Selama potongan pertama belum datang, placeholder kosong digantikan titik-titik.
    private var showsTypingIndicator: Bool {
        chat.isStreaming && (chat.messages.last?.text.isEmpty ?? true)
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsDateHeader {
                Text(Self.dayLabel(for: chat.messages.last?.date ?? .now, now: .now))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }

            messageList

            VStack(spacing: Spacing.sm) {
                if let availability, availability != .ready {
                    AIUnavailableBanner(availability: availability,
                                        onOpenSettings: onOpenIntelligenceSettings)
                }
                Composer(draft: $draft, state: composerState,
                         onSend: { send() },
                         onStop: { chat.stopStreaming() })
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.lg)
        }
        // Esc menghentikan jawaban walau fokus tidak di composer.
        .onExitCommand { chat.stopStreaming() }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                    ForEach(chat.messages) { message in
                        MessageRow(message: message,
                                   reminders: reminders,
                                   canRetry: !chat.isStreaming && message.id == chat.messages.last?.id,
                                   onRetry: { Task { await chat.retry(message.id) } })
                            .id(message.id)
                    }
                    if showsTypingIndicator {
                        TypingIndicator()
                    }
                    if let notice = chat.noticeMessage {
                        Label(notice, systemImage: "info.circle")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .defaultScrollAnchor(.bottom)
            .defaultScrollAnchor(.bottom, for: .sizeChanges)
            .onChange(of: chat.messages.last?.id) { _, id in
                guard let id else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(id, anchor: .bottom)
                }
            }
            .overlay {
                if chat.messages.isEmpty && !chat.isStreaming {
                    ContentUnavailableView {
                        Label("Say hi to Apl", systemImage: "bubble.left.and.bubble.right")
                    } description: {
                        Text("Ask anything, or try “Remind me to stretch at 3 PM”.")
                    }
                }
            }
        }
    }

    private func send() {
        let text = draft
        draft = ""
        Task { await chat.send(text) }
    }

    /// "Today", "Yesterday", atau tanggal pesan terakhir.
    nonisolated static func dayLabel(for date: Date, now: Date, calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        return date.formatted(.dateTime.month(.wide).day())
    }
}

#Preview("Conversation · Light") {
    ConversationView(chat: .preview(), reminders: .preview(), availability: .ready,
                     onOpenIntelligenceSettings: {})
        .frame(width: 680, height: 620)
}

#Preview("Conversation · AI off · Dark") {
    ConversationView(chat: .preview(), reminders: .preview(),
                     availability: .unavailable("Enable Apple Intelligence in System Settings."),
                     onOpenIntelligenceSettings: {})
        .frame(width: 680, height: 620)
        .preferredColorScheme(.dark)
}

#Preview("Conversation · Empty, thinking · Dark") {
    ConversationView(chat: .preview([ChatMessage(role: .user, text: "Hello!"),
                                     ChatMessage(role: .assistant, text: "")], isStreaming: true),
                     reminders: .preview(), availability: .ready,
                     onOpenIntelligenceSettings: {})
        .frame(width: 680, height: 620)
        .preferredColorScheme(.dark)
}

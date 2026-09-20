//
//  QuickAskBubble.swift
//  Apl
//
//  Isi bubble: satu giliran dan satu kolom tulis (spec C1 §4).
//
//  Tidak ada riwayat di sini dan tidak ada penyimpanan sendiri. Semua yang
//  tampil dipotong dari `ChatStore` yang sama dengan jendela utama, jadi apa
//  pun yang ditanyakan lewat robot langsung ada di percakapan utama.
//

import AppKit
import SwiftUI

struct QuickAskBubble: View {
    let chat: ChatStore
    let reminders: ReminderListViewModel
    let onOpenMainWindow: () -> Void
    let onOpenIntelligenceSettings: () -> Void
    /// Dipanggil setiap kali tinggi isi berubah, supaya panel ikut menyesuaikan.
    let onHeightChange: (CGFloat) -> Void
    /// Panel yang meminta fokus setelah ia benar-benar menjadi key; lihat
    /// `QuickAskPanelController.handOverToSwiftUI()`.
    var focus = ComposerFocus()

    @State private var draft = ""
    @State private var availability: BrainAvailability?
    /// Tinggi jawaban yang sebenarnya, sebelum dibatasi.
    @State private var answerHeight: CGFloat = 0

    private var turn: QuickAskTurn? { QuickAskTurn.latest(in: chat.messages) }

    private var composerState: ComposerState {
        .current(availability: availability, isStreaming: chat.isStreaming)
    }

    /// Selama potongan pertama belum datang, yang tampil titik-titik.
    private var showsTypingIndicator: Bool {
        chat.isStreaming && (chat.messages.last?.text.isEmpty ?? true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let turn {
                if let asked = turn.question {
                    question(asked)
                }
                answerArea(turn)
                if !chat.isStreaming, turn.answer != nil {
                    Button("Open in Apl", action: onOpenMainWindow)
                        .buttonStyle(.link)
                        .font(.callout)
                }
            }
            if let availability, availability != .ready {
                unavailableLine
            }
            Composer(draft: $draft, state: composerState,
                     onSend: { send() },
                     onStop: { chat.stopStreaming() },
                     focus: focus)
                // Menolak dikompres. Area jawaban di atasnya bertinggi kaku,
                // jadi tanpa ini composer-lah satu-satunya yang lentur:
                // baris kedua dari ⇧Return terpotong alih-alih membuat bubble
                // ikut tumbuh.
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .frame(width: BubblePlacement.width, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
            .strokeBorder(.separator))
        .background(heightReporter)
        .task { availability = await chat.availability() }
        // Bubble akan menghilang, jadi pengumumannya boleh memotong.
        .announcesAnswers(from: chat, priority: .high)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Apl quick ask")
    }

    private func question(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Penanda pembicara, sama seperti di jendela utama: teks tanpa
            // penanda berarti Apl.
            .accessibilityLabel("You said: \(text)")
    }

    /// `ScrollView` mengambil SELURUH tinggi yang ditawarkan, jadi tingginya
    /// harus dipatok dari isi — kalau tidak, bubble selalu setinggi batas
    /// maksimum dan menyisakan rongga besar di atas composer.
    @ViewBuilder
    private func answerArea(_ turn: QuickAskTurn) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if let answer = turn.answer, !answer.text.isEmpty || answer.status == .failed {
                    MessageRow(message: answer,
                               reminders: reminders,
                               canRetry: !chat.isStreaming,
                               onRetry: { Task { await chat.retry(answer.id) } })
                } else if showsTypingIndicator {
                    TypingIndicator()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GeometryReader { proxy in
                Color.clear
                    .onChange(of: proxy.size.height, initial: true) { _, height in
                        answerHeight = height
                    }
            })
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: min(answerHeight, BubblePlacement.answerMaxHeight))
    }

    /// Versi satu baris dari `AIUnavailableBanner`: di ruang 360pt, kartu penuh
    /// mendorong composer keluar layar.
    private var unavailableLine: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "apple.intelligence")
                .foregroundStyle(AppColor.statusWarning)
                .accessibilityHidden(true)
            Text("Chat needs Apple Intelligence. Reminders still work.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("Settings", action: onOpenIntelligenceSettings)
                .buttonStyle(.link)
                .font(.caption)
        }
    }

    private var heightReporter: some View {
        GeometryReader { proxy in
            Color.clear
                .onChange(of: proxy.size.height, initial: true) { _, height in
                    onHeightChange(height)
                }
        }
    }

    private func send() {
        let text = draft
        draft = ""
        Task { await chat.send(text) }
    }
}

#Preview("Bubble · Light") {
    QuickAskBubble(chat: .preview(), reminders: .preview(),
                   onOpenMainWindow: {}, onOpenIntelligenceSettings: {},
                   onHeightChange: { _ in })
        .padding(Spacing.xl)
}

#Preview("Bubble · Menjawab · Dark") {
    QuickAskBubble(chat: .preview([ChatMessage(role: .user, text: "What's next today?"),
                                   ChatMessage(role: .assistant, text: "")], isStreaming: true),
                   reminders: .preview(),
                   onOpenMainWindow: {}, onOpenIntelligenceSettings: {},
                   onHeightChange: { _ in })
        .padding(Spacing.xl)
        .preferredColorScheme(.dark)
}

#Preview("Bubble · Kosong · Dark") {
    QuickAskBubble(chat: .preview([]), reminders: .preview(),
                   onOpenMainWindow: {}, onOpenIntelligenceSettings: {},
                   onHeightChange: { _ in })
        .padding(Spacing.xl)
        .preferredColorScheme(.dark)
}

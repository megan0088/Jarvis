//
//  PhoneMessageViews.swift
//  Apl (iPhone)
//
//  Potongan tampilan percakapan (spec H §4.1): bubble pengguna, teks Apl
//  tanpa bubble, jawaban gagal, dan indikator mengetik.
//

import SwiftUI

/// Pesan pengguna: bubble beraksen di kanan, menyisakan tepi kiri.
struct PhoneUserBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .textSelection(.enabled)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(PhoneColor.userBubble, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .padding(.leading, 48)
            .frame(maxWidth: .infinity, alignment: .trailing)
            // VoiceOver membacakan isi tanpa menyebut siapa yang bicara.
            // Penanda hanya di sisi pengguna; teks tanpa penanda berarti Apl.
            .accessibilityLabel("You said: \(text)")
    }
}

/// Jawaban Apl: teks polos menyatu dengan layar, Markdown.
struct PhoneAssistantMessage: View {
    let text: String
    var isStopped = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(Array(MarkdownBlocks.split(text).enumerated()), id: \.offset) { _, block in
                switch block {
                case .text(let paragraph):
                    Text(Self.attributed(paragraph))
                        .fixedSize(horizontal: false, vertical: true)
                case .code(let language, let code, _):
                    PhoneCodeBlock(language: language, code: code)
                }
            }
            if isStopped {
                Label("Stopped", systemImage: "stop.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Markup inline saja; spasi dan baris baru dipertahankan. Markdown yang
    /// belum lengkap saat streaming tampil apa adanya.
    static func attributed(_ markdown: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: markdown, options: options)) ?? AttributedString(markdown)
    }
}

private struct PhoneCodeBlock: View {
    let language: String?
    let code: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if let language {
                Text(language)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(AppFont.code)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PhoneColor.controlFill, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
    }
}

/// Jawaban yang gagal. Teks yang sempat tertulis tetap tampil; Retry hanya
/// ada untuk jawaban terakhir.
struct PhoneFailedMessage: View {
    let text: String
    let onRetry: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if !text.isEmpty {
                PhoneAssistantMessage(text: text)
            }
            HStack(spacing: Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(PhoneColor.statusWarning)
                    .accessibilityHidden(true)
                Text(AnswerAnnouncementText.failureNotice)
                    .foregroundStyle(.secondary)
                if let onRetry {
                    Button("Retry", action: onRetry)
                        .buttonStyle(.borderless)
                }
            }
            .font(.callout)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Tiga titik bergantian menyala selama jawaban belum mulai tertulis.
struct PhoneTypingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.35, paused: reduceMotion)) { context in
            let lit = reduceMotion ? -1 : Int(context.date.timeIntervalSinceReferenceDate / 0.35) % 3
            HStack(spacing: Spacing.xs) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(.secondary)
                        .frame(width: 6, height: 6)
                        .opacity(index == lit ? 1 : 0.35)
                }
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement()
        .accessibilityLabel("Apl is typing")
    }
}

#Preview("Messages") {
    VStack(spacing: Spacing.lg) {
        PhoneUserBubble(text: "Any tips to stay focused this afternoon?")
        PhoneAssistantMessage(text: PreviewData.messages[1].text)
        PhoneAssistantMessage(text: "Here's the first part of", isStopped: true)
        PhoneFailedMessage(text: "", onRetry: {})
        PhoneTypingIndicator()
    }
    .padding(Spacing.lg)
}

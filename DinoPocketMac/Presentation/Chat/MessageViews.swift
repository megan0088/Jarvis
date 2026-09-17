//
//  MessageViews.swift
//  Apl
//
//  Potongan tampilan percakapan (spec B §5–§6): bubble pengguna, teks
//  asisten tanpa bubble, jawaban gagal, dan indikator mengetik.
//

import SwiftUI

/// Pesan pengguna: bubble beraksen di kanan, maksimal 420pt.
struct UserBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .textSelection(.enabled)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(AppColor.userBubble, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .frame(maxWidth: 420, alignment: .trailing)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

/// Jawaban asisten: teks polos menyatu dengan jendela, maksimal 460pt, Markdown.
struct AssistantMessage: View {
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
                    CodeBlock(language: language, code: code)
                }
            }
            if isStopped {
                Label("Stopped", systemImage: "stop.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .textSelection(.enabled)
        .frame(maxWidth: 460, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Markup inline saja; spasi dan baris baru dipertahankan sehingga list
    /// tetap terbaca. Markdown yang belum lengkap saat streaming tampil apa adanya.
    static func attributed(_ markdown: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: markdown, options: options)) ?? AttributedString(markdown)
    }
}

private struct CodeBlock: View {
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
        .background(AppColor.controlFill, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
    }
}

/// Jawaban yang gagal (spec B §9). Teks yang sempat tertulis tetap tampil;
/// tombol Retry hanya ada untuk jawaban terakhir.
struct FailedMessage: View {
    let text: String
    let onRetry: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if !text.isEmpty {
                AssistantMessage(text: text)
            }
            HStack(spacing: Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppColor.statusWarning)
                    .accessibilityHidden(true)
                Text("Apl couldn't finish this reply.")
                    .foregroundStyle(.secondary)
                if let onRetry {
                    Button("Retry", action: onRetry)
                        .buttonStyle(.link)
                }
            }
            .font(.callout)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Tiga titik bergantian menyala selama jawaban belum mulai tertulis.
struct TypingIndicator: View {
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

#Preview("Messages · Light") {
    VStack(spacing: Spacing.lg) {
        UserBubble(text: "Any tips to stay focused this afternoon?")
        AssistantMessage(text: PreviewData.messages[1].text)
        AssistantMessage(text: "Here's the first part of", isStopped: true)
        FailedMessage(text: "", onRetry: {})
        TypingIndicator()
    }
    .padding(Spacing.xl)
    .frame(width: 640)
}

#Preview("Messages · Dark") {
    VStack(spacing: Spacing.lg) {
        UserBubble(text: "Any tips to stay focused this afternoon?")
        AssistantMessage(text: PreviewData.messages[1].text)
        FailedMessage(text: "Half a reply", onRetry: {})
        TypingIndicator()
    }
    .padding(Spacing.xl)
    .frame(width: 640)
    .preferredColorScheme(.dark)
}

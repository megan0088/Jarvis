//
//  ConversationView.swift
//  Apl
//
//  Kolom kanan jendela utama: header tanggal, daftar pesan yang mengikuti
//  pesan terbaru, banner AI, dan composer (spec B §5–§6).
//

import AppKit
import ImagePlayground
import SwiftUI
import UniformTypeIdentifiers

struct ConversationView: View {
    let chat: ChatStore
    let reminders: ReminderListViewModel
    let availability: BrainAvailability?
    let imageStore: ImageStore
    let pictures: PictureSession
    /// Menu dinonaktifkan (bukan disembunyikan) saat Image Playground belum
    /// tersedia — kontrol yang lenyap tidak mengajarkan apa-apa (spec G §5).
    var pictureIsAvailable = true
    /// Dipanggil saat sheet selesai: URL sementara dari Apple, beserta konsep
    /// yang diminta. Penyalinan dan pemangkasannya milik `AplApp`.
    let onPictureCreated: (URL, String) -> Void
    var showsDateHeader = true
    let composerFocus: ComposerFocus
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
                         onStop: { chat.stopStreaming() },
                         focus: composerFocus,
                         picture: PictureMenuActions(
                            isEnabled: pictureIsAvailable,
                            describe: { pictures.start(PictureRequest(concept: "", sourceImage: nil)) },
                            usePhoto: { choosePhoto() }))
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.lg)
        }
        // Esc menghentikan jawaban walau fokus tidak di composer.
        .onExitCommand { chat.stopStreaming() }
        // Jendela ini tetap bisa ditelusuri ulang, jadi pengumumannya tidak
        // perlu memotong apa yang sedang dibacakan.
        .announcesAnswers(from: chat, priority: .medium)
        // Varian `concepts:` dipakai untuk KEDUA jalur: array kosong berarti
        // sheet terbuka tanpa konsep, dan itu persis yang diminta menu
        // "Describe an image…".
        .imagePlaygroundSheet(
            isPresented: Binding(get: { pictures.request != nil },
                                 set: { if !$0 { pictures.finish() } }),
            concepts: pictures.request.map { request in
                request.concept.isEmpty ? [] : [ImagePlaygroundConcept.text(request.concept)]
            } ?? [],
            sourceImage: pictures.request?.sourceImage
                .flatMap { NSImage(contentsOf: $0) }
                .map { Image(nsImage: $0) },
            onCompletion: { url in
                // `lastConcept`, bukan `request`: sheet boleh sudah menutup
                // dirinya (dan mengosongkan `request`) sebelum sampai di sini.
                pictures.finish()
                onPictureCreated(url, pictures.lastConcept)
            },
            onCancellation: { pictures.finish() }
        )
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                    ForEach(chat.messages) { message in
                        MessageRow(message: message,
                                   reminders: reminders,
                                   imageStore: imageStore,
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
            // Mengikuti pesan terakhir, termasuk saat ia memanjang (teks yang
            // sedang ditulis, label "Stopped", baris gagal). Anchor bawaan untuk
            // perubahan ukuran tidak cukup: LazyVStack tidak tetap di bawah.
            .onChange(of: chat.messages.last) { old, new in
                guard let new else { return }
                if old?.id == new.id {
                    proxy.scrollTo(new.id, anchor: .bottom)
                } else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(new.id, anchor: .bottom)
                    }
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

    /// Panel dibatasi ke gambar, jadi yang salah jenis tidak bisa dipilih sejak
    /// awal. Yang tidak terbaca sama sekali dikatakan sebelum sheet dibuka
    /// (spec G §5).
    private func choosePhoto() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        panel.prompt = "Use Photo"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard NSImage(contentsOf: url) != nil else {
            chat.appendAssistantNote("I couldn't read that image.")
            return
        }
        pictures.start(PictureRequest(concept: "", sourceImage: url))
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
                     imageStore: ImageStore(folder: FileManager.default.temporaryDirectory.appendingPathComponent("apl.preview.images", isDirectory: true)),
                     pictures: PictureSession(), onPictureCreated: { _, _ in },
                     composerFocus: ComposerFocus(),
                     onOpenIntelligenceSettings: {})
        .frame(width: 680, height: 620)
}

#Preview("Conversation · AI off · Dark") {
    ConversationView(chat: .preview(), reminders: .preview(),
                     availability: .unavailable("Enable Apple Intelligence in System Settings."),
                     imageStore: ImageStore(folder: FileManager.default.temporaryDirectory.appendingPathComponent("apl.preview.images", isDirectory: true)),
                     pictures: PictureSession(), onPictureCreated: { _, _ in },
                     composerFocus: ComposerFocus(),
                     onOpenIntelligenceSettings: {})
        .frame(width: 680, height: 620)
        .preferredColorScheme(.dark)
}

#Preview("Conversation · Empty, thinking · Dark") {
    ConversationView(chat: .preview([ChatMessage(role: .user, text: "Hello!"),
                                     ChatMessage(role: .assistant, text: "")], isStreaming: true),
                     reminders: .preview(), availability: .ready,
                     imageStore: ImageStore(folder: FileManager.default.temporaryDirectory.appendingPathComponent("apl.preview.images", isDirectory: true)),
                     pictures: PictureSession(), onPictureCreated: { _, _ in },
                     composerFocus: ComposerFocus(),
                     onOpenIntelligenceSettings: {})
        .frame(width: 680, height: 620)
        .preferredColorScheme(.dark)
}

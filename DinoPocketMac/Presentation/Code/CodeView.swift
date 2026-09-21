//
//  CodeView.swift
//  Apl
//
//  Ruang kedua di jendela utama (spec E §7).
//
//  Yang paling penting di layar ini bukan percakapannya, melainkan pengukur
//  token: ia satu-satunya yang memberi tahu kapan jawaban akan mulai memburuk.
//  Tanpa itu, penurunannya terjadi diam-diam.
//

import AppKit
import SwiftUI

struct CodeView: View {
    let workspace: CodeWorkspace
    let chat: ChatStore
    let writer: FileWriter
    let reminders: ReminderListViewModel

    @State private var attached: [WorkspaceFile] = []
    @State private var draft = ""
    @State private var availability: BrainAvailability?
    @State private var isPickingFile = false
    @State private var notice: String?
    @State private var lastReceipt: FileWriter.Receipt?

    var body: some View {
        VStack(spacing: 0) {
            if workspace.url == nil {
                empty
            } else {
                fileBar
                Divider()
                conversation
            }
        }
        .task { availability = await chat.availability() }
        .announcesAnswers(from: chat, priority: .medium)
    }

    private var empty: some View {
        ContentUnavailableView {
            Label("Pick a folder to talk about code", systemImage: "folder")
        } description: {
            Text("Apl only reads the files you point at, and only inside this folder.")
        } actions: {
            Button("Choose Folder…", action: chooseFolder)
        }
        // Mengisi ruang yang tersedia. Tanpa ini VStack induk memusatkan
        // isinya, dan pemilih Chat | Code ikut melompat dari atas ke tengah
        // setiap kali sisi Code masih kosong.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var fileBar: some View {
        HStack(spacing: Spacing.sm) {
            Button(action: chooseFolder) {
                Label(workspace.url?.lastPathComponent ?? "", systemImage: "folder")
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            .help("Change folder")

            ForEach(attached) { file in
                FileChip(file: file) { attached.removeAll { $0 == file } }
            }

            Button { isPickingFile = true } label: { Image(systemName: "plus") }
                .buttonStyle(.plain)
                .accessibilityLabel("Attach a file")
                .popover(isPresented: $isPickingFile) { filePicker }

            Spacer(minLength: Spacing.sm)

            Text("\(ContextBudget.used(attached)) / \(ContextBudget.limit) tokens")
                .font(.caption.monospacedDigit())
                .foregroundStyle(ContextBudget.remaining(after: attached) == 0
                                 ? AppColor.statusWarning : Color.secondary)
                .accessibilityLabel("\(ContextBudget.used(attached)) of \(ContextBudget.limit) tokens used")
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    private var filePicker: some View {
        List(workspace.files()) { file in
            Button {
                add(file)
            } label: {
                HStack {
                    Text(file.relativePath).lineLimit(1)
                    Spacer()
                    Text("\(ContextBudget.tokens(for: file))t").foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(attached.contains(file) || !ContextBudget.canAdd(file, to: attached))
        }
        .frame(width: 420, height: 320)
    }

    private var conversation: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                    ForEach(chat.messages) { message in
                        MessageRow(message: message, reminders: reminders,
                                   canRetry: false, onRetry: {})
                    }
                }
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .defaultScrollAnchor(.bottom)
            .defaultScrollAnchor(.bottom, for: .sizeChanges)
            .overlay {
                if chat.messages.isEmpty {
                    ContentUnavailableView {
                        Label("Attach a file and ask", systemImage: "curlybraces")
                    } description: {
                        Text("Apl answers about the files you attached, and can rewrite one of them.")
                    }
                }
            }

            if let lastReceipt {
                writeChip(lastReceipt)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.sm)
            }

            if let notice {
                Label(notice, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(AppColor.statusWarning)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.sm)
            }

            Composer(draft: $draft,
                     state: .current(availability: availability, isStreaming: chat.isStreaming),
                     onSend: send,
                     onStop: { chat.stopStreaming() })
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.lg)
        }
    }

    private func writeChip(_ receipt: FileWriter.Receipt) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "square.and.pencil")
                .foregroundStyle(AppColor.accent)
                .accessibilityHidden(true)
            Text(receipt.relativePath).fontWeight(.medium).lineLimit(1)
            Text("\(receipt.changedLines) lines changed").foregroundStyle(.secondary)
            Button("Undo") { undo(receipt) }
                .buttonStyle(.link)
        }
        .font(.callout)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 6)
        .background(AppColor.controlFill, in: Capsule())
        .accessibilityElement(children: .contain)
    }

    // MARK: - Tindakan

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        workspace.choose(folder)
        notice = workspace.bookmarkFailure
        attached = []
        lastReceipt = nil
    }

    private func add(_ file: WorkspaceFile) {
        guard ContextBudget.canAdd(file, to: attached) else {
            notice = "\(file.name) needs \(ContextBudget.tokens(for: file)) tokens; only \(ContextBudget.remaining(after: attached)) left."
            return
        }
        attached.append(file)
        notice = nil
        isPickingFile = false
    }

    private func send() {
        let question = draft
        draft = ""
        let files = attached.compactMap { file -> (WorkspaceFile, String)? in
            guard let contents = workspace.contents(of: file.relativePath) else { return nil }
            return (file, contents)
        }
        Task { await ask(question, with: files) }
    }

    /// Satu giliran sisi Code: berkas yang ditunjuk dan pertanyaannya masuk
    /// sebagai satu pesan, lalu jawabannya diperiksa sebelum menyentuh disk.
    private func ask(_ question: String, with files: [(WorkspaceFile, String)]) async {
        let attachments = files.map { file, contents in
            "File: \(file.relativePath)\n```\n\(contents)\n```"
        }.joined(separator: "\n\n")
        let prompt = attachments.isEmpty ? question : attachments + "\n\n" + question

        await chat.send(prompt)

        // Menulis hanya bila TEPAT SATU berkas ditunjuk: dengan dua berkas,
        // tidak ada cara aman menebak yang mana yang dimaksud jawaban itu.
        guard files.count == 1, let (file, contents) = files.first,
              let answer = chat.messages.last, answer.role == .assistant,
              answer.status != .failed else { return }

        switch CodeAnswer.fileContents(from: answer.text, originalCharacters: contents.count) {
        case .failure(let reason):
            notice = Self.explain(reason)
        case .success(let updated):
            applyWrite(updated, to: file)
        }
    }

    private func applyWrite(_ contents: String, to file: WorkspaceFile) {
        guard let root = workspace.url,
              let expected = try? FileWriter.snapshot(of: file.relativePath, in: root) else { return }
        do {
            let receipt = try writer.write(contents, to: file.relativePath,
                                           in: root, expecting: expected)
            lastReceipt = receipt
            notice = nil
        } catch FileWriter.Failure.staleOnDisk {
            notice = "\(file.name) changed on disk since you attached it. Nothing was written."
        } catch {
            notice = "Couldn't write \(file.name)."
        }
    }

    private func undo(_ receipt: FileWriter.Receipt) {
        guard let root = workspace.url else { return }
        do {
            try writer.undo(receipt, in: root)
            lastReceipt = nil
            notice = nil
        } catch FileWriter.Failure.staleOnDisk {
            notice = "\(receipt.relativePath) changed again after Apl wrote it. Nothing was undone."
        } catch {
            notice = "Couldn't undo \(receipt.relativePath)."
        }
    }

    private static func explain(_ reason: CodeAnswer.Rejection) -> String {
        switch reason {
        case .noCodeBlock: "No file was written — the answer has no code block."
        case .manyCodeBlocks: "No file was written — the answer has more than one code block."
        case .empty: "No file was written — the code block is empty."
        case .sizeOutOfBand: "No file was written — the answer looks truncated."
        }
    }
}

#Preview("Code · kosong") {
    CodeView(workspace: CodeWorkspace(bookmarks: UserDefaultsBookmarkStore(
                defaults: UserDefaults(suiteName: "apl.preview.code")!)),
             chat: .preview([]), writer: FileWriter(backups: FileManager.default.temporaryDirectory),
             reminders: .preview())
        .frame(width: 680, height: 620)
}

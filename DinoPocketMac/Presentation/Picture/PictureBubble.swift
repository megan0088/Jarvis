//
//  PictureBubble.swift
//  Apl
//
//  Gambar di dalam percakapan (spec G §3, §4).
//
//  Pesannya tidak berteks: gambarnya sudah ada di sana, dan menambahkan
//  "Here's your image" hanya menambah baris yang harus dibaca. Konsepnya
//  tampil sebagai keterangan kecil, dan itu pula yang dibacakan VoiceOver.
//

import AppKit
import SwiftUI

struct PictureBubble: View {
    let name: String
    let concept: String
    let store: ImageStore

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let url = store.url(for: name), let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 320, maxHeight: 320)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .strokeBorder(.separator))
                    .accessibilityLabel(AnswerAnnouncement.pictureLabel(concept: concept))
                HStack(spacing: Spacing.sm) {
                    // Jalur menu tidak membawa konsep; keterangan kosong
                    // hanya menyisakan celah di depan tombol Save.
                    if !concept.isEmpty {
                        Text(concept)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Button("Save") { save(url) }
                        .buttonStyle(.link)
                        .font(.caption)
                }
            } else {
                // Berkasnya sudah dipangkas atau dihapus pengguna. Satu baris
                // tenang, bukan ruang kosong dan bukan tanda seru.
                Label("Image no longer stored", systemImage: "photo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func save(_ url: URL) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Apl image \(Date.now.formatted(.dateTime.year().month().day())).png"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        try? FileManager.default.removeItem(at: destination)
        try? FileManager.default.copyItem(at: url, to: destination)
    }
}

#Preview("Gambar hilang") {
    PictureBubble(name: "tidak-ada.png", concept: "an orange cat",
                  store: ImageStore(folder: FileManager.default.temporaryDirectory
                      .appendingPathComponent("apl.preview.images", isDirectory: true)))
        .padding(Spacing.xl)
}

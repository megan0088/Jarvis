//
//  FileChip.swift
//  Apl
//
//  Satu berkas yang sedang ditunjuk, beserta cara melepasnya (spec E §7).
//

import SwiftUI

struct FileChip: View {
    let file: WorkspaceFile
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Text(file.name)
                .lineLimit(1)
            Text("\(ContextBudget.tokens(for: file))t")
                .foregroundStyle(.secondary)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(file.name)")
        }
        .font(.callout)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 4)
        .background(AppColor.controlFill, in: Capsule())
    }
}

#Preview("Chip berkas") {
    HStack {
        FileChip(file: WorkspaceFile(relativePath: "Sources/App/Main.swift", byteCount: 3_200),
                 onRemove: {})
        FileChip(file: WorkspaceFile(relativePath: "README.md", byteCount: 900), onRemove: {})
    }
    .padding()
}

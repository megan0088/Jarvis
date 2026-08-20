//
//  DashCard.swift
//  Jarvis
//
//  Organism: shared card container (title + SF Symbol header + content)
//  used by all dashboard cards.
//

#if os(macOS)
import SwiftUI

struct DashCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.medium))
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.card, in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    DashCard(title: "Contoh", systemImage: "target") {
        Text("Konten kartu di sini.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
    .frame(width: 300)
    .padding()
}
#endif

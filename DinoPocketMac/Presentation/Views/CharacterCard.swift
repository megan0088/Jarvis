//
//  CharacterCard.swift
//  Jarvis
//
//  Organism: Jarvis status + energy level from WellnessStore.
//

import SwiftUI

struct CharacterCard: View {
    @Bindable var store: WellnessStore

    var body: some View {
        DashCard(title: "Jarvis", systemImage: "face.smiling") {
            HStack(spacing: Spacing.md) {
                AvatarBadge(systemImage: "sparkles")
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(store.statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ProgressView(value: Double(store.energy), total: 100) {
                        Text("Energy").font(.caption)
                    }
                    .tint(AppColor.accent)
                }
            }
        }
    }
}

#Preview {
    CharacterCard(store: WellnessStore())
        .frame(width: 300)
        .padding()
}

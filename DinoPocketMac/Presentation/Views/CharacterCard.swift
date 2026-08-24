//
//  CharacterCard.swift
//  Jarvis
//
//  Organism: Jarvis status + energy level from WellnessStore.
//

import SwiftUI

struct CharacterCard: View {
    let wellness: WellnessViewModel

    var body: some View {
        DashCard(title: "Jarvis", systemImage: "face.smiling") {
            HStack(spacing: Spacing.md) {
                AvatarBadge(systemImage: "sparkles")
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(wellness.statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ProgressView(value: Double(wellness.energy), total: 100) {
                        Text("Energy").font(.caption)
                    }
                    .tint(AppColor.accent)
                }
            }
        }
    }
}

#Preview {
    CharacterCard(wellness: .preview)
        .frame(width: 300)
        .padding()
}

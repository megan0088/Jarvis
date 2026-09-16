//
//  ReminderRow.swift
//  Apl
//
//  Molecule: an icon chip + title/time + done/skip actions for one reminder.
//

import SwiftUI

struct ReminderRow: View {
    let icon: String
    let title: String
    let timeLabel: String
    var onDone: () -> Void
    var onSkip: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            RoundedRectangle(cornerRadius: 8)
                .fill(AppColor.accent.opacity(0.15))
                .frame(width: 30, height: 30)
                .overlay {
                    Image(systemName: icon)
                        .foregroundStyle(AppColor.accent)
                        .font(.system(size: 13, weight: .medium))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline)
                Text(timeLabel).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onDone) {
                Image(systemName: "checkmark.circle.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppColor.online)

            Button(action: onSkip) {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    VStack(spacing: Spacing.sm) {
        ReminderRow(icon: "drop.fill", title: "Drink water", timeLabel: "09.00", onDone: {}, onSkip: {})
        ReminderRow(icon: "figure.cooldown", title: "Stretch break", timeLabel: "09.45", onDone: {}, onSkip: {})
    }
    .padding()
    .frame(width: 300)
}

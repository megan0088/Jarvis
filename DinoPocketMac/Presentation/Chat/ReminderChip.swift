//
//  ReminderChip.swift
//  Apl
//
//  Chip di bawah konfirmasi reminder: bukti reminder itu ada, dan jalan
//  tercepat untuk membatalkannya (spec B §6).
//

import SwiftUI

struct ReminderChip: View {
    let state: ReminderChipState
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            switch state {
            case .scheduled(let title, let whenText):
                Image(systemName: "bell.fill")
                    .foregroundStyle(AppColor.accent)
                Text(title)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(whenText)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Button("Undo", action: onUndo)
                    .buttonStyle(.link)
            case .past:
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.secondary)
                Text("Reminder passed")
                    .foregroundStyle(.secondary)
            case .removed:
                Image(systemName: "bell.slash")
                    .foregroundStyle(.secondary)
                Text("Reminder removed")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.callout)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 6)
        .background(AppColor.controlFill, in: Capsule())
        .accessibilityElement(children: .contain)
    }
}

#Preview("Chip · Light") {
    VStack(alignment: .leading, spacing: Spacing.sm) {
        ReminderChip(state: .scheduled(title: "Stretch", whenText: "Today, 3:00 PM"), onUndo: {})
        ReminderChip(state: .past, onUndo: {})
        ReminderChip(state: .removed, onUndo: {})
    }
    .padding()
}

#Preview("Chip · Dark") {
    VStack(alignment: .leading, spacing: Spacing.sm) {
        ReminderChip(state: .scheduled(title: "Stretch", whenText: "Every day, 9:00 AM"), onUndo: {})
        ReminderChip(state: .removed, onUndo: {})
    }
    .padding()
    .preferredColorScheme(.dark)
}

//
//  PhoneReminderChip.swift
//  Apl (iPhone)
//
//  Chip di bawah konfirmasi reminder: bukti reminder itu ada, dan jalan
//  tercepat untuk membatalkannya (spec H §4.1).
//

import SwiftUI

struct PhoneReminderChip: View {
    let state: ReminderChipState
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            switch state {
            case .scheduled(let title, let whenText):
                Image(systemName: "bell.fill")
                    .foregroundStyle(PhoneColor.accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text(whenText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Button("Undo", action: onUndo)
                    .buttonStyle(.borderless)
            case .past:
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text("Reminder passed")
                    .foregroundStyle(.secondary)
            case .removed:
                Image(systemName: "bell.slash")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text("Reminder removed")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.callout)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(PhoneColor.controlFill, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

#Preview("Chip") {
    VStack(alignment: .leading, spacing: Spacing.sm) {
        PhoneReminderChip(state: .scheduled(title: "Stretch", whenText: "Today, 3:00 PM"), onUndo: {})
        PhoneReminderChip(state: .past, onUndo: {})
        PhoneReminderChip(state: .removed, onUndo: {})
    }
    .padding()
}

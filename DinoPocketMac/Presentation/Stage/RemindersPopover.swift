//
//  RemindersPopover.swift
//  Apl
//
//  "See all": semua reminder, dengan edit, batal, dan Undo (spec B §5).
//

import SwiftUI

struct RemindersPopover: View {
    let viewModel: ReminderListViewModel

    @State private var editingID: Reminder.ID?

    var body: some View {
        TimelineView(.everyMinute) { context in
            let rows = viewModel.rows(at: context.date)
            VStack(alignment: .leading, spacing: 0) {
                Text("Reminders")
                    .font(.headline)
                    .padding(Spacing.lg)
                Divider()
                if rows.isEmpty {
                    ContentUnavailableView {
                        Label("No reminders", systemImage: "bell")
                    } description: {
                        Text("Ask Apl in chat, like “Remind me to stretch at 3 PM”.")
                    }
                    .frame(height: 180)
                } else if rows.count > Self.rowsWithoutScrolling {
                    ScrollView {
                        list(rows)
                    }
                    .frame(height: 340)
                } else {
                    // Tanpa ScrollView: tinggi ScrollView di popover tidak ikut
                    // bertambah saat editor dibuka, sehingga editor terpotong.
                    list(rows)
                }
                if let cancelled = viewModel.lastCancelled {
                    Divider()
                    HStack {
                        Text("“\(cancelled.title)” removed")
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Undo") { Task { await viewModel.undo() } }
                    }
                    .font(.callout)
                    .padding(Spacing.md)
                }
            }
        }
        .frame(width: 320)
    }

    /// Lebih dari ini, daftar digulir dalam tinggi tetap.
    private static let rowsWithoutScrolling = 4

    private func list(_ rows: [ReminderListViewModel.Row]) -> some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                if editingID == row.id {
                    ReminderEditor(reminder: row.reminder,
                                   onSave: { save($0) },
                                   onCancel: { editingID = nil })
                        .padding(Spacing.sm)
                } else {
                    rowView(row)
                }
                Divider()
            }
        }
    }

    private func rowView(_ row: ReminderListViewModel.Row) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: row.repeatsDaily ? "repeat" : "bell")
                .foregroundStyle(AppColor.accent)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.reminder.title)
                    .lineLimit(1)
                Text(row.whenText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: Spacing.sm)
            IconButton(systemImage: "pencil", label: "Edit “\(row.reminder.title)”") {
                editingID = row.id
            }
            IconButton(systemImage: "trash", label: "Remove “\(row.reminder.title)”") {
                Task { await viewModel.cancel(row.id) }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    private func save(_ reminder: Reminder) {
        Task {
            await viewModel.update(reminder)
            editingID = nil
        }
    }
}

#Preview("Popover · Light") {
    RemindersPopover(viewModel: .preview())
}

#Preview("Popover · Empty · Dark") {
    RemindersPopover(viewModel: .preview([]))
        .preferredColorScheme(.dark)
}

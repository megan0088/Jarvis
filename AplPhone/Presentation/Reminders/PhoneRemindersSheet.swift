//
//  PhoneRemindersSheet.swift
//  Apl (iPhone)
//
//  Semua reminder yang akan datang (spec H §4.2): geser untuk hapus, ketuk
//  untuk ubah.
//

import SwiftUI

struct PhoneRemindersSheet: View {
    let viewModel: ReminderListViewModel
    let onOpenSystemSettings: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var editing: Reminder?

    var body: some View {
        NavigationStack {
            // Diperbarui tiap menit, supaya reminder yang lewat hilang sendiri.
            TimelineView(.everyMinute) { context in
                let rows = viewModel.rows(at: context.date)
                List {
                    // Reminder tetap tercatat, tapi tidak akan berbunyi. Tanpa
                    // keterangan ini, itu janji palsu.
                    if !viewModel.notificationsAllowed {
                        Section {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                Label("Notifications are off", systemImage: "bell.slash")
                                    .foregroundStyle(PhoneColor.statusWarning)
                                Text("Your reminders are saved, but they won't alert you.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Button("Open Settings", action: onOpenSystemSettings)
                                    .font(.footnote.weight(.semibold))
                            }
                        }
                    }

                    if let cancelled = viewModel.lastCancelled {
                        Section {
                            HStack {
                                Text("Removed “\(cancelled.title)”")
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Spacer()
                                Button("Undo") { Task { await viewModel.undo() } }
                            }
                        }
                    }

                    Section {
                        ForEach(rows) { row in
                            Button { editing = row.reminder } label: {
                                HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                                    Image(systemName: row.repeatsDaily ? "repeat" : "bell")
                                        .foregroundStyle(PhoneColor.accent)
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(row.reminder.title)
                                            .foregroundStyle(.primary)
                                        Text(row.whenText)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .accessibilityHint("Edits this reminder")
                            .swipeActions {
                                Button("Delete", role: .destructive) {
                                    Task { await viewModel.cancel(row.id) }
                                }
                            }
                        }
                    }
                }
                .overlay {
                    if rows.isEmpty && viewModel.lastCancelled == nil {
                        ContentUnavailableView {
                            Label("No reminders yet", systemImage: "bell")
                        } description: {
                            Text("Ask Apl in chat, like “Remind me to stretch at 3 PM”.")
                        }
                    }
                }
            }
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $editing) { reminder in
                PhoneReminderEditor(reminder: reminder,
                                    onSave: { updated in
                                        Task { await viewModel.update(updated) }
                                        editing = nil
                                    },
                                    onCancel: { editing = nil })
            }
            .task { await viewModel.refreshPermission() }
        }
    }
}

#Preview("Reminders") {
    PhoneRemindersSheet(viewModel: .preview(), onOpenSystemSettings: {})
}

#Preview("Reminders · Empty, notifications off · Dark") {
    PhoneRemindersSheet(viewModel: .preview([], notificationsAllowed: false), onOpenSystemSettings: {})
        .preferredColorScheme(.dark)
}

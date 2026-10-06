//
//  PhoneReminderEditor.swift
//  Apl (iPhone)
//
//  Mengubah judul dan waktu satu reminder (spec H §4.2). Sah-tidaknya isian
//  diputuskan `ReminderDraft`; view ini hanya mengikat kontrolnya.
//

import SwiftUI

struct PhoneReminderEditor: View {
    let reminder: Reminder
    let onSave: (Reminder) -> Void
    let onCancel: () -> Void

    @State private var draft: ReminderDraft

    init(reminder: Reminder, now: Date = .now,
         onSave: @escaping (Reminder) -> Void, onCancel: @escaping () -> Void) {
        self.reminder = reminder
        self.onSave = onSave
        self.onCancel = onCancel
        _draft = State(initialValue: ReminderDraft(reminder, now: now, calendar: .current))
    }

    /// `nil` selama isian belum bisa disimpan: judul kosong, atau reminder
    /// sekali jalan di waktu lampau.
    private var result: Reminder? {
        draft.applied(to: reminder, now: .now, calendar: .current)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $draft.title)
                }
                Section {
                    Picker("Repeat", selection: $draft.frequency) {
                        Text("Once").tag(ReminderDraft.Frequency.once)
                        Text("Every day").tag(ReminderDraft.Frequency.daily)
                    }
                    .pickerStyle(.segmented)
                    DatePicker("Time", selection: $draft.time,
                               displayedComponents: draft.frequency == .once
                                   ? [.date, .hourAndMinute] : [.hourAndMinute])
                } footer: {
                    if result == nil {
                        Text("Add a title and pick a time that hasn't passed.")
                    }
                }
            }
            .navigationTitle("Edit Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let result { onSave(result) }
                    }
                    .disabled(result == nil)
                }
            }
        }
    }
}

#Preview("Editor") {
    PhoneReminderEditor(reminder: PreviewData.reminders()[0], onSave: { _ in }, onCancel: {})
}

//
//  ReminderEditor.swift
//  Apl
//
//  Editor sebaris di popover reminder.
//

import SwiftUI

struct ReminderEditor: View {
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

    private var result: Reminder? {
        draft.applied(to: reminder, now: .now, calendar: .current)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            TextField("Title", text: $draft.title)
                .textFieldStyle(.roundedBorder)
            Picker("Repeat", selection: $draft.frequency) {
                Text("Once").tag(ReminderDraft.Frequency.once)
                Text("Every day").tag(ReminderDraft.Frequency.daily)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            DatePicker("Time", selection: $draft.time,
                       displayedComponents: draft.frequency == .once ? [.date, .hourAndMinute] : [.hourAndMinute])
                .labelsHidden()
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Save") {
                    if let result { onSave(result) }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(result == nil)
            }
        }
        .padding(Spacing.md)
        .background(AppColor.controlFill, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
    }
}

#Preview("Editor · Light") {
    ReminderEditor(reminder: PreviewData.reminders()[0], onSave: { _ in }, onCancel: {})
        .padding()
        .frame(width: 320)
}

#Preview("Editor · Dark") {
    ReminderEditor(reminder: PreviewData.reminders()[1], onSave: { _ in }, onCancel: {})
        .padding()
        .frame(width: 320)
        .preferredColorScheme(.dark)
}

//
//  UpdateReminderUseCase.swift
//  SharedCore
//
//  Mengubah judul, waktu, atau aturan ulang satu reminder. Dipakai
//  sub-project B (edit di popover reminder).
//

import Foundation

@MainActor
struct UpdateReminderUseCase {

    private let store: any ReminderStoring
    private let notifications: any ReminderScheduling
    private let now: () -> Date

    init(store: any ReminderStoring, notifications: any ReminderScheduling,
         now: @escaping () -> Date = { .now }) {
        self.store = store
        self.notifications = notifications
        self.now = now
    }

    func execute(_ reminder: Reminder) async {
        store.update(reminder)
        await notifications.sync(store.reminders, now: now())
    }
}

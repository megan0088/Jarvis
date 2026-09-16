//
//  CancelReminderUseCase.swift
//  SharedCore
//
//  Membatalkan satu reminder. Dipakai sub-project B (Up next, Undo).
//

import Foundation

@MainActor
struct CancelReminderUseCase {

    private let store: any ReminderStoring
    private let notifications: any ReminderScheduling
    private let now: () -> Date

    init(store: any ReminderStoring, notifications: any ReminderScheduling,
         now: @escaping () -> Date = { .now }) {
        self.store = store
        self.notifications = notifications
        self.now = now
    }

    /// Menjadwalkan ulang seluruh daftar, bukan menghapus satu notifikasi,
    /// supaya penjadwal hanya punya satu jalur kebenaran: `sync`.
    func execute(id: Reminder.ID) async {
        store.remove(id: id)
        await notifications.sync(store.reminders, now: now())
    }
}

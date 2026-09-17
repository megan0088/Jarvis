//
//  ReminderScheduling.swift
//  SharedCore
//
//  Kontrak penjadwal notifikasi reminder, dan rencana trigger yang murni.
//
//  Keputusan "apa yang dijadwalkan" dipisah dari adapter sistem supaya bisa
//  dites tanpa UNUserNotificationCenter. Nama `ReminderScheduling`, bukan
//  `NotificationScheduling`: nama itu sempat dipakai jalur wellness selama
//  keduanya hidup berdampingan.
//

import Foundation

protocol ReminderScheduling: Sendable {
    func requestAuthorization() async -> Bool
    /// Apakah macOS saat ini mengizinkan Apl menampilkan notifikasi. Tidak
    /// pernah memunculkan dialog; dipakai petunjuk "Notifications are off".
    func notificationsAllowed() async -> Bool
    /// Menyamakan notifikasi tertunda dengan daftar reminder: semua milik Apl
    /// dihapus, lalu kemunculan terdekat dijadwalkan ulang.
    func sync(_ reminders: [Reminder], now: Date) async
    func cancelAll() async
}

struct ReminderTrigger: Equatable, Sendable {
    let identifier: String
    let title: String
    let components: DateComponents
    let repeats: Bool
}

enum ReminderTriggers {

    static let identifierPrefix = "apl.reminder."

    /// macOS membatasi jumlah notifikasi tertunda per app; tetap di bawahnya.
    static let maxScheduled = 60

    static func plan(for reminders: [Reminder], now: Date, calendar: Calendar) -> [ReminderTrigger] {
        reminders
            .compactMap { reminder in
                reminder.nextOccurrence(after: now, calendar: calendar).map { (reminder, $0) }
            }
            .sorted { $0.1 < $1.1 }
            .prefix(maxScheduled)
            .map { trigger(for: $0.0, calendar: calendar) }
    }

    static func trigger(for reminder: Reminder, calendar: Calendar) -> ReminderTrigger {
        let identifier = identifierPrefix + reminder.id.uuidString
        switch reminder.rule {
        case .once(let date):
            return ReminderTrigger(
                identifier: identifier,
                title: reminder.title,
                components: calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date),
                repeats: false
            )
        case .daily(let hour, let minute):
            return ReminderTrigger(
                identifier: identifier,
                title: reminder.title,
                components: DateComponents(hour: hour, minute: minute),
                repeats: true
            )
        }
    }
}

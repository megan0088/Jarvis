//
//  NotificationScheduling.swift
//  SharedCore
//

import Foundation

protocol NotificationScheduling: Sendable {
    func schedule(_ reminders: [ReminderSchedule]) async
    /// Ada di protokol, bukan hanya di `WellnessNotificationCenter`, karena
    /// mematikan pengingat adalah setengah dari fiturnya — dan setengah itu
    /// tidak bisa diuji selama pemanggilnya harus menyentuh singleton.
    func clearScheduledReminders() async
    func requestAuthorization() async -> Bool
}

extension WellnessNotificationCenter: NotificationScheduling {}

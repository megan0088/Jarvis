//
//  NotificationScheduling.swift
//  SharedCore
//

import Foundation

protocol NotificationScheduling: Sendable {
    func schedule(_ reminders: [ReminderSchedule]) async
    func requestAuthorization() async -> Bool
}

extension WellnessNotificationCenter: NotificationScheduling {}

//
//  WellnessNotificationCenter.swift
//  Jarvis
//

import Foundation
import UserNotifications

@MainActor
final class WellnessNotificationCenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = WellnessNotificationCenter()

    private let center = UNUserNotificationCenter.current()
    private let reminderPrefix = "wellness."

    func configure() {
        center.delegate = self
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    func schedule(_ reminders: [PetStore.ReminderSchedule]) async {
        await clearDeliveredReminders()
        await clearScheduledReminders()

        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            content.userInfo = [
                "wellnessKind": reminder.kind.rawValue,
                "wellnessTitle": reminder.title,
                "wellnessBody": reminder.body
            ]

            var date = DateComponents()
            date.hour = reminder.hour
            date.minute = reminder.minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
            let request = UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger)

            do {
                try await center.add(request)
            } catch {
                continue
            }
        }
    }

    func clearScheduledReminders() async {
        let identifiers = await pendingReminderIDs()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func fetchDeliveredEvents() async -> [PetStore.ReminderEvent] {
        let notifications = await deliveredNotifications()
        let events = notifications.compactMap(event(from:))
        let identifiers = notifications
            .map(\.request.identifier)
            .filter { $0.hasPrefix(reminderPrefix) }

        if !identifiers.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: identifiers)
        }

        return events
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    private func pendingReminderIDs() async -> [String] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests.map(\.identifier).filter { $0.hasPrefix(self.reminderPrefix) })
            }
        }
    }

    private func deliveredNotifications() async -> [UNNotification] {
        await withCheckedContinuation { continuation in
            center.getDeliveredNotifications { continuation.resume(returning: $0) }
        }
    }

    private func clearDeliveredReminders() async {
        let identifiers = await deliveredNotifications()
            .map(\.request.identifier)
            .filter { $0.hasPrefix(reminderPrefix) }
        if !identifiers.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: identifiers)
        }
    }

    private func event(from notification: UNNotification) -> PetStore.ReminderEvent? {
        let userInfo = notification.request.content.userInfo
        guard
            let rawKind = userInfo["wellnessKind"] as? String,
            let kind = PetStore.ReminderKind(rawValue: rawKind)
        else {
            return nil
        }

        let stamp = ISO8601DateFormatter().string(from: notification.date)
        let title = userInfo["wellnessTitle"] as? String ?? notification.request.content.title
        let body = userInfo["wellnessBody"] as? String ?? notification.request.content.body

        return PetStore.ReminderEvent(
            id: "\(notification.request.identifier).\(stamp)",
            kind: kind,
            date: notification.date,
            message: "\(title): \(body)"
        )
    }
}

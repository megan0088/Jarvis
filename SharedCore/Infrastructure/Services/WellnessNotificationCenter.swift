//
//  WellnessNotificationCenter.swift
//  Apl
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

    func schedule(_ reminders: [ReminderSchedule]) async {
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

    func fetchDeliveredEvents() async -> [ReminderEvent] {
        let payload = await deliveredReminderPayload()
        if !payload.identifiers.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: payload.identifiers)
        }
        return payload.events
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

    /// Mengembalikan hasil yang sudah dipetakan, bukan `[UNNotification]`.
    ///
    /// `UNNotification` bukan `Sendable`; menyeberangkannya keluar dari
    /// completion handler adalah satu-satunya pelanggaran Swift 6 di seluruh
    /// basis kode ini. Pemetaan dipindah ke dalam handler sehingga yang
    /// menyeberang hanya `ReminderEvent` dan `String`.
    private func deliveredReminderPayload() async -> (events: [ReminderEvent], identifiers: [String]) {
        let prefix = reminderPrefix
        return await withCheckedContinuation { continuation in
            center.getDeliveredNotifications { notifications in
                let events = notifications.compactMap(Self.event(from:))
                let identifiers = notifications
                    .map(\.request.identifier)
                    .filter { $0.hasPrefix(prefix) }
                continuation.resume(returning: (events, identifiers))
            }
        }
    }

    private func clearDeliveredReminders() async {
        let identifiers = await deliveredReminderPayload().identifiers
        if !identifiers.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: identifiers)
        }
    }

    /// Fungsi murni dan `nonisolated`: dipanggil DI DALAM completion handler,
    /// bukan setelahnya, supaya `UNNotification` — yang bukan `Sendable` —
    /// tidak pernah menyeberangi batas isolasi.
    nonisolated private static func event(from notification: UNNotification) -> ReminderEvent? {
        let userInfo = notification.request.content.userInfo
        guard
            let rawKind = userInfo["wellnessKind"] as? String,
            let kind = ReminderKind(rawValue: rawKind)
        else {
            return nil
        }

        let stamp = ISO8601DateFormatter().string(from: notification.date)
        let title = userInfo["wellnessTitle"] as? String ?? notification.request.content.title
        let body = userInfo["wellnessBody"] as? String ?? notification.request.content.body

        return ReminderEvent(
            id: "\(notification.request.identifier).\(stamp)",
            kind: kind,
            date: notification.date,
            message: "\(title): \(body)"
        )
    }
}

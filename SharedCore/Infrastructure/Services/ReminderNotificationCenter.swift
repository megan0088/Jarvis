//
//  ReminderNotificationCenter.swift
//  SharedCore
//
//  Adapter tipis ke UNUserNotificationCenter. Keputusan apa yang dijadwalkan,
//  kapan, dan berapa banyak ada di `ReminderTriggers` — murni dan dites.
//  Berkas ini hanya menerjemahkannya ke API sistem, jadi diverifikasi lewat
//  app sungguhan, bukan unit test.
//

import Foundation
import UserNotifications

@MainActor
final class ReminderNotificationCenter: NSObject, UNUserNotificationCenterDelegate {

    static let shared = ReminderNotificationCenter()

    private let center = UNUserNotificationCenter.current()

    /// Dipanggil sekali saat app dibuka. Tanpa delegate, reminder yang jatuh
    /// tempo saat Apl sedang di depan tidak ditampilkan sama sekali.
    func configure() {
        center.delegate = self
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    func sync(_ reminders: [Reminder], now: Date) async {
        await cancelAll()
        for trigger in ReminderTriggers.plan(for: reminders, now: now, calendar: .current) {
            let content = UNMutableNotificationContent()
            content.title = trigger.title
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: trigger.identifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: trigger.components,
                                                       repeats: trigger.repeats)
            )
            do {
                try await center.add(request)
            } catch {
                continue
            }
        }
    }

    func cancelAll() async {
        let identifiers = await pendingReminderIDs()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    /// Hanya identifier yang keluar dari completion handler: `UNNotificationRequest`
    /// bukan `Sendable`, dan menyeberangkannya ditolak Swift 6.
    private func pendingReminderIDs() async -> [String] {
        let prefix = ReminderTriggers.identifierPrefix
        return await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests.map(\.identifier).filter { $0.hasPrefix(prefix) })
            }
        }
    }
}

extension ReminderNotificationCenter: ReminderScheduling {}

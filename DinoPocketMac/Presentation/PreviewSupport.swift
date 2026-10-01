//
//  PreviewSupport.swift
//  Apl
//
//  Data dan penyimpanan palsu untuk #Preview.
//
//  SENGAJA tidak dibungkus `#if DEBUG`: blok #Preview ikut dikompilasi di
//  Release, dan helper yang hilang di Release baru ketahuan saat archive.
//  Penyimpanan preview memakai suite UserDefaults sendiri, bukan data app.
//

import Foundation

enum PreviewData {

    static let stretchID = UUID(uuidString: "5A1E0000-0000-4000-8000-000000000001")!

    static func reminders(now: Date = .now) -> [Reminder] {
        [
            Reminder(id: stretchID, title: "Stretch",
                     rule: .once(now.addingTimeInterval(45 * 60)), createdAt: now),
            Reminder(title: "Drink water", rule: .daily(hour: 9, minute: 0), createdAt: now),
            Reminder(title: "Call mom", rule: .once(now.addingTimeInterval(26 * 60 * 60)), createdAt: now),
            Reminder(title: "Write stand-up notes", rule: .daily(hour: 16, minute: 30), createdAt: now),
        ]
    }

    static var messages: [ChatMessage] {
        [
            ChatMessage(role: .user, text: "Any tips to stay focused this afternoon?"),
            ChatMessage(role: .assistant, text: """
                Try **25-minute blocks** with a short break between them:

                - Close the tabs you don't need
                - Put your phone out of reach

                ```swift
                let block = Duration.seconds(25 * 60)
                ```
                """),
            ChatMessage(role: .user, text: "Remind me to stretch in 45 minutes"),
            ChatMessage(role: .assistant, text: "Done — I'll remind you to stretch in 45 minutes.",
                        attachment: .reminder(stretchID)),
        ]
    }
}

/// Penjadwal yang tidak menjadwalkan apa pun.
struct PreviewReminderScheduler: ReminderScheduling {
    var allowed = true

    func requestAuthorization() async -> Bool { allowed }
    func notificationsAllowed() async -> Bool { allowed }
    func sync(_ reminders: [Reminder], now: Date) async {}
    func cancelAll() async {}
}

extension ReminderListViewModel {
    static func preview(_ reminders: [Reminder] = PreviewData.reminders(),
                        notificationsAllowed: Bool = true) -> ReminderListViewModel {
        let store = ReminderStore(defaults: UserDefaults(suiteName: "apl.preview.reminders")!)
        store.eraseAllStoredData()
        for reminder in reminders {
            store.add(reminder)
        }
        return ReminderListViewModel(store: store,
                                     notifications: PreviewReminderScheduler(allowed: notificationsAllowed),
                                     notificationsAllowed: notificationsAllowed)
    }
}

extension ChatStore {
    static func preview(_ messages: [ChatMessage] = PreviewData.messages,
                        isStreaming: Bool = false) -> ChatStore {
        let store = ChatStore(brain: nil, defaults: UserDefaults(suiteName: "apl.preview.chat")!)
        store.messages = messages
        store.isStreaming = isStreaming
        return store
    }
}

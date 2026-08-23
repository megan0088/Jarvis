//
//  AppIntent.swift
//  JarvisWidget
//

import AppIntents
import ActivityKit
import WidgetKit

// MARK: - Complete Reminder Intent

struct CompleteReminderIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Reminder"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Reminder Kind")
    var kind: String

    init() { self.kind = "" }
    init(kind: String) { self.kind = kind }

    func perform() async throws -> some IntentResult {
        // Dismiss active reminder from Live Activity
        dismissReminder()
        // Write completion to App Group so main app can update goals
        let defaults = UserDefaults(suiteName: "group.com.Jarvis")
        defaults?.set(kind, forKey: "reminder.completed.kind")
        defaults?.set(Date().timeIntervalSince1970, forKey: "reminder.completed.time")
        return .result()
    }
}

// MARK: - Snooze Reminder Intent

struct SnoozeReminderIntent: AppIntent {
    static var title: LocalizedStringResource = "Snooze Reminder"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Reminder Kind")
    var kind: String

    init() { self.kind = "" }
    init(kind: String) { self.kind = kind }

    func perform() async throws -> some IntentResult {
        // Dismiss active reminder from Live Activity
        dismissReminder()
        // Write snooze to App Group (10 minutes)
        let defaults = UserDefaults(suiteName: "group.com.Jarvis")
        defaults?.set(kind, forKey: "reminder.snoozed.kind")
        defaults?.set(
            Date().addingTimeInterval(600).timeIntervalSince1970,
            forKey: "reminder.snoozed.until"
        )
        return .result()
    }
}

// MARK: - Shared Helper

/// Removes activeReminder from any running Jarvis Live Activity
private func dismissReminder() {
    Task {
        for activity in Activity<PetActivityAttributes>.activities {
            var state = activity.content.state
            guard state.activeReminder != nil else { continue }
            state.activeReminder = nil
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }
}

// MARK: - Widget Configuration Intent (template, keep for JarvisWidget)

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration" }
    static var description: IntentDescription { "Jarvis widget configuration." }

    @Parameter(title: "Favorite Emoji", default: "😃")
    var favoriteEmoji: String
}

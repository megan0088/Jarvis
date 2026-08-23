//
//  JarvisTests.swift
//  JarvisTests
//
//  Created by Muhamad Ega Nugraha on 13/03/26.
//

import Foundation
import Testing
@testable import Jarvis

struct JarvisTests {
    @MainActor
    @Test func screenTimeSplitsAcrossDays() {
        let store = PetStore()
        store.screenTimeHistory = []

        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2025, month: 1, day: 1, hour: 23, minute: 30))!
        let end = calendar.date(from: DateComponents(year: 2025, month: 1, day: 2, hour: 0, minute: 30))!

        store.resumeScreenTime(at: start)
        store.pauseScreenTime(at: end)

        let durations: [Date: TimeInterval] = Dictionary(uniqueKeysWithValues: store.screenTimeHistory.map {
            (calendar.startOfDay(for: $0.date), $0.duration)
        })

        #expect(durations.count == 2)
        #expect(durations[calendar.startOfDay(for: start)] == 1800)
        #expect(durations[calendar.startOfDay(for: end)] == 1800)
    }

    @MainActor
    @Test func reminderHistoryDeduplicatesEventIDs() {
        let store = PetStore()
        store.reminderHistory = []
        store.seenReminderEventIDs = []

        let event = PetStore.ReminderEvent(
            id: "wellness.water.9.0.test",
            kind: .water,
            date: .now,
            message: "Hydration: test"
        )

        store.recordReminder(event)
        store.recordReminder(event)

        #expect(store.reminderHistory.count == 1)
    }

    @MainActor
    @Test func completingReminderIncrementsGoalProgress() {
        let store = PetStore()
        store.goalProgress = .init(date: .now, water: 0, stretch: 0, meal: 0)

        let reminder = PetStore.BuddyReminder(
            key: "wellness.water.9.0.test",
            schedule: .init(
                id: "wellness.water.9.0",
                kind: .water,
                hour: 9,
                minute: 0,
                title: "Minum air",
                body: "Ambil jeda dan minum segelas air."
            ),
            scheduledDate: .now
        )

        store.completeReminder(reminder)

        #expect(store.goalProgress.water == 1)
    }

    @MainActor
    @Test func snoozingReminderStoresDeferredPrompt() {
        let store = PetStore()
        store.snoozedReminders = []

        let reminder = PetStore.BuddyReminder(
            key: "wellness.meal.13.0.test",
            schedule: .init(
                id: "wellness.meal.13.0",
                kind: .meal,
                hour: 13,
                minute: 0,
                title: "Makan siang",
                body: "Saatnya makan siang."
            ),
            scheduledDate: .now
        )

        let target = Date().addingTimeInterval(600)
        store.snoozeReminder(reminder, until: target)

        #expect(store.snoozedReminders.count == 1)
        #expect(store.snoozedReminders.first?.kind == .meal)
    }
}

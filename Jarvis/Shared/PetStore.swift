//
//  PetStore.swift
//  Jarvis
//
//  Created by Codex on 13/03/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class PetStore {
    struct ScreenTimeEntry: Codable, Identifiable {
        var date: Date
        var duration: TimeInterval

        var id: Date { Calendar.current.startOfDay(for: date) }
    }

    enum ReminderKind: String, CaseIterable, Codable, Identifiable {
        case water
        case stretch
        case meal

        var id: String { rawValue }

        var title: String {
            switch self {
            case .water: "Hydration"
            case .stretch: "Stretching"
            case .meal: "Meals"
            }
        }

        var icon: String {
            switch self {
            case .water: "drop.fill"
            case .stretch: "figure.cooldown"
            case .meal: "fork.knife"
            }
        }

        var researchNote: String {
            switch self {
            case .water:
                "NHS menyarankan sekitar 6-8 gelas cairan per hari. Default Jarvis: pengingat tiap 2 jam."
            case .stretch:
                "AHA menyarankan bergerak setidaknya tiap 30 menit saat banyak duduk. Default Jarvis: pengingat tiap 45 menit."
            case .meal:
                "Panduan gizi jantung menganjurkan pola makan teratur sepanjang hari. Default Jarvis: sarapan, makan siang, makan malam."
            }
        }
    }

    struct ReminderEvent: Codable, Identifiable {
        var id: String
        var kind: ReminderKind
        var date: Date
        var message: String
        var wasCompleted: Bool = false
    }

    struct WellnessGoalProgress: Codable {
        var date: Date
        var water: Int
        var stretch: Int
        var meal: Int
    }

    struct SnoozedReminder: Codable {
        var key: String
        var kind: ReminderKind
        var fireDate: Date
    }

    struct ReminderSchedule: Codable, Identifiable {
        var id: String
        var kind: ReminderKind
        var hour: Int
        var minute: Int
        var title: String
        var body: String

        var timeLabel: String {
            let components = DateComponents(hour: hour, minute: minute)
            return Calendar.current.date(from: components)?.formatted(date: .omitted, time: .shortened) ?? "\(hour):\(minute)"
        }
    }

    struct BuddyReminder {
        var key: String
        var schedule: ReminderSchedule
        var scheduledDate: Date
    }

    private enum AppGroup {
        static let id = "group.com.example.jarvis"
    }

    enum Mood: String, CaseIterable, Codable {
        case happy, calm, hungry, sleepy, angry

        var label: String {
            switch self {
            case .happy: "Laughing"
            case .calm: "Ready"
            case .hungry: "Hungry"
            case .sleepy: "Sleepy"
            case .angry: "Angry"
            }
        }

        var emoji: String {
            switch self {
            case .happy: "😂"
            case .calm: "😌"
            case .hungry: "😋"
            case .sleepy: "🥱"
            case .angry: "😤"
            }
        }
    }

    private let defaults = UserDefaults(suiteName: AppGroup.id) ?? .standard
    private let ubiquitous = NSUbiquitousKeyValueStore.default
    private let calendar = Calendar.current

    private enum Keys {
        static let mood = "pet.mood"
        static let hunger = "pet.hunger"
        static let energy = "pet.energy"
        static let lastFed = "pet.lastFed"
        static let affection = "pet.affection"
        static let screenTimeHistory = "wellness.screenTimeHistory"
        static let reminderHistory = "wellness.reminderHistory"
        static let reminderEventsSeen = "wellness.reminderEventsSeen"
        static let remindersEnabled = "wellness.remindersEnabled"
        static let goalProgress = "wellness.goalProgress"
        static let snoozedReminders = "wellness.snoozedReminders"
    }

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var activeSessionStart: Date?
    private var didPrepareWellness = false

    var mood: Mood
    var hunger: Int
    var energy: Int
    var affection: Int
    var lastFed: Date

    var screenTimeHistory: [ScreenTimeEntry]
    var reminderHistory: [ReminderEvent]
    var seenReminderEventIDs: Set<String>
    var remindersEnabled: Bool
    var goalProgress: WellnessGoalProgress
    var snoozedReminders: [SnoozedReminder]

    init() {
        mood = Mood(rawValue: defaults.string(forKey: Keys.mood) ?? "calm") ?? .calm
        hunger = defaults.integer(forKey: Keys.hunger)
        energy = defaults.integer(forKey: Keys.energy)
        affection = defaults.integer(forKey: Keys.affection)
        lastFed = defaults.object(forKey: Keys.lastFed) as? Date ?? .now
        screenTimeHistory = Self.decode([ScreenTimeEntry].self, from: defaults.data(forKey: Keys.screenTimeHistory)) ?? []
        reminderHistory = Self.decode([ReminderEvent].self, from: defaults.data(forKey: Keys.reminderHistory)) ?? []
        seenReminderEventIDs = Set(defaults.stringArray(forKey: Keys.reminderEventsSeen) ?? [])
        remindersEnabled = defaults.bool(forKey: Keys.remindersEnabled)
        goalProgress = Self.decode(WellnessGoalProgress.self, from: defaults.data(forKey: Keys.goalProgress))
            ?? WellnessGoalProgress(date: .now, water: 0, stretch: 0, meal: 0)
        snoozedReminders = Self.decode([SnoozedReminder].self, from: defaults.data(forKey: Keys.snoozedReminders)) ?? []

        if hunger == 0 { hunger = 45 }
        if energy == 0 { energy = 70 }
        if affection == 0 { affection = 55 }
        resetGoalsIfNeeded()

        Task { @MainActor in
            syncFromCloudIfAvailable()
        }
        NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: ubiquitous, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.syncFromCloudIfAvailable()
            }
        }
    }

    var todayScreenTime: TimeInterval {
        screenTime(on: .now) + activeSessionDuration(at: .now)
    }

    var recentScreenTimeHistory: [ScreenTimeEntry] {
        screenTimeHistory
            .sorted { $0.date > $1.date }
            .prefix(7)
            .map { $0 }
    }

    var recentReminderHistory: [ReminderEvent] {
        reminderHistory
            .sorted { $0.date > $1.date }
            .prefix(8)
            .map { $0 }
    }

    var reminderSchedules: [ReminderSchedule] {
        [
            schedule(.water, 9, 0, "Minum air", "Ambil jeda dan minum segelas air."),
            schedule(.water, 11, 0, "Hydration break", "Saatnya minum lagi supaya tetap terhidrasi."),
            schedule(.water, 13, 0, "Refill air", "Isi ulang cairan tubuh setelah setengah hari bekerja."),
            schedule(.water, 15, 0, "Minum sebentar", "Bangun, tarik napas, lalu minum air."),
            schedule(.water, 17, 0, "Hydration check", "Pastikan asupan cairan tetap jalan."),
            schedule(.water, 19, 0, "Last water break", "Tambahkan satu gelas air sebelum malam."),
            schedule(.stretch, 9, 45, "Stretch break", "Berdiri 2-3 menit dan regangkan bahu, leher, serta punggung."),
            schedule(.stretch, 10, 30, "Move a bit", "Lepas duduk terlalu lama dengan stretch singkat."),
            schedule(.stretch, 11, 15, "Posture reset", "Goyangkan bahu dan buka dada sebentar."),
            schedule(.stretch, 14, 0, "Stretching", "Setelah makan siang, berdiri dan gerakkan tubuh."),
            schedule(.stretch, 15, 0, "Mobility break", "Istirahat sebentar untuk kaki, punggung, dan leher."),
            schedule(.stretch, 16, 0, "Desk break", "Lepas posisi duduk dan jalan singkat."),
            schedule(.meal, 8, 0, "Sarapan", "Mulai hari dengan sarapan yang seimbang."),
            schedule(.meal, 13, 0, "Makan siang", "Saatnya makan siang, jangan cuma kopi."),
            schedule(.meal, 19, 0, "Makan malam", "Atur makan malam yang cukup dan tidak terlalu larut.")
        ]
    }

    var statusMessage: String {
        switch mood {
        case .hungry:
            "Butuh makan (terakhir \(lastFed.formatted(date: .abbreviated, time: .shortened)))"
        case .sleepy where energy < 30:
            "Mengantuk, beri waktu istirahat."
        case .angry:
            "Sedang kesal, ajak bermain sebentar."
        case .happy:
            "Lagi tertawa. Keep it fun."
        default:
            affection < 30 ? "Merasa sepi, butuh dipet." : "Siap jadi coding buddy."
        }
    }

    var goalSummary: [ReminderKind: String] {
        resetGoalsIfNeeded()
        return [
            .water: "\(goalProgress.water)/6",
            .stretch: "\(goalProgress.stretch)/6",
            .meal: "\(goalProgress.meal)/3"
        ]
    }

    var buddyReminderPollingInterval: TimeInterval {
        60
    }

    func prepareWellness() async {
        guard !didPrepareWellness else { return }
        didPrepareWellness = true
        resumeScreenTime()
        if remindersEnabled {
            await scheduleReminders()
        }
        await syncReminderHistory()
    }

    func squish() {
        bumpEnergy(by: 5)
        bumpAffection(by: 6)
        recalcMood()
        savePet()
    }

    func pet() {
        bumpEnergy(by: 10)
        hunger += 3
        bumpAffection(by: 12)
        recalcMood()
        savePet()
    }

    func feed() {
        hunger = max(0, hunger - 35)
        lastFed = .now
        bumpAffection(by: 8)
        bumpEnergy(by: 5)
        recalcMood()
        savePet()
    }

    func rest() {
        energy = min(100, energy + 20)
        affection = max(0, affection - 2)
        recalcMood()
        savePet()
    }

    func wakeUp() {
        energy = min(100, energy + 10)
        recalcMood()
        savePet()
    }

    func tick() {
        hunger = min(100, hunger + 2)
        energy = max(0, energy - 1)
        affection = max(0, affection - 1)
        recalcMood()
        savePet()
    }

    func resumeScreenTime(at date: Date = .now) {
        guard activeSessionStart == nil else { return }
        activeSessionStart = date
    }

    func pauseScreenTime(at date: Date = .now) {
        guard let activeSessionStart else { return }
        addScreenTime(from: activeSessionStart, to: date)
        self.activeSessionStart = nil
        saveWellness()
    }

    func screenTimeToday(at date: Date) -> TimeInterval {
        screenTime(on: date) + activeSessionDuration(at: date)
    }

    func toggleReminders() async {
        remindersEnabled.toggle()
        if remindersEnabled {
            let granted = await WellnessNotificationCenter.shared.requestAuthorization()
            if granted {
                await scheduleReminders()
            } else {
                remindersEnabled = false
            }
        } else {
            await WellnessNotificationCenter.shared.clearScheduledReminders()
        }
        saveWellness()
    }

    func scheduleReminders() async {
        guard remindersEnabled else { return }
        await WellnessNotificationCenter.shared.schedule(reminderSchedules)
    }

    func syncReminderHistory() async {
        let events = await WellnessNotificationCenter.shared.fetchDeliveredEvents()
        for event in events {
            recordReminder(event)
        }
    }

    func recordReminder(_ event: ReminderEvent) {
        resetGoalsIfNeeded()
        guard seenReminderEventIDs.insert(event.id).inserted else { return }
        reminderHistory.insert(event, at: 0)
        reminderHistory = Array(reminderHistory.prefix(30))
        saveWellness()
    }

    func completeReminder(_ reminder: BuddyReminder, at date: Date = .now) {
        resetGoalsIfNeeded(referenceDate: date)
        snoozedReminders.removeAll { $0.key == reminder.key }
        switch reminder.schedule.kind {
        case .water:
            goalProgress.water += 1
        case .stretch:
            goalProgress.stretch += 1
        case .meal:
            goalProgress.meal += 1
        }

        recordReminder(
            ReminderEvent(
                id: reminder.key + ".done",
                kind: reminder.schedule.kind,
                date: date,
                message: "\(reminder.schedule.title): selesai",
                wasCompleted: true
            )
        )
        saveWellness()
    }

    func snoozeReminder(_ reminder: BuddyReminder, until date: Date) {
        snoozedReminders.removeAll { $0.key == reminder.key }
        snoozedReminders.append(
            SnoozedReminder(key: reminder.key, kind: reminder.schedule.kind, fireDate: date)
        )
        saveWellness()
    }

    func buddyReminder(at date: Date = .now) -> BuddyReminder? {
        if let snoozed = dueSnoozedReminder(at: date) {
            return snoozed
        }

        let minute = calendar.component(.minute, from: date)
        let hour = calendar.component(.hour, from: date)

        for schedule in reminderSchedules {
            guard schedule.hour == hour else { continue }
            guard minute >= schedule.minute, minute < schedule.minute + 15 else { continue }

            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = schedule.hour
            components.minute = schedule.minute
            let scheduledDate = calendar.date(from: components) ?? date

            return BuddyReminder(
                key: "\(schedule.id).\(calendar.startOfDay(for: date).timeIntervalSince1970)",
                schedule: schedule,
                scheduledDate: scheduledDate
            )
        }

        return nil
    }

    func demoReminder(for kind: ReminderKind, at date: Date = .now) -> BuddyReminder {
        let schedule = reminderSchedules.first(where: { $0.kind == kind }) ?? fallbackSchedule(for: kind)
        return BuddyReminder(
            key: "demo.\(kind.rawValue).\(Int(date.timeIntervalSince1970))",
            schedule: schedule,
            scheduledDate: date
        )
    }

    func resetGoalProgress(for kind: ReminderKind, at date: Date = .now) {
        resetGoalsIfNeeded(referenceDate: date)
        switch kind {
        case .water:
            goalProgress.water = 0
        case .stretch:
            goalProgress.stretch = 0
        case .meal:
            goalProgress.meal = 0
        }
        saveWellness()
    }

    private func schedule(_ kind: ReminderKind, _ hour: Int, _ minute: Int, _ title: String, _ body: String) -> ReminderSchedule {
        ReminderSchedule(
            id: "wellness.\(kind.rawValue).\(hour).\(minute)",
            kind: kind,
            hour: hour,
            minute: minute,
            title: title,
            body: body
        )
    }

    private func fallbackSchedule(for kind: ReminderKind) -> ReminderSchedule {
        switch kind {
        case .water:
            schedule(.water, 9, 0, "Minum air", "Ambil jeda dan minum segelas air.")
        case .stretch:
            schedule(.stretch, 9, 45, "Stretch break", "Berdiri 2-3 menit dan regangkan bahu, leher, serta punggung.")
        case .meal:
            schedule(.meal, 13, 0, "Makan siang", "Saatnya makan siang, jangan cuma kopi.")
        }
    }

    private func screenTime(on date: Date) -> TimeInterval {
        let start = calendar.startOfDay(for: date)
        return screenTimeHistory.first(where: { calendar.isDate($0.date, inSameDayAs: start) })?.duration ?? 0
    }

    private func activeSessionDuration(at date: Date) -> TimeInterval {
        guard let activeSessionStart else { return 0 }
        let dayStart = calendar.startOfDay(for: date)
        return max(0, date.timeIntervalSince(max(activeSessionStart, dayStart)))
    }

    private func addScreenTime(from start: Date, to end: Date) {
        guard end > start else { return }
        var cursor = start

        while cursor < end {
            let dayStart = calendar.startOfDay(for: cursor)
            let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? end
            let segmentEnd = min(end, nextDay)
            upsertScreenTime(on: dayStart, duration: segmentEnd.timeIntervalSince(cursor))
            cursor = segmentEnd
        }
    }

    private func upsertScreenTime(on day: Date, duration: TimeInterval) {
        if let index = screenTimeHistory.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: day) }) {
            screenTimeHistory[index].duration += duration
        } else {
            screenTimeHistory.append(ScreenTimeEntry(date: day, duration: duration))
        }
        screenTimeHistory = screenTimeHistory
            .sorted { $0.date > $1.date }
            .prefix(14)
            .map { $0 }
    }

    private func bumpEnergy(by delta: Int) {
        energy = min(100, energy + delta)
    }

    private func bumpAffection(by delta: Int) {
        affection = min(100, affection + delta)
    }

    private func savePet() {
        defaults.set(mood.rawValue, forKey: Keys.mood)
        defaults.set(hunger, forKey: Keys.hunger)
        defaults.set(energy, forKey: Keys.energy)
        defaults.set(affection, forKey: Keys.affection)
        defaults.set(lastFed, forKey: Keys.lastFed)
        ubiquitous.set(mood.rawValue, forKey: Keys.mood)
        ubiquitous.set(hunger, forKey: Keys.hunger)
        ubiquitous.set(energy, forKey: Keys.energy)
        ubiquitous.set(affection, forKey: Keys.affection)
        ubiquitous.set(lastFed.timeIntervalSince1970, forKey: Keys.lastFed)
        ubiquitous.synchronize()
    }

    private func saveWellness() {
        defaults.set(try? encoder.encode(screenTimeHistory), forKey: Keys.screenTimeHistory)
        defaults.set(try? encoder.encode(reminderHistory), forKey: Keys.reminderHistory)
        defaults.set(Array(seenReminderEventIDs), forKey: Keys.reminderEventsSeen)
        defaults.set(remindersEnabled, forKey: Keys.remindersEnabled)
        defaults.set(try? encoder.encode(goalProgress), forKey: Keys.goalProgress)
        defaults.set(try? encoder.encode(snoozedReminders), forKey: Keys.snoozedReminders)
    }

    private func syncFromCloudIfAvailable() {
        if let moodRaw = ubiquitous.string(forKey: Keys.mood), let cloudMood = Mood(rawValue: moodRaw) {
            mood = cloudMood
        }
        if ubiquitous.object(forKey: Keys.hunger) != nil {
            hunger = Int(ubiquitous.longLong(forKey: Keys.hunger))
        }
        if ubiquitous.object(forKey: Keys.energy) != nil {
            energy = Int(ubiquitous.longLong(forKey: Keys.energy))
        }
        if ubiquitous.object(forKey: Keys.affection) != nil {
            affection = Int(ubiquitous.longLong(forKey: Keys.affection))
        }
        if ubiquitous.object(forKey: Keys.lastFed) != nil {
            lastFed = Date(timeIntervalSince1970: ubiquitous.double(forKey: Keys.lastFed))
        }
    }

    private func recalcMood() {
        if hunger > 80 {
            mood = .hungry
        } else if energy < 25 {
            mood = .sleepy
        } else if affection < 20 {
            mood = .angry
        } else if affection > 70 {
            mood = .happy
        } else {
            mood = .calm
        }
    }

    private func resetGoalsIfNeeded(referenceDate: Date = .now) {
        guard !calendar.isDate(goalProgress.date, inSameDayAs: referenceDate) else { return }
        goalProgress = WellnessGoalProgress(date: referenceDate, water: 0, stretch: 0, meal: 0)
    }

    private func dueSnoozedReminder(at date: Date) -> BuddyReminder? {
        snoozedReminders.removeAll { $0.fireDate < date.addingTimeInterval(-3600 * 6) }
        guard let index = snoozedReminders.firstIndex(where: { $0.fireDate <= date }) else { return nil }
        let snoozed = snoozedReminders[index]
        guard let schedule = reminderSchedules.first(where: { $0.kind == snoozed.kind }) else {
            snoozedReminders.remove(at: index)
            return nil
        }
        return BuddyReminder(key: snoozed.key, schedule: schedule, scheduledDate: snoozed.fireDate)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

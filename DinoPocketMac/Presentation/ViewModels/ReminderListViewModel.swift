//
//  ReminderListViewModel.swift
//  Apl
//
//  Reminder untuk Up next, popover, dan chip di chat (spec B §6). Membaca
//  store reminder dari A; setiap perubahan menjadwalkan ulang notifikasi
//  lewat UseCase yang sama dengan jalur chat.
//

import Foundation
import Observation

/// Isi chip di bawah konfirmasi reminder.
enum ReminderChipState: Equatable {
    case scheduled(title: String, whenText: String)
    /// Sudah lewat — termasuk yang sudah dibuang ReminderStore karena lewat
    /// lebih dari sehari.
    case past
    /// Dibatalkan pengguna di sesi ini (Undo di chip atau di popover).
    case removed
}

@MainActor
@Observable
final class ReminderListViewModel {

    struct Row: Identifiable, Equatable {
        let reminder: Reminder
        let next: Date
        let whenText: String

        var id: Reminder.ID { reminder.id }

        var repeatsDaily: Bool {
            if case .daily = reminder.rule { return true }
            return false
        }
    }

    nonisolated static let upNextLimit = 3

    /// Reminder terakhir yang dibatalkan, untuk Undo di popover.
    private(set) var lastCancelled: Reminder?
    private(set) var notificationsAllowed: Bool
    private var removedIDs: Set<Reminder.ID> = []

    private let store: any ReminderStoring
    private let notifications: any ReminderScheduling
    private let now: () -> Date
    private let calendar: Calendar
    private let locale: Locale

    init(store: any ReminderStoring,
         notifications: any ReminderScheduling,
         now: @escaping () -> Date = { .now },
         calendar: Calendar = .current,
         locale: Locale = .current,
         notificationsAllowed: Bool = true) {
        self.store = store
        self.notifications = notifications
        self.now = now
        self.calendar = calendar
        self.locale = locale
        self.notificationsAllowed = notificationsAllowed
    }

    // MARK: - Membaca

    /// Reminder yang masih akan muncul, terdekat dulu. `.once` yang sudah lewat tidak ikut.
    /// `date` diberikan view (TimelineView), supaya daftar ikut bergeser seiring waktu.
    func rows(at date: Date) -> [Row] {
        store.reminders
            .compactMap { reminder in
                reminder.nextOccurrence(after: date, calendar: calendar).map { (reminder, $0) }
            }
            .sorted { $0.1 < $1.1 }
            .map {
                Row(reminder: $0.0, next: $0.1,
                    whenText: Self.whenText(for: $0.0.rule, next: $0.1, now: date,
                                            calendar: calendar, locale: locale))
            }
    }

    func upNext(at date: Date) -> [Row] {
        Array(rows(at: date).prefix(Self.upNextLimit))
    }

    func reminder(withID id: Reminder.ID) -> Reminder? {
        store.reminders.first { $0.id == id }
    }

    func chipState(for id: Reminder.ID, at date: Date) -> ReminderChipState {
        guard let reminder = reminder(withID: id) else {
            return removedIDs.contains(id) ? .removed : .past
        }
        guard let next = reminder.nextOccurrence(after: date, calendar: calendar) else {
            return .past
        }
        return .scheduled(title: reminder.title,
                          whenText: Self.whenText(for: reminder.rule, next: next, now: date,
                                                  calendar: calendar, locale: locale))
    }

    // MARK: - Mengubah

    func cancel(_ id: Reminder.ID) async {
        guard let reminder = reminder(withID: id) else { return }
        lastCancelled = reminder
        removedIDs.insert(id)
        await CancelReminderUseCase(store: store, notifications: notifications, now: now).execute(id: id)
    }

    /// Mengembalikan reminder yang terakhir dibatalkan, dengan id yang sama.
    func undo() async {
        guard let reminder = lastCancelled else { return }
        lastCancelled = nil
        removedIDs.remove(reminder.id)
        store.add(reminder)
        await notifications.sync(store.reminders, now: now())
    }

    func update(_ reminder: Reminder) async {
        await UpdateReminderUseCase(store: store, notifications: notifications, now: now).execute(reminder)
    }

    func refreshPermission() async {
        notificationsAllowed = await notifications.notificationsAllowed()
    }

    // MARK: - Teks

    /// "Today, 3:00 PM" · "Tomorrow, 9:00 AM" · "Every day, 9:00 AM" · "Sep 19, 9:00 AM"
    nonisolated static func whenText(for rule: Reminder.Rule, next: Date, now: Date,
                                     calendar: Calendar, locale: Locale) -> String {
        let clock = ReminderPhrasing.time(next, calendar: calendar, locale: locale)
        if case .daily = rule {
            return "Every day, \(clock)"
        }
        if calendar.isDate(next, inSameDayAs: now) {
            return "Today, \(clock)"
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(next, inSameDayAs: tomorrow) {
            return "Tomorrow, \(clock)"
        }
        let dayStyle = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            .month(.abbreviated)
            .day()
        return "\(next.formatted(dayStyle)), \(clock)"
    }
}

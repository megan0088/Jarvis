//
//  CreateReminderFromTextUseCase.swift
//  SharedCore
//
//  Parse → simpan → jadwalkan, sebagai satu tanggung jawab.
//
//  Dulu penjadwalan terjadi di tempat lain, sehingga apakah reminder
//  benar-benar berbunyi bergantung pada siapa yang memasang closure-nya.
//  Menyatukannya di sini membuat "reminder dibuat" dan "reminder
//  dijadwalkan" tidak mungkin berbeda pendapat.
//

import Foundation

@MainActor
struct CreateReminderFromTextUseCase {

    enum Output: Equatable {
        case created(Reminder, confirmation: String)
        case needsTime(title: String?, question: String)
        case notAReminder
    }

    private let store: any ReminderStoring
    private let notifications: any ReminderScheduling
    private let now: () -> Date
    private let calendar: Calendar
    private let locale: Locale

    init(store: any ReminderStoring,
         notifications: any ReminderScheduling,
         now: @escaping () -> Date = { .now },
         calendar: Calendar = .current,
         locale: Locale = .current) {
        self.store = store
        self.notifications = notifications
        self.now = now
        self.calendar = calendar
        self.locale = locale
    }

    func execute(text: String) async -> Output {
        let current = now()
        switch ReminderParser.parse(text, now: current, calendar: calendar) {
        case .reminder(let title, let rule):
            return await create(title: title, rule: rule, at: current)
        case .missingTime(let title):
            return .needsTime(title: title, question: ReminderPhrasing.timeQuestion(title: title))
        case .notAReminder:
            return .notAReminder
        }
    }

    /// Melengkapi reminder yang tadi ditanyakan jamnya. nil bila `text` bukan
    /// ungkapan waktu saja — pemanggil lalu memperlakukannya sebagai pesan biasa.
    func complete(title: String?, timeText text: String) async -> Output? {
        let current = now()
        guard let rule = ReminderParser.parseTimeOnly(text, now: current, calendar: calendar) else {
            return nil
        }
        return await create(title: title ?? ReminderParser.defaultTitle, rule: rule, at: current)
    }

    private func create(title: String, rule: Reminder.Rule, at current: Date) async -> Output {
        let reminder = Reminder(title: title, rule: rule, createdAt: current)
        store.add(reminder)
        await notifications.sync(store.reminders, now: current)
        let confirmation = ReminderPhrasing.confirmation(title: title, rule: rule, now: current,
                                                         calendar: calendar, locale: locale)
        return .created(reminder, confirmation: confirmation)
    }
}

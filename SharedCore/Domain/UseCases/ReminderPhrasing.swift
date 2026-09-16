//
//  ReminderPhrasing.swift
//  SharedCore
//
//  Kalimat yang Apl ucapkan saat membuat reminder atau menanyakan jamnya.
//
//  Deterministik, bukan buatan model: konfirmasi adalah bukti bahwa reminder
//  benar-benar ada, jadi tidak boleh dikarang. Selalu menyebut KAPAN, supaya
//  jam yang sudah lewat dan dipindah ke besok langsung terlihat.
//

import Foundation

enum ReminderPhrasing {

    static func confirmation(title: String, rule: Reminder.Rule, now: Date,
                             calendar: Calendar, locale: Locale) -> String {
        let subject = title == ReminderParser.defaultTitle ? "" : " to \(lowercasedFirst(title))"
        return "Done — I'll remind you\(subject) \(when(rule, now: now, calendar: calendar, locale: locale))."
    }

    static func timeQuestion(title: String?) -> String {
        guard let title else { return "What time should I remind you?" }
        return "What time should I remind you to \(lowercasedFirst(title))?"
    }

    /// Jam dalam format locale pengguna ("3:00 PM" di en_US).
    static func time(_ date: Date, calendar: Calendar, locale: Locale) -> String {
        let style = Date.FormatStyle(date: .omitted, time: .shortened, locale: locale,
                                     calendar: calendar, timeZone: calendar.timeZone)
        return date.formatted(style)
    }

    private static func when(_ rule: Reminder.Rule, now: Date, calendar: Calendar, locale: Locale) -> String {
        switch rule {
        case .daily(let hour, let minute):
            let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
            return "every day at \(time(date, calendar: calendar, locale: locale))"

        case .once(let date):
            let clock = time(date, calendar: calendar, locale: locale)
            let interval = date.timeIntervalSince(now)
            if interval > 0, interval <= 3600 {
                let minutes = max(1, Int((interval / 60).rounded()))
                return "in \(minutes) \(minutes == 1 ? "minute" : "minutes") (\(clock))"
            }
            if calendar.isDate(date, inSameDayAs: now) {
                return "today at \(clock)"
            }
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
               calendar.isDate(date, inSameDayAs: tomorrow) {
                return "tomorrow at \(clock)"
            }
            // Tidak dihasilkan parser hari ini; ada untuk reminder yang diedit di B.
            let dayStyle = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
                .month(.abbreviated)
                .day()
            return "on \(date.formatted(dayStyle)) at \(clock)"
        }
    }

    private static func lowercasedFirst(_ text: String) -> String {
        text.prefix(1).lowercased() + String(text.dropFirst())
    }
}

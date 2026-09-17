//
//  ReminderDraft.swift
//  Apl
//
//  Isian editor reminder di popover: judul, waktu, dan sekali/harian (spec B §5).
//

import Foundation

struct ReminderDraft: Equatable {

    enum Frequency: Hashable, CaseIterable {
        case once
        case daily
    }

    var title: String
    /// Tanggal dan jam untuk `.once`; untuk `.daily` hanya jam dan menitnya yang dipakai.
    var time: Date
    var frequency: Frequency

    init(_ reminder: Reminder, now: Date, calendar: Calendar) {
        title = reminder.title
        switch reminder.rule {
        case .once(let date):
            time = date
            frequency = .once
        case .daily(let hour, let minute):
            time = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
            frequency = .daily
        }
    }

    /// Reminder yang diperbarui dengan id yang sama, atau nil bila isian belum
    /// bisa disimpan: judul kosong, atau reminder sekali jalan di waktu lampau.
    func applied(to reminder: Reminder, now: Date, calendar: Calendar) -> Reminder? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return nil }

        var updated = reminder
        updated.title = trimmedTitle
        switch frequency {
        case .once:
            // DatePicker membawa detik dari nilai awal; reminder selalu tepat di menitnya.
            let minute = calendar.dateInterval(of: .minute, for: time)?.start ?? time
            guard minute > now else { return nil }
            updated.rule = .once(minute)
        case .daily:
            let parts = calendar.dateComponents([.hour, .minute], from: time)
            updated.rule = .daily(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
        }
        return updated
    }
}

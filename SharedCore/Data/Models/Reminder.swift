//
//  Reminder.swift
//  SharedCore
//
//  Reminder yang dibuat pengguna lewat chat.
//
//  Menggantikan ReminderSchedule, yang hanya menyimpan jam dan menit sehingga
//  "remind me at 3 PM" diam-diam berulang setiap hari (spec A §1).
//

import Foundation

struct Reminder: Codable, Equatable, Identifiable, Sendable {

    enum Rule: Codable, Equatable, Sendable {
        /// Sekali jalan, pada tanggal dan jam tertentu.
        case once(Date)
        /// Setiap hari pada jam dan menit yang sama.
        case daily(hour: Int, minute: Int)
    }

    let id: UUID
    var title: String
    var rule: Rule
    let createdAt: Date

    init(id: UUID = UUID(), title: String, rule: Rule, createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.rule = rule
        self.createdAt = createdAt
    }

    /// Kemunculan berikutnya SETELAH `now`.
    ///
    /// `.once` yang sudah lewat → nil. `.daily` → hari ini bila jamnya belum
    /// lewat, selain itu besok. Tepat di menit yang sama dianggap sudah lewat.
    func nextOccurrence(after now: Date, calendar: Calendar = .current) -> Date? {
        switch rule {
        case .once(let date):
            return date > now ? date : nil
        case .daily(let hour, let minute):
            guard let today = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) else {
                return nil
            }
            return today > now ? today : calendar.date(byAdding: .day, value: 1, to: today)
        }
    }
}

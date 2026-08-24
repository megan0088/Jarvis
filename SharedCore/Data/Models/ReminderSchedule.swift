//
//  ReminderSchedule.swift
//  SharedCore
//

import Foundation

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

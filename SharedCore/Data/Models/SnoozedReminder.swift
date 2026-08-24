//
//  SnoozedReminder.swift
//  SharedCore
//

import Foundation

struct SnoozedReminder: Codable {
    var key: String
    var kind: ReminderKind
    var fireDate: Date
}

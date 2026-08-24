//
//  ReminderEvent.swift
//  SharedCore
//

import Foundation

struct ReminderEvent: Codable, Equatable, Identifiable {
    var id: String
    var kind: ReminderKind
    var date: Date
    var message: String
    var wasCompleted: Bool = false
}

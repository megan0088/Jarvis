//
//  ScreenTimeEntry.swift
//  SharedCore
//

import Foundation

struct ScreenTimeEntry: Codable, Identifiable {
    var date: Date
    var duration: TimeInterval

    var id: Date { Calendar.current.startOfDay(for: date) }
}

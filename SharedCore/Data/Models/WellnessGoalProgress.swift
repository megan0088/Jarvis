//
//  WellnessGoalProgress.swift
//  SharedCore
//

import Foundation

struct WellnessGoalProgress: Codable, Equatable {
    var date: Date
    var water: Int
    var stretch: Int
    var meal: Int
}

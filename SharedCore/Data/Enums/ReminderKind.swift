//
//  ReminderKind.swift
//  SharedCore
//

import Foundation

enum ReminderKind: String, CaseIterable, Codable, Identifiable {
    case water
    case stretch
    case meal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .water: "Hydration"
        case .stretch: "Stretching"
        case .meal: "Meals"
        }
    }

    var icon: String {
        switch self {
        case .water: "drop.fill"
        case .stretch: "figure.cooldown"
        case .meal: "fork.knife"
        }
    }

    var researchNote: String {
        switch self {
        case .water:
            "NHS recommends about 6-8 glasses of fluid a day. Apl default: a reminder every 2 hours."
        case .stretch:
            "AHA recommends moving at least every 30 minutes when sitting a lot. Apl default: a reminder every 45 minutes."
        case .meal:
            "Heart-healthy nutrition guidelines recommend regular meals throughout the day. Apl default: breakfast, lunch, dinner."
        }
    }
}

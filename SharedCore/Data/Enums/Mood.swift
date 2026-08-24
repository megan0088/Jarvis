//
//  Mood.swift
//  SharedCore
//

import Foundation

enum Mood: String, CaseIterable, Codable {
    case happy, calm, hungry, sleepy, angry

    var label: String {
        switch self {
        case .happy: "Laughing"
        case .calm: "Ready"
        case .hungry: "Hungry"
        case .sleepy: "Sleepy"
        case .angry: "Angry"
        }
    }

    var emoji: String {
        switch self {
        case .happy: "😂"
        case .calm: "😌"
        case .hungry: "😋"
        case .sleepy: "🥱"
        case .angry: "😤"
        }
    }
}

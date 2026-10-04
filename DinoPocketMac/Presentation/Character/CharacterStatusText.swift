//
//  CharacterStatusText.swift
//  Apl
//
//  Kalimat di bawah nama robot dan label VoiceOver-nya (spec B §5, §7).
//

import Foundation

enum CharacterStatusText {

    static func text(for behavior: CharacterBehavior,
                     now: Date,
                     calendar: Calendar = .current,
                     locale: Locale = .current,
                     intelligenceAvailable: Bool,
                     celebratedTime: Date?) -> String {
        switch behavior {
        case .idle:
            return "Here when you need me"
        case .greet:
            return greeting(at: now, calendar: calendar)
        case .thinking:
            return "Thinking…"
        case .celebrate:
            guard let celebratedTime else { return "Reminder set" }
            return "Reminder set for \(ReminderPhrasing.time(celebratedTime, calendar: calendar, locale: locale))"
        case .sleepy:
            // Robot juga tertidur sesaat setelah jawaban gagal. Menyebut Apple
            // Intelligence mati di situ akan menyuruh pengguna memperbaiki
            // hal yang tidak rusak.
            return intelligenceAvailable ? "Something went wrong" : "Apple Intelligence is off"
        }
    }

    static func greeting(at date: Date, calendar: Calendar) -> String {
        switch calendar.component(.hour, from: date) {
        case ..<12: "Good morning!"
        case ..<18: "Good afternoon!"
        default: "Good evening!"
        }
    }

    static func accessibilityLabel(for behavior: CharacterBehavior) -> String {
        switch behavior {
        case .idle: "Apl, idle"
        case .greet: "Apl, saying hello"
        case .thinking: "Apl, thinking"
        case .celebrate: "Apl, celebrating"
        case .sleepy: "Apl, sleepy"
        }
    }
}

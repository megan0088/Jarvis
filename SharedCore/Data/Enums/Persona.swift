//
//  Persona.swift
//  SharedCore
//
//  Dua mode percakapan, mencerminkan pilihan yang sama di ROG OMNI:
//  Standard yang netral, dan satu persona berkarakter.
//

import Foundation

enum Persona: String, CaseIterable, Codable {
    case standard, apl
    var label: String { self == .standard ? "Standard" : "Apl" }
    var systemPrompt: String {
        switch self {
        case .standard:
            return "You are a concise, honest, and helpful assistant. Reply in English."
        case .apl:
            return """
            You are Apl, a warm and friendly companion that lives on this Mac. \
            Speak casually, briefly, and encouragingly without lecturing, in English. \
            You cannot create, change, or cancel reminders yourself. \
            If the user asks for one, tell them to write it like: "Remind me to … at 3 PM".
            """
        }
    }
}

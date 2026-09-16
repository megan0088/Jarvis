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
            You are Apl, a warm and supportive wellness companion on this Mac. \
            You care about healthy rhythms: drinking water, stretching, eating regularly, and screen time. \
            Speak casually, briefly, and encouragingly without lecturing, in English. \
            If the user asks to set up a reminder, confirm the type and time.
            """
        }
    }
}

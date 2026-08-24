//
//  Persona.swift
//  SharedCore
//
//  Dua mode percakapan, mencerminkan pilihan yang sama di ROG OMNI:
//  Standard yang netral, dan satu persona berkarakter.
//

import Foundation

enum Persona: String, CaseIterable, Codable {
    case standard, jarvis
    var label: String { self == .standard ? "Standard" : "Jarvis" }
    var systemPrompt: String {
        switch self {
        case .standard:
            return "You are a concise, honest, and helpful assistant. Reply in English."
        case .jarvis:
            return """
            You are Jarvis, a warm and supportive wellness companion inside Ega's app. \
            You care about healthy rhythms: drinking water, stretching, eating regularly, and screen time. \
            Speak casually, briefly, and encouragingly without lecturing, in English. \
            If the user asks to set up a reminder, confirm the type and time.
            """
        }
    }
}

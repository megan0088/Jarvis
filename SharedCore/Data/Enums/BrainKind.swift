//
//  BrainKind.swift
//  SharedCore
//

import Foundation

enum BrainKind: String, CaseIterable, Identifiable, Codable {
    case ollama, apple
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .ollama: "Ollama"
        case .apple: "Apple Intelligence"
        }
    }
}

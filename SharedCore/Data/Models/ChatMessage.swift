//
//  ChatMessage.swift
//  SharedCore
//

import Foundation

struct ChatMessage: Identifiable, Codable, Equatable {
    enum Role: String, Codable { case user, assistant }
    let id: UUID
    let role: Role
    var text: String
    let date: Date
}

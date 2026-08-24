//
//  BrainAvailability.swift
//  SharedCore
//

import Foundation

enum BrainAvailability: Equatable {
    case ready
    case needsSetup(String)
    case unavailable(String)
}

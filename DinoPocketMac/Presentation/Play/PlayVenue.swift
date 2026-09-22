//
//  PlayVenue.swift
//  Apl
//
//  Di mana ronde berlangsung (spec F §2 #6).
//

enum PlayVenue: Equatable {
    case balloon, chat

    static func decide(buddyIsRunning: Bool) -> PlayVenue {
        buddyIsRunning ? .balloon : .chat
    }
}

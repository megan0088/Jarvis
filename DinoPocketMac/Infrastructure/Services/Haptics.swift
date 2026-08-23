//
//  Haptics.swift
//  Jarvis
//
//  Created by Codex on 13/03/26.
//

import Foundation

enum Haptics {
    static func squish() {
        #if os(iOS)
        impact(style: .soft)
        #endif
    }
    static func pet() {
        #if os(iOS)
        impact(style: .light)
        #endif
    }
    static func feed() {
        #if os(iOS)
        notify(.success)
        #endif
    }
    static func rest() {
        #if os(iOS)
        impact(style: .medium)
        #endif
    }
    static func heartbeat() {
        #if os(iOS)
        impact(style: .rigid)
        #endif
    }
}

#if os(iOS)
import UIKit

private extension Haptics {
    static func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}
#endif

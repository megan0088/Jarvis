//
//  IdleTimeService.swift
//  AplMac
//

import Foundation
import CoreGraphics

/// Membaca idle time sistem lewat CoreGraphics.
///
/// Sengaja TIDAK memakai `NSWorkspace.frontmostApplication`, yang juga berfungsi:
/// melacak app mana yang sedang dipakai adalah pengawasan, dan ritme istirahat
/// sepenuhnya bisa disimpulkan dari idle time — tahu KAPAN user di meja tanpa
/// tahu APA yang dikerjakan. Manfaat penuh, nol biaya privasi.
struct IdleTimeService: IdleTimeProviding {
    var secondsSinceLastInput: TimeInterval {
        let anyInput = CGEventType(rawValue: ~0) ?? .null
        return CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: anyInput)
    }
}

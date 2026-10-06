//
//  BellBadge.swift
//  Apl (iPhone)
//
//  Angka di tombol lonceng (spec H §4.1).
//

import Foundation

enum BellBadge {

    /// `nil` berarti tanpa lencana.
    static func text(upcomingCount: Int) -> String? {
        guard upcomingCount > 0 else { return nil }
        return upcomingCount > 99 ? "99+" : String(upcomingCount)
    }

    static func accessibilityLabel(upcomingCount: Int) -> String {
        upcomingCount > 0 ? "Reminders, \(upcomingCount) upcoming" : "Reminders"
    }
}

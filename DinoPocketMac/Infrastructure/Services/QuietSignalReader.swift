//
//  QuietSignalReader.swift
//  Apl
//
//  Membaca keadaan yang membungkam Apl (spec C2 §4) — tanpa satu pun izin baru.
//

import AppKit

@MainActor
struct QuietSignalReader {

    var isBuddyRunning: () -> Bool
    var isQuickAskOpen: () -> Bool
    var isNudgeOnScreen: () -> Bool
    var isGameOnScreen: () -> Bool

    func read() -> QuietSignals {
        QuietSignals(
            otherAppIsFullScreen: Self.frontmostAppIsFullScreen(),
            screenIsAsleepOrLocked: Self.screenIsAsleepOrLocked(),
            aplIsFrontmost: NSApp.isActive,
            quickAskIsOpen: isQuickAskOpen(),
            buddyIsRunning: isBuddyRunning(),
            aNudgeIsOnScreen: isNudgeOnScreen(),
            aGameIsOnScreen: isGameOnScreen()
        )
    }

    /// Jendela layar penuh berukuran PERSIS sebesar layarnya, termasuk area
    /// menu bar; jendela yang di-zoom hanya sebesar `visibleFrame`.
    ///
    /// Ukurannya yang dibandingkan, bukan posisinya: `CGWindowList` memakai
    /// koordinat ber-origin kiri-atas sedangkan `NSScreen` kiri-bawah, dan
    /// menyamakan keduanya hanya menambah satu cara untuk salah.
    static func frontmostAppIsFullScreen() -> Bool {
        guard let front = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              front != ProcessInfo.processInfo.processIdentifier,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                       kCGNullWindowID) as? [[String: Any]]
        else { return false }

        let screenSizes = NSScreen.screens.map(\.frame.size)
        for window in windows {
            guard window[kCGWindowOwnerPID as String] as? pid_t == front,
                  window[kCGWindowLayer as String] as? Int == 0,
                  let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary)
            else { continue }
            if screenSizes.contains(where: { $0 == rect.size }) { return true }
        }
        return false
    }

    static func screenIsAsleepOrLocked() -> Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        let locked = session["CGSSessionScreenIsLocked"] as? Int == 1
        let onConsole = session["kCGSSessionOnConsoleKey"] as? Int != 0
        return locked || !onConsole
    }
}

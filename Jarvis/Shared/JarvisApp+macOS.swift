//
//  JarvisApp+macOS.swift
//  Jarvis
//

#if os(macOS)
import AppKit

extension JarvisApp {
    func toggleBuddyMode() {
        isBuddyMode.toggle()
    }

    func dismissFromBuddy() {
        JarvisBuddyWindowController.shared.stopBuddyMode()
        isBuddyMode = false
    }

    func hidePrimaryWindows() {
        for window in NSApp.windows where window !== JarvisBuddyWindowController.shared.window {
            window.orderOut(nil)
        }
    }

    func showPrimaryWindows() {
        for window in NSApp.windows where window !== JarvisBuddyWindowController.shared.window {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
#endif

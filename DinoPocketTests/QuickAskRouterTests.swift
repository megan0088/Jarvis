import Testing
@testable import Apl

struct QuickAskRouterTests {

    /// Buddy bersifat aditif — jendela utama TIDAK disembunyikan saat robot
    /// hidup, jadi kedua kondisi bisa benar bersamaan dan urutannya menentukan.
    @Test func frontmostMainWindowWinsOverBuddy() {
        #expect(QuickAskRouter.action(mainWindowIsFrontmost: true, buddyIsRunning: true)
                == .focusComposer)
    }

    @Test func buddyRunningBehindOtherAppsOpensTheBubble() {
        #expect(QuickAskRouter.action(mainWindowIsFrontmost: false, buddyIsRunning: true)
                == .toggleBubble)
    }

    @Test func withoutBuddyTheShortcutBringsTheWindow() {
        #expect(QuickAskRouter.action(mainWindowIsFrontmost: false, buddyIsRunning: false)
                == .openMainWindow)
    }

    @Test func frontmostWindowWithoutBuddyStillJustFocuses() {
        #expect(QuickAskRouter.action(mainWindowIsFrontmost: true, buddyIsRunning: false)
                == .focusComposer)
    }
}

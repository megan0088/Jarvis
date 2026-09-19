//
//  AplApp+macOS.swift
//  Apl
//

import AppKit

extension AplApp {
    func toggleBuddyMode() {
        isBuddyMode.toggle()
    }

    func dismissFromBuddy() {
        AplBuddyWindowController.shared.stopBuddyMode()
        isBuddyMode = false
    }

    /// Satu tombol, tiga arti (spec C1 §3). Keputusannya milik `QuickAskRouter`;
    /// di sini hanya pelaksanaannya.
    func handleQuickAskShortcut() {
        switch QuickAskRouter.action(mainWindowIsFrontmost: Self.mainWindowIsFrontmost,
                                     buddyIsRunning: isBuddyMode) {
        case .focusComposer:
            composerFocus.request()
        case .toggleBubble:
            // Robot hidup tapi belum punya frame: lebih baik membuka jendela
            // daripada tidak terjadi apa-apa.
            if !QuickAskPanelController.shared.toggle() {
                bringMainWindowForward()
            }
        case .openMainWindow:
            bringMainWindowForward()
        }
    }

    func bringMainWindowForward() {
        NSApp.activate()
        Self.mainWindow?.makeKeyAndOrderFront(nil)
        composerFocus.request()
    }

    /// Jendela utama adalah satu-satunya jendela biasa app ini: panel Buddy dan
    /// panel bubble keduanya `NSPanel`, dan Settings punya kelas sendiri.
    static var mainWindow: NSWindow? {
        NSApp.windows.first { $0.isVisible && !($0 is NSPanel) && $0.canBecomeMain }
    }

    static var mainWindowIsFrontmost: Bool {
        NSApp.isActive && NSApp.keyWindow != nil && NSApp.keyWindow === mainWindow
    }

    // `hidePrimaryWindows()` / `showPrimaryWindows()` dihapus di sini.
    //
    // Dulu Buddy Mode menyembunyikan jendela utama — masuk akal selama mode itu
    // dinyalakan manual. Begitu ia menyala sendiri saat dashboard tampil, arti
    // penyembunyian itu berubah: setiap kali app dibuka, dashboard langsung
    // lenyap. Dan satu-satunya jalan keluar adalah Esc lewat
    // `NSEvent.addLocalMonitorForEvents`, monitor LOKAL yang hanya menerima
    // event saat app ini aktif — padahal jendela yang bisa menerima fokus baru
    // saja disembunyikan. Kombinasinya adalah app yang tampak hilang.
    //
    // Buddy sekarang aditif: robot hidup di desktop, dashboard tetap ada.
    // Itu juga yang dijanjikan layar onboarding.
}

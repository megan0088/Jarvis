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

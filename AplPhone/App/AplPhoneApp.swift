//
//  AplPhoneApp.swift
//  Apl (iPhone)
//
//  Titik masuk companion iPhone (spec H). Satu-satunya berkas yang menyentuh
//  UIApplication: membuka Settings sistem adalah urusan app, bukan view.
//

import SwiftUI
import UIKit

@main
struct AplPhoneApp: App {
    /// Satu-satunya tempat implementasi konkret dipilih.
    private static let deps = PhoneDependencies.live()

    init() {
        // Tanpa delegate, reminder yang jatuh tempo saat Apl di depan tidak
        // ditampilkan sama sekali.
        ReminderNotificationCenter.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            PhoneRootView(profile: Self.deps.profile,
                          chat: Self.deps.chat,
                          reminders: Self.deps.reminders,
                          cache: Self.deps.characterCache,
                          requestNotifications: { await Self.deps.requestNotifications() },
                          eraseAllData: { await Self.deps.eraseAllData() },
                          onOpenSystemSettings: { Self.openSystemSettings() })
                .tint(PhoneColor.accent)
                .task {
                    // Kelima ekspresi dimuat di awal, supaya pergantian wajah
                    // pertama pun tidak menunggu disk.
                    await Self.deps.characterCache.preload(.robot)
                }
        }
    }

    private static func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

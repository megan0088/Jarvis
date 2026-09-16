//
//  AplApp.swift
//  Apl
//
//  Created by Codex on 13/03/26.
//

import SwiftUI

@main
struct AplApp: App {
    /// Satu-satunya tempat implementasi konkret dipilih.
    private static let deps = AppDependencies.live()

    @State private var chat = deps.makeChatStore()
    @State private var buddySettings = deps.buddySettings
    @State private var profile = deps.profile

    @State var isBuddyMode = false

    init() {
        ReminderNotificationCenter.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            rootView
                .task {
                    chat.createReminder = Self.deps.makeCreateReminderUseCase()
                }
        }
        // Modifier Scene, bukan View. Tanpa ini jendela memakai ukuran bawaan
        // yang bisa memotong sidebar dan halaman chat.
        .defaultSize(width: 1000, height: 680)
        .windowResizability(.contentMinSize)
    }

    @ViewBuilder
    private var rootView: some View {
        if profile.hasCompletedOnboarding {
            dashboard
        } else {
            OnboardingView(profile: profile, chat: chat,
                           onNotificationsGranted: {
                               // Reminder yang dibuat sebelum izin diberikan baru bisa dijadwalkan sekarang.
                               await Self.deps.reminderScheduler.sync(Self.deps.reminderStore.reminders, now: .now)
                           })
        }
    }

    @ViewBuilder
    private var dashboard: some View {
        DashboardTemplate(
            chat: chat,
            buddySettings: buddySettings,
            profile: profile,
            extraErasableStores: Self.deps.erasableStores,
            onBuddyMode: toggleBuddyMode,
            isBuddyModeActive: isBuddyMode
        )
        // Setiap preferensi buddy diterapkan langsung tanpa memulai ulang mode,
        // supaya kontrol di Settings terasa hidup saat digeser.
        .onChange(of: buddySettings.size) { _, value in
            guard isBuddyMode else { return }
            AplBuddyWindowController.shared.updateCharacterSize(CGFloat(value))
        }
        .onChange(of: buddySettings.opacity) { _, value in
            guard isBuddyMode else { return }
            AplBuddyWindowController.shared.apply(opacity: value)
        }
        .onChange(of: buddySettings.keepOnTop) { _, value in
            guard isBuddyMode else { return }
            AplBuddyWindowController.shared.apply(keepOnTop: value)
        }
        .onChange(of: buddySettings.strolling) { _, value in
            guard isBuddyMode else { return }
            AplBuddyWindowController.shared.apply(strolling: value)
        }
        .onChange(of: isBuddyMode) { _, active in
            if active {
                AplBuddyWindowController.shared.startBuddyMode(
                    settings: buddySettings,
                    onDismiss: { dismissFromBuddy() }
                )
            } else {
                AplBuddyWindowController.shared.stopBuddyMode()
            }
        }
        // Buddy Mode menyala sendiri begitu dashboard tampil.
        //
        // Dijalankan sekali per kemunculan dashboard; menyalakan ulang saat
        // sudah aktif akan membangun ulang jendelanya tanpa alasan.
        .task {
            guard !isBuddyMode else { return }
            isBuddyMode = true
        }
    }
}

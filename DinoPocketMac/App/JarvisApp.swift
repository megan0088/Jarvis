//
//  JarvisApp.swift
//  Jarvis
//
//  Created by Codex on 13/03/26.
//

import SwiftUI

@main
struct JarvisApp: App {
    /// Satu-satunya tempat implementasi konkret dipilih.
    private static let deps = AppDependencies.live()

    @State private var wellness = deps.makeWellnessViewModel()
    @State private var chat = deps.makeChatStore()
    @State private var buddySettings = deps.buddySettings
    @State private var account = deps.account

    @Environment(\.scenePhase) private var scenePhase
    @State var isBuddyMode = false

    init() {
        WellnessNotificationCenter.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            rootView
                .task {
                    chat.createReminder = wellness.makeCreateReminderUseCase()
                    await wellness.prepare()
                    await account.refreshCredentialState()
                }
        }
        // Modifier Scene, bukan View. Tanpa ini jendela memakai ukuran bawaan
        // yang bisa memotong grid kartu dan sidebar. 1000×680 memuat dua kolom
        // LazyVGrid(.adaptive(minimum: 260)) plus sidebar 190pt dengan lega.
        .defaultSize(width: 1000, height: 680)
        .windowResizability(.contentMinSize)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                wellness.resumeSession()
                Task { await wellness.syncReminderHistory() }
            case .inactive, .background:
                wellness.pauseSession()
                if phase == .background { wellness.tick() }
            @unknown default:
                break
            }
        }
    }

    @ViewBuilder
    private var rootView: some View {
        if account.isSignedIn && account.hasCompletedOnboarding {
            dashboard
        } else {
            OnboardingView(account: account, chat: chat)
        }
    }

    @ViewBuilder
    private var dashboard: some View {
        DashboardTemplate(
            wellness: wellness,
            chat: chat,
            buddySettings: buddySettings,
            account: account,
            extraErasableStores: Self.deps.erasableStores,
            onBuddyMode: toggleBuddyMode,
            isBuddyModeActive: isBuddyMode
        )
        // Setiap preferensi buddy diterapkan langsung tanpa memulai ulang mode,
        // supaya kontrol di Settings terasa hidup saat digeser.
        .onChange(of: buddySettings.size) { _, value in
            guard isBuddyMode else { return }
            JarvisBuddyWindowController.shared.updateCharacterSize(CGFloat(value))
        }
        .onChange(of: buddySettings.opacity) { _, value in
            guard isBuddyMode else { return }
            JarvisBuddyWindowController.shared.apply(opacity: value)
        }
        .onChange(of: buddySettings.keepOnTop) { _, value in
            guard isBuddyMode else { return }
            JarvisBuddyWindowController.shared.apply(keepOnTop: value)
        }
        .onChange(of: buddySettings.strolling) { _, value in
            guard isBuddyMode else { return }
            JarvisBuddyWindowController.shared.apply(strolling: value)
        }
        .onChange(of: isBuddyMode) { _, active in
            if active {
                JarvisBuddyWindowController.shared.startBuddyMode(
                    settings: buddySettings,
                    onDismiss: { dismissFromBuddy() }
                )
                hidePrimaryWindows()
            } else {
                JarvisBuddyWindowController.shared.stopBuddyMode()
                showPrimaryWindows()
            }
        }
    }
}

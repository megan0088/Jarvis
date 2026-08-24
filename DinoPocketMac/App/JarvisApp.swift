//
//  JarvisApp.swift
//  Jarvis
//
//  Created by Codex on 13/03/26.
//

import SwiftUI

@main
struct JarvisApp: App {
    @State private var store = PetStore()
    // Rilis: HANYA Apple Intelligence. Ollama butuh localhost, sementara build ini
    // menyetel ENABLE_OUTGOING_NETWORK_CONNECTIONS = NO — menyertakannya berarti
    // menawarkan opsi yang pasti gagal, dan app yang bergantung pada software
    // eksternal berisiko ditolak App Review.
    #if DEBUG
    @State private var chat = ChatStore(brains: [.apple: AppleBrain(), .ollama: OllamaBrain()])
    #else
    @State private var chat = ChatStore(brains: [.apple: AppleBrain()])
    #endif
    @Environment(\.scenePhase) private var scenePhase
    @State var isBuddyMode = false
    @State private var buddySettings = BuddySettingsStore()
    @State private var account = AccountStore()

    init() {
        WellnessNotificationCenter.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            rootView
                .task {
                    chat.onCreateReminder = { [store] schedule in store.addCustomSchedule(schedule) }
                    await store.prepareWellness()
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
                store.resumeScreenTime()
                Task { await store.syncReminderHistory() }
            case .inactive, .background:
                store.pauseScreenTime()
                if phase == .background { store.tick() }
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
            store: store,
            chat: chat,
            buddySettings: buddySettings,
            account: account,
            onBuddyMode: toggleBuddyMode,
            isBuddyModeActive: isBuddyMode
        )
        .onChange(of: buddySettings.size) { _, newSize in
            guard isBuddyMode else { return }
            JarvisBuddyWindowController.shared.updateCharacterSize(CGFloat(newSize))
        }
        .onChange(of: isBuddyMode) { _, active in
            if active {
                JarvisBuddyWindowController.shared.startBuddyMode(
                    store: store,
                    size: CGFloat(buddySettings.size),
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

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
    @State private var chat = ChatStore(brains: [.ollama: OllamaBrain(), .apple: AppleBrain()])
    @Environment(\.scenePhase) private var scenePhase
    @State var isBuddyMode = false

    init() {
        WellnessNotificationCenter.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            rootView
                .task {
                    chat.onCreateReminder = { [store] schedule in store.addCustomSchedule(schedule) }
                    await store.prepareWellness()
#if os(macOS)
                    // Temporary diagnostic hook: JARVIS_AUTO_BUDDY=1 opens Buddy Mode on launch.
                    if ProcessInfo.processInfo.environment["JARVIS_AUTO_BUDDY"] == "1" {
                        isBuddyMode = true
                    }
#endif
                }
        }
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
#if os(macOS)
        DashboardTemplate(
            store: store,
            chat: chat,
            onBuddyMode: toggleBuddyMode,
            isBuddyModeActive: isBuddyMode
        )
        .onChange(of: isBuddyMode) { _, active in
            if active {
                JarvisBuddyWindowController.shared.startBuddyMode(
                    store: store,
                    onDismiss: { dismissFromBuddy() }
                )
                hidePrimaryWindows()
            } else {
                JarvisBuddyWindowController.shared.stopBuddyMode()
                showPrimaryWindows()
            }
        }
#else
        ContentView(store: store)
#endif
    }
}

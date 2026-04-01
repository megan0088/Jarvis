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
    @Environment(\.scenePhase) private var scenePhase
    @State var isBuddyMode = false

    init() {
        WellnessNotificationCenter.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            rootView
                .task { await store.prepareWellness() }
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
        ContentView(
            store: store,
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

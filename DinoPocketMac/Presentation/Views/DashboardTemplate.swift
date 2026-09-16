//
//  DashboardTemplate.swift
//  Apl
//
//  Template: NavigationSplitView shell — sidebar section switcher plus the
//  detail pages.
//
//  SEMENTARA: bentuk ini hidup di antara sub-project A dan B. Jendela utama
//  chat-first (spec 2026-09-15-apl-main-window-design.md) menggantikannya.
//

import SwiftUI

struct DashboardTemplate: View {
    @Bindable var chat: ChatStore
    @Bindable var buddySettings: BuddySettingsStore
    let profile: ProfileStore
    var extraErasableStores: [any LocallyErasable] = []
    var onBuddyMode: (() -> Void)? = nil
    var isBuddyModeActive: Bool = false

    @State private var selection: DashboardSection = .chat

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection, chat: chat)
                .frame(minWidth: 190)
        } detail: {
            switch selection {
            case .chat:
                ChatPage(chat: chat)
            case .settings:
                SettingsPage(chat: chat, buddySettings: buddySettings, profile: profile,
                             extraErasableStores: extraErasableStores)
            }
        }
        .frame(minWidth: 720, minHeight: 520)
        .toolbar {
            // Satu-satunya jalan menyalakan ulang Buddy setelah ditutup dengan
            // Esc — tombolnya dulu ada di HomePage, yang sudah dihapus.
            ToolbarItem(placement: .primaryAction) {
                Button(isBuddyModeActive ? "Hide Buddy" : "Show Buddy", systemImage: "figure.stand") {
                    onBuddyMode?()
                }
            }
        }
    }
}

#Preview {
    DashboardTemplate(chat: ChatStore(brains: [:]), buddySettings: BuddySettingsStore(), profile: ProfileStore())
}

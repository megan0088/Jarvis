//
//  DashboardTemplate.swift
//  Jarvis
//
//  Template: NavigationSplitView shell — sidebar section switcher plus the
//  detail pages, and the chat sheet reachable from anywhere in the dashboard.
//

import SwiftUI

struct DashboardTemplate: View {
    let wellness: WellnessViewModel
    @Bindable var chat: ChatStore
    @Bindable var buddySettings: BuddySettingsStore
    @Bindable var account: AccountStore
    var onBuddyMode: (() -> Void)? = nil
    var isBuddyModeActive: Bool = false

    @State private var selection: DashboardSection = .home
    @State private var showChat = false

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection, chat: chat)
                .frame(minWidth: 190)
        } detail: {
            switch selection {
            case .home:
                HomePage(wellness: wellness, chat: chat, onBuddyMode: onBuddyMode, showChat: $showChat)
            case .chat:
                ChatPage(chat: chat)
            case .wellness:
                ScrollView {
                    WellnessCard(wellness: wellness)
                        .padding()
                }
                .navigationTitle("Wellness")
            case .history:
                HistoryPage(wellness: wellness)
            case .settings:
                SettingsPage(chat: chat, wellness: wellness, buddySettings: buddySettings, account: account)
            }
        }
        .frame(minWidth: 720, minHeight: 520)
        .sheet(isPresented: $showChat) {
            NavigationStack {
                ChatPage(chat: chat)
            }
            .frame(minWidth: 420, minHeight: 520)
        }
    }
}

#Preview {
    DashboardTemplate(wellness: .preview, chat: ChatStore(brains: [:]), buddySettings: BuddySettingsStore(), account: AccountStore())
}

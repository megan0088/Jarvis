//
//  DashboardTemplate.swift
//  Jarvis
//
//  Template: NavigationSplitView shell — sidebar section switcher plus the
//  detail pages, and the chat sheet reachable from anywhere in the dashboard.
//

#if os(macOS)
import SwiftUI

struct DashboardTemplate: View {
    @Bindable var store: PetStore
    @Bindable var chat: ChatStore
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
                HomePage(store: store, chat: chat, onBuddyMode: onBuddyMode, showChat: $showChat)
            case .chat:
                ChatPage(chat: chat)
            case .wellness:
                ScrollView {
                    WellnessCard(store: store)
                        .padding()
                }
                .navigationTitle("Wellness")
            case .history:
                Text("History coming soon.")
                    .foregroundStyle(.secondary)
                    .navigationTitle("History")
            case .settings:
                SettingsPage(chat: chat)
            }
        }
        .sheet(isPresented: $showChat) {
            NavigationStack {
                ChatPage(chat: chat)
            }
            .frame(minWidth: 420, minHeight: 520)
        }
    }
}

#Preview {
    DashboardTemplate(store: PetStore(), chat: ChatStore(brains: [:]))
}
#endif

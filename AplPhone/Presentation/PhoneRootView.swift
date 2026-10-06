//
//  PhoneRootView.swift
//  Apl (iPhone)
//
//  Akar tampilan: onboarding atau layar utama, beserta dua sheet-nya.
//

import SwiftUI

struct PhoneRootView: View {
    let profile: ProfileStore
    let chat: ChatStore
    let reminders: ReminderListViewModel
    let cache: CharacterExpressionCache
    let requestNotifications: () async -> Bool
    let eraseAllData: () async -> Void
    let onOpenSystemSettings: () -> Void

    @State private var showsReminders = false
    @State private var showsSettings = false

    var body: some View {
        PhoneHomeView(chat: chat, reminders: reminders, cache: cache,
                      onOpenReminders: { showsReminders = true },
                      onOpenSettings: { showsSettings = true },
                      onOpenSystemSettings: onOpenSystemSettings)
            .sheet(isPresented: $showsReminders) {
                Text("Reminders")   // diganti di Task 7
            }
            .sheet(isPresented: $showsSettings) {
                Text("Settings")    // diganti di Task 8
            }
    }
}

#Preview("Root") {
    PhoneRootView(profile: .preview(), chat: .preview(), reminders: .preview(),
                  cache: CharacterExpressionCache(),
                  requestNotifications: { true }, eraseAllData: {}, onOpenSystemSettings: {})
}

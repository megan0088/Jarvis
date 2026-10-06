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
        Group {
            if profile.hasCompletedOnboarding {
                PhoneHomeView(chat: chat, reminders: reminders, cache: cache,
                              onOpenReminders: { showsReminders = true },
                              onOpenSettings: { showsSettings = true },
                              onOpenSystemSettings: onOpenSystemSettings)
            } else {
                PhoneOnboardingView(profile: profile, chat: chat, cache: cache,
                                    requestNotifications: requestNotifications,
                                    onOpenSystemSettings: onOpenSystemSettings)
            }
        }
        .sheet(isPresented: $showsReminders) {
            PhoneRemindersSheet(viewModel: reminders, onOpenSystemSettings: onOpenSystemSettings)
        }
        .sheet(isPresented: $showsSettings) {
            PhoneSettingsView(profile: profile, chat: chat, eraseAllData: eraseAllData)
        }
    }
}

#Preview("Root") {
    PhoneRootView(profile: .preview(), chat: .preview(), reminders: .preview(),
                  cache: CharacterExpressionCache(),
                  requestNotifications: { true }, eraseAllData: {}, onOpenSystemSettings: {})
}

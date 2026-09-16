//
//  HomePage.swift
//  Apl
//
//  Page: dashboard home — greeting, quick actions, and the metric card grid.
//

import SwiftUI

struct HomePage: View {
    let wellness: WellnessViewModel
    @Bindable var chat: ChatStore
    /// Nama dari Sign in with Apple. `nil` saat user menyembunyikan namanya —
    /// sapaannya lalu jatuh ke bentuk tanpa nama, bukan ke nama orang lain.
    var greetingName: String?
    var onBuddyMode: (() -> Void)?
    @Binding var showChat: Bool

    private let columns = [GridItem(.adaptive(minimum: 260), spacing: Spacing.md)]


    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(greetingName.map { "Hello, \($0)" } ?? "Hello")
                        .font(.largeTitle.weight(.medium))
                    Text("How can I help you today?")
                        .font(.title3)
                        .foregroundStyle(AppColor.accent)
                }

                HStack(spacing: Spacing.sm) {
                    PillButton(title: "Ask Apl", systemImage: "sparkles", isPrimary: true) {
                        showChat = true
                    }
                    PillButton(title: "Buddy Mode", systemImage: "figure.walk") {
                        onBuddyMode?()
                    }
                    PillButton(title: "Summarize my day", systemImage: "text.alignleft") {
                        chat.pendingPrompt = wellness.summaryPrompt
                        showChat = true
                    }
                    PillButton(title: "Set a reminder", systemImage: "bell.badge") {
                        chat.pendingPrompt = "Remind me to "
                        showChat = true
                    }
                }

                LazyVGrid(columns: columns, spacing: Spacing.md) {
                    WellnessCard(wellness: wellness)
                    CharacterCard(wellness: wellness)
                    RemindersCard(wellness: wellness)
                    DeskTimeCard(wellness: wellness)
                }
            }
            .padding()
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                showChat = true
            } label: {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding(Spacing.md)
                    .background(AppColor.accent, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(Spacing.lg)
        }
        .navigationTitle("Home")
    }
}

#Preview {
    NavigationStack {
        HomePage(wellness: .preview, chat: ChatStore(brains: [:]), greetingName: "Ega",
                 onBuddyMode: nil, showChat: .constant(false))
    }
}

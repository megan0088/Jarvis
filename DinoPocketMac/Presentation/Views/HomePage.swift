//
//  HomePage.swift
//  Jarvis
//
//  Page: dashboard home — greeting, quick actions, and the metric card grid.
//

import SwiftUI

struct HomePage: View {
    @Bindable var store: PetStore
    @Bindable var chat: ChatStore
    var onBuddyMode: (() -> Void)?
    @Binding var showChat: Bool

    private let columns = [GridItem(.adaptive(minimum: 260), spacing: Spacing.md)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Hello, Ega")
                        .font(.largeTitle.weight(.medium))
                    Text("How can I help you today?")
                        .font(.title3)
                        .foregroundStyle(AppColor.accent)
                }

                HStack(spacing: Spacing.sm) {
                    PillButton(title: "Ask Jarvis", systemImage: "sparkles", isPrimary: true) {
                        showChat = true
                    }
                    PillButton(title: "Buddy Mode", systemImage: "figure.walk") {
                        onBuddyMode?()
                    }
                    PillButton(title: "Summarize my day", systemImage: "text.alignleft") {
                        showChat = true
                    }
                    PillButton(title: "Set a reminder", systemImage: "bell.badge") {
                        showChat = true
                    }
                }

                LazyVGrid(columns: columns, spacing: Spacing.md) {
                    WellnessCard(store: store)
                    CharacterCard(store: store)
                    RemindersCard(store: store)
                    ScreenTimeCard(store: store)
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
        HomePage(store: PetStore(), chat: ChatStore(brains: [:]), onBuddyMode: nil, showChat: .constant(false))
    }
}

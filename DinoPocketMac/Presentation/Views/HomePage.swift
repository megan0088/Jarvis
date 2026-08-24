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

    /// Angka hari ini disisipkan ke prompt supaya model MERANGKAI data nyata,
    /// bukan mengarang. Model on-device kecil kuat pada tugas seperti ini dan
    /// lemah pada pengetahuan dunia, jadi ringkasan yang di-ground begini adalah
    /// pemakaian terbaiknya.
    private var summaryPrompt: String {
        let desk = HistoryPage.durationText(store.todayScreenTime)
        let g = store.goalProgress
        return """
        Summarize my day so far in two or three warm sentences. \
        Here is what I actually did: \(desk) at my desk, \(g.water) glasses of water, \
        \(g.stretch) stretch breaks, \(g.meal) meals. \
        Only use these numbers; do not invent anything else.
        """
    }

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
                        chat.pendingPrompt = summaryPrompt
                        showChat = true
                    }
                    PillButton(title: "Set a reminder", systemImage: "bell.badge") {
                        chat.pendingPrompt = "Remind me to "
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

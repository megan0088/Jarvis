//
//  RemindersCard.swift
//  Jarvis
//
//  Organism: up to 3 upcoming reminders for the rest of today, from WellnessStore.
//

import SwiftUI

struct RemindersCard: View {
    @Bindable var store: WellnessStore

    private var upcoming: [WellnessStore.ReminderSchedule] {
        let now = Calendar.current.dateComponents([.hour, .minute], from: .now)
        let minutesNow = (now.hour ?? 0) * 60 + (now.minute ?? 0)
        return store.reminderSchedules
            .filter { ($0.hour * 60 + $0.minute) >= minutesNow }
            .sorted { ($0.hour * 60 + $0.minute) < ($1.hour * 60 + $1.minute) }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        DashCard(title: "Reminders", systemImage: "bell") {
            VStack(spacing: Spacing.sm) {
                if upcoming.isEmpty {
                    Text("No more reminders today.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(upcoming) { s in
                        ReminderRow(
                            icon: s.kind.icon,
                            title: s.title,
                            timeLabel: s.timeLabel,
                            onDone: {},
                            onSkip: {}
                        )
                    }
                }
            }
        }
    }
}

#Preview {
    RemindersCard(store: WellnessStore())
        .frame(width: 300)
        .padding()
}

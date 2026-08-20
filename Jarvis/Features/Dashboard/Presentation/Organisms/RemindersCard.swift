//
//  RemindersCard.swift
//  Jarvis
//
//  Organism: up to 3 upcoming reminders for the rest of today, from PetStore.
//

#if os(macOS)
import SwiftUI

struct RemindersCard: View {
    @Bindable var store: PetStore

    private var upcoming: [PetStore.ReminderSchedule] {
        let now = Calendar.current.dateComponents([.hour, .minute], from: .now)
        let minutesNow = (now.hour ?? 0) * 60 + (now.minute ?? 0)
        return store.reminderSchedules
            .filter { ($0.hour * 60 + $0.minute) >= minutesNow }
            .sorted { ($0.hour * 60 + $0.minute) < ($1.hour * 60 + $1.minute) }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        DashCard(title: "Pengingat", systemImage: "bell") {
            VStack(spacing: Spacing.sm) {
                if upcoming.isEmpty {
                    Text("Tidak ada pengingat lagi hari ini.")
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
    RemindersCard(store: PetStore())
        .frame(width: 300)
        .padding()
}
#endif

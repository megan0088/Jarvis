//
//  RemindersCard.swift
//  Apl
//
//  Organism: up to 3 upcoming reminders for the rest of today, from WellnessStore.
//

import SwiftUI

struct RemindersCard: View {
    let wellness: WellnessViewModel

    var body: some View {
        DashCard(title: "Reminders", systemImage: "bell") {
            VStack(spacing: Spacing.sm) {
                let upcoming = wellness.upcomingReminders()
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
                            onDone: { wellness.complete(s) },
                            onSkip: { wellness.snooze(s) }
                        )
                    }
                }

                if !wellness.remindersEnabled {
                    // Baris ini jujur soal keadaan: jadwalnya terlihat, tapi
                    // tanpa saklar menyala tidak ada notifikasi yang berbunyi.
                    Label("Notifications are off — turn them on in Settings.",
                          systemImage: "bell.slash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

#Preview {
    RemindersCard(wellness: .preview)
        .frame(width: 300)
        .padding()
}

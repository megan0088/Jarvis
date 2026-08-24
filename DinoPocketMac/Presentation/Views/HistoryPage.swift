//
//  HistoryPage.swift
//  DinoPocketMac
//
//  Menggantikan placeholder "History coming soon." — App Store Guideline 2.1
//  menolak fungsi yang belum jadi, dan placeholder adalah bentuk paling
//  gamblang dari itu.
//

import SwiftUI

struct HistoryPage: View {
    let wellness: WellnessViewModel

    var body: some View {
        Group {
            if wellness.recentReminderHistory.isEmpty && wellness.recentScreenTimeHistory.isEmpty {
                emptyState
            } else {
                List {
                    if !wellness.recentScreenTimeHistory.isEmpty {
                        Section("Desk time") {
                            ForEach(wellness.recentScreenTimeHistory) { entry in
                                LabeledContent(entry.date.formatted(date: .abbreviated, time: .omitted)) {
                                    Text(Self.durationText(entry.duration))
                                        .font(.body.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    if !wellness.recentReminderHistory.isEmpty {
                        Section("Reminders") {
                            ForEach(wellness.recentReminderHistory) { event in
                                HStack(spacing: 10) {
                                    Image(systemName: event.wasCompleted
                                          ? "checkmark.circle.fill" : "circle.dashed")
                                        .foregroundStyle(event.wasCompleted ? .green : .secondary)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(event.message)
                                        Text(event.date.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Nothing yet",
            systemImage: "clock",
            description: Text("Your desk time and reminders will appear here as you use DinoPocket.")
        )
    }

    /// Jam dan menit; detik tidak berarti apa-apa untuk ritme harian.
    static func durationText(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}

#Preview {
    NavigationStack {
        HistoryPage(wellness: .preview)
    }
}

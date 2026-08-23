//
//  JarvisWidgetLiveActivity.swift
//  JarvisWidget
//

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Mood (must match PetStore.Mood raw values)

enum Mood: String, Codable, Hashable {
    case happy, calm, hungry, sleepy, angry

    var label: String {
        switch self {
        case .happy:  "Laughing"
        case .calm:   "Ready"
        case .hungry: "Hungry"
        case .sleepy: "Sleepy"
        case .angry:  "Angry"
        }
    }

    var emoji: String {
        switch self {
        case .happy:  "😂"
        case .calm:   "😌"
        case .hungry: "😋"
        case .sleepy: "🥱"
        case .angry:  "😤"
        }
    }

    var isUrgent: Bool { self == .hungry || self == .angry }
    var urgentColor: Color { self == .angry ? .red : .orange }
}

// MARK: - PetActivityAttributes (must match main app struct exactly)

struct PetActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var mood: Mood
        var hunger: Int
        var energy: Int
        var waterProgress: Int
        var stretchProgress: Int
        var mealProgress: Int
        var screenTimeMinutes: Int
        var activeReminder: ActiveReminder?

        struct ActiveReminder: Codable, Hashable {
            var kind: ReminderKind
            var title: String
            var body: String
        }

        enum ReminderKind: String, Codable, Hashable {
            case water, stretch, meal

            var emoji: String {
                switch self {
                case .water:   "💧"
                case .stretch: "🧘"
                case .meal:    "🍽️"
                }
            }

            var color: Color {
                switch self {
                case .water:   .cyan
                case .stretch: .orange
                case .meal:    .green
                }
            }
        }
    }
    var name: String
}

// MARK: - Mode 1: Normal Dashboard

private struct NormalView: View {
    let state: PetActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            // Left: mood + wellness goals
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(state.mood.emoji).font(.title2)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Jarvis").font(.headline.bold())
                        Text(state.mood.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                // Wellness row
                HStack(spacing: 10) {
                    goalChip("💧", current: state.waterProgress, max: 6)
                    goalChip("🧘", current: state.stretchProgress, max: 6)
                    goalChip("🍽️", current: state.mealProgress, max: 3)
                }
            }

            Spacer()

            // Right: stats
            VStack(alignment: .trailing, spacing: 6) {
                statBadge("⚡️", value: "\(state.energy)%", color: .yellow)
                statBadge("🍔", value: "Full \(100 - state.hunger)%", color: .green)
                statBadge("📱", value: screenTimeLabel, color: .cyan)
            }
        }
        .padding()
    }

    private var screenTimeLabel: String {
        let h = state.screenTimeMinutes / 60
        let m = state.screenTimeMinutes % 60
        return h > 0 ? "\(h)j\(m)m" : "\(m)m"
    }

    private func goalChip(_ emoji: String, current: Int, max: Int) -> some View {
        HStack(spacing: 2) {
            Text(emoji).font(.system(size: 11))
            Text("\(current)/\(max)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(current >= max ? .green : .secondary)
        }
    }

    private func statBadge(_ icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Text(icon).font(.system(size: 11))
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
        }
    }
}

// MARK: - Mode 2: Reminder Alert

private struct ReminderAlertView: View {
    let reminder: PetActivityAttributes.ContentState.ActiveReminder

    var body: some View {
        VStack(spacing: 10) {
            // Title row
            HStack(spacing: 8) {
                Text(reminder.kind.emoji)
                    .font(.title)
                VStack(alignment: .leading, spacing: 2) {
                    Text(reminder.title)
                        .font(.headline.bold())
                    Text(reminder.body)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }

            // Action buttons
            HStack(spacing: 10) {
                // Complete button
                Button(intent: CompleteReminderIntent(kind: reminder.kind.rawValue)) {
                    Label("Sudah ✓", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 10).fill(reminder.kind.color))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                // Snooze button
                Button(intent: SnoozeReminderIntent(kind: reminder.kind.rawValue)) {
                    Label("10 menit", systemImage: "clock.arrow.circlepath")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }
}

// MARK: - Mode 3: Urgent Mood Takeover

private struct UrgentView: View {
    let state: PetActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            // Big mood emoji + warning
            ZStack {
                Circle()
                    .fill(state.mood.urgentColor.opacity(0.2))
                    .frame(width: 60, height: 60)
                Text(state.mood.emoji)
                    .font(.system(size: 36))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(state.mood.urgentColor)
                    Text(urgentTitle)
                        .font(.headline.bold())
                        .foregroundStyle(state.mood.urgentColor)
                }
                Text(urgentSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Mini progress
                ProgressView(value: Double(100 - state.hunger), total: 100)
                    .tint(state.mood.urgentColor)
                    .frame(maxWidth: 160)
            }

            Spacer()
        }
        .padding()
    }

    private var urgentTitle: String {
        switch state.mood {
        case .hungry: "Jarvis Lapar!"
        case .angry:  "Jarvis Kesal!"
        default:      "Perhatian!"
        }
    }

    private var urgentSubtitle: String {
        switch state.mood {
        case .hungry: "Buka app dan feed Jarvis sekarang"
        case .angry:  "Ajak Jarvis bermain sebentar"
        default:      "Jarvis butuh perhatianmu"
        }
    }
}

// MARK: - Live Activity Widget

struct JarvisWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PetActivityAttributes.self) { context in
            // Lock Screen — dispatch ke 3 mode
            Group {
                if let reminder = context.state.activeReminder {
                    ReminderAlertView(reminder: reminder)
                } else if context.state.mood.isUrgent {
                    UrgentView(state: context.state)
                } else {
                    NormalView(state: context.state)
                }
            }
            .activityBackgroundTint(.clear)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    if let reminder = context.state.activeReminder {
                        Text(reminder.kind.emoji).font(.title2)
                    } else {
                        Label("Full \(100 - context.state.hunger)%", systemImage: "fork.knife")
                            .font(.caption.monospacedDigit())
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let reminder = context.state.activeReminder {
                        Text(reminder.title)
                            .font(.caption.bold())
                            .lineLimit(2)
                    } else {
                        Label("\(context.state.energy)%", systemImage: "bolt.fill")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.yellow)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    if context.state.activeReminder == nil {
                        Text(context.state.mood.emoji + " " + context.state.mood.label)
                            .font(.headline)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let reminder = context.state.activeReminder {
                        HStack(spacing: 8) {
                            Button(intent: CompleteReminderIntent(kind: reminder.kind.rawValue)) {
                                Label("Sudah", systemImage: "checkmark.circle.fill")
                                    .font(.caption.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(reminder.kind.color))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                            Button(intent: SnoozeReminderIntent(kind: reminder.kind.rawValue)) {
                                Label("10m", systemImage: "clock")
                                    .font(.caption)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(.ultraThinMaterial))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)
                    } else {
                        HStack(spacing: 12) {
                            goalPill("💧", v: context.state.waterProgress, max: 6)
                            goalPill("🧘", v: context.state.stretchProgress, max: 6)
                            goalPill("🍽️", v: context.state.mealProgress, max: 3)
                        }
                    }
                }

            } compactLeading: {
                if let reminder = context.state.activeReminder {
                    Text(reminder.kind.emoji)
                } else {
                    Text(context.state.mood.emoji)
                }

            } compactTrailing: {
                if context.state.activeReminder != nil {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                } else if context.state.mood.isUrgent {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(context.state.mood.urgentColor)
                        .font(.caption)
                } else {
                    Text("\(100 - context.state.hunger)%")
                        .font(.caption.monospacedDigit())
                }

            } minimal: {
                if context.state.activeReminder != nil {
                    Image(systemName: "bell.fill").foregroundStyle(.orange)
                } else if context.state.mood.isUrgent {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(context.state.mood.urgentColor)
                } else {
                    Text(context.state.mood.emoji)
                }
            }
        }
    }

    private func goalPill(_ emoji: String, v: Int, max: Int) -> some View {
        Text("\(emoji) \(v)/\(max)")
            .font(.caption2.monospacedDigit())
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(Capsule().fill(v >= max ? Color.green.opacity(0.3) : Color.white.opacity(0.1)))
    }
}

// MARK: - Previews

extension PetActivityAttributes {
    fileprivate static var preview: PetActivityAttributes { .init(name: "Jarvis") }
}

extension PetActivityAttributes.ContentState {
    fileprivate static var normal: Self {
        .init(mood: .calm, hunger: 30, energy: 80, waterProgress: 3, stretchProgress: 2, mealProgress: 1, screenTimeMinutes: 150, activeReminder: nil)
    }
    fileprivate static var reminderWater: Self {
        .init(mood: .calm, hunger: 30, energy: 80, waterProgress: 3, stretchProgress: 2, mealProgress: 1, screenTimeMinutes: 150,
              activeReminder: .init(kind: .water, title: "Waktunya minum air!", body: "Ambil jeda dan minum segelas air."))
    }
    fileprivate static var urgent: Self {
        .init(mood: .hungry, hunger: 90, energy: 50, waterProgress: 1, stretchProgress: 0, mealProgress: 0, screenTimeMinutes: 240, activeReminder: nil)
    }
}

#Preview("Normal", as: .content, using: PetActivityAttributes.preview) {
    JarvisWidgetLiveActivity()
} contentStates: { PetActivityAttributes.ContentState.normal }

#Preview("Reminder", as: .content, using: PetActivityAttributes.preview) {
    JarvisWidgetLiveActivity()
} contentStates: { PetActivityAttributes.ContentState.reminderWater }

#Preview("Urgent", as: .content, using: PetActivityAttributes.preview) {
    JarvisWidgetLiveActivity()
} contentStates: { PetActivityAttributes.ContentState.urgent }

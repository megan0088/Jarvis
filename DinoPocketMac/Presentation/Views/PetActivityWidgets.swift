//
//  PetActivityWidgets.swift
//  Jarvis
//

#if os(iOS)
import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Activity Attributes

struct PetActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var mood: WellnessStore.Mood
        var hunger: Int
        var energy: Int
        // Wellness goals
        var waterProgress: Int
        var stretchProgress: Int
        var mealProgress: Int
        var screenTimeMinutes: Int
        // Active reminder (nil = normal mode)
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
        }
    }

    var name: String
}

// MARK: - Static Widget Provider

private enum AppGroup {
    static let id = "group.com.Jarvis"
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> PetEntry {
        PetEntry(date: .now, mood: .calm, hunger: 20, energy: 80)
    }

    func getSnapshot(in context: Context, completion: @escaping (PetEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PetEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .after(.now.addingTimeInterval(900))))
    }

    private func currentEntry() -> PetEntry {
        let defaults = UserDefaults(suiteName: AppGroup.id) ?? .standard
        let mood = WellnessStore.Mood(rawValue: defaults.string(forKey: "pet.mood") ?? "calm") ?? .calm
        let hunger = defaults.integer(forKey: "pet.hunger")
        let energy = defaults.integer(forKey: "pet.energy")
        return PetEntry(date: .now, mood: mood, hunger: hunger, energy: energy)
    }
}

struct PetEntry: TimelineEntry {
    let date: Date
    let mood: WellnessStore.Mood
    let hunger: Int
    let energy: Int
}

// MARK: - Static Widget

struct PetWidget: Widget {
    let kind: String = "PetWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.mood.emoji + " " + entry.mood.label)
                    .font(.headline)
                ProgressView(value: Double(100 - entry.hunger), total: 100) {
                    Text("Fullness")
                }
                .tint(.green)
                ProgressView(value: Double(entry.energy), total: 100) {
                    Text("Energy")
                }
                .tint(.blue)
            }
            .padding()
            .containerBackground(.thinMaterial, for: .widget)
        }
        .configurationDisplayName("Jarvis")
        .description("Check your desktop friend at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

#endif

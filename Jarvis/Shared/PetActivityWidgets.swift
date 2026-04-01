//
//  PetActivityWidgets.swift
//  Jarvis
//
//  Created by Codex on 13/03/26.
//

#if os(iOS)
import ActivityKit
import WidgetKit
import SwiftUI

struct PetActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var mood: PetStore.Mood
        var hunger: Int
        var energy: Int
    }

    var name: String
}

struct PetLiveActivityView: View {
    let context: ActivityViewContext<PetActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Jarvis")
                    .font(.headline)
                Text(context.state.mood.label)
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(100 - context.state.hunger), total: 100) {
                    Text("Fullness")
                }
                .tint(.green)
            }
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: context.state.mood == .hungry ? "takeoutbag.and.cup.and.straw.fill" : "heart.fill")
                    .font(.title2)
                    .foregroundStyle(.pink)
                Text("Energy \(context.state.energy)%")
                    .font(.caption.monospacedDigit())
            }
        }
        .padding()
    }
}

struct PetWidget: Widget {
    let kind: String = "PetWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.mood.label)
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

struct PetActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PetActivityAttributes.self) { context in
            PetLiveActivityView(context: context)
                .activityBackgroundTint(.clear)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Full \(100 - context.state.hunger)%", systemImage: "fork.knife")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Label("Energy \(context.state.energy)%", systemImage: "bolt.fill")
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.mood.label)
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: Double(100 - context.state.hunger), total: 100)
                        .tint(.green)
                }
            } compactLeading: {
                Image(systemName: "heart.fill")
            } compactTrailing: {
                Text("\(100 - context.state.hunger)%")
            } minimal: {
                Image(systemName: context.state.mood == .hungry ? "exclamationmark.triangle.fill" : "heart.fill")
            }
        }
    }
}

private enum AppGroup {
    static let id = "group.com.example.jarvis"
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
        let mood = PetStore.Mood(rawValue: defaults.string(forKey: "pet.mood") ?? "calm") ?? .calm
        let hunger = defaults.integer(forKey: "pet.hunger")
        let energy = defaults.integer(forKey: "pet.energy")
        return PetEntry(date: .now, mood: mood, hunger: hunger, energy: energy)
    }
}

struct PetEntry: TimelineEntry {
    let date: Date
    let mood: PetStore.Mood
    let hunger: Int
    let energy: Int
}

#endif

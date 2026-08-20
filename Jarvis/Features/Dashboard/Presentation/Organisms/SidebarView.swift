//
//  SidebarView.swift
//  Jarvis
//
//  Organism: dashboard navigation sidebar + active-brain switcher.
//

#if os(macOS)
import SwiftUI

enum DashboardSection: String, CaseIterable, Identifiable {
    case home = "Home"
    case chat = "Jarvis AI"
    case wellness = "Wellness"
    case history = "History"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: "house"
        case .chat: "sparkles"
        case .wellness: "heart"
        case .history: "clock.arrow.circlepath"
        case .settings: "gearshape"
        }
    }
}

struct SidebarView: View {
    @Binding var selection: DashboardSection
    @Bindable var chat: ChatStore

    var body: some View {
        List(selection: $selection) {
            ForEach(DashboardSection.allCases) { section in
                Label(section.rawValue, systemImage: section.icon).tag(section)
            }

            Section {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Label("Active brain", systemImage: "bolt").font(.caption)
                    BrainSegmentedPicker(selection: $chat.activeBrain)
                }
            }
        }
        .listStyle(.sidebar)
    }
}

#Preview {
    SidebarView(selection: .constant(.home), chat: ChatStore(brains: [:]))
        .frame(width: 220, height: 400)
}
#endif

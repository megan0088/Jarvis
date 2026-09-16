//
//  SidebarView.swift
//  Apl
//
//  Organism: dashboard navigation sidebar + active-brain switcher.
//

import SwiftUI

enum DashboardSection: String, CaseIterable, Identifiable {
    case chat = "Apl AI"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .chat: "sparkles"
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
    SidebarView(selection: .constant(.chat), chat: ChatStore(brains: [:]))
        .frame(width: 220, height: 400)
}

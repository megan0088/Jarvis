//
//  SidebarView.swift
//  Apl
//
//  Organism: dashboard navigation sidebar.
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

    var body: some View {
        List(selection: $selection) {
            ForEach(DashboardSection.allCases) { section in
                Label(section.rawValue, systemImage: section.icon).tag(section)
            }
        }
        .listStyle(.sidebar)
    }
}

#Preview {
    SidebarView(selection: .constant(.chat))
        .frame(width: 220, height: 400)
}

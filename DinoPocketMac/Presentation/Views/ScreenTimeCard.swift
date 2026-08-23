//
//  ScreenTimeCard.swift
//  Jarvis
//
//  Organism: today's total screen time from PetStore, formatted "Xj Ym".
//

import SwiftUI

struct ScreenTimeCard: View {
    @Bindable var store: PetStore

    private var todayLabel: String {
        let secs = store.screenTimeHistory.first(where: { Calendar.current.isDateInToday($0.date) })?.duration ?? 0
        let h = Int(secs) / 3600
        let m = (Int(secs) % 3600) / 60
        return "\(h)h \(m)m"
    }

    var body: some View {
        DashCard(title: "Screen time", systemImage: "desktopcomputer") {
            Text(todayLabel)
                .font(.system(size: 26, weight: .medium))
        }
    }
}

#Preview {
    ScreenTimeCard(store: PetStore())
        .frame(width: 300)
        .padding()
}

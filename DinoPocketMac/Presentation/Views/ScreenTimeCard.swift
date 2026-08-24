//
//  ScreenTimeCard.swift
//  Jarvis
//
//  Organism: today's total screen time from WellnessStore, formatted "Xj Ym".
//

import SwiftUI

struct ScreenTimeCard: View {
    let wellness: WellnessViewModel

    private var todayLabel: String {
        let secs = wellness.screenTimeHistory.first(where: { Calendar.current.isDateInToday($0.date) })?.duration ?? 0
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
    ScreenTimeCard(wellness: .preview)
        .frame(width: 300)
        .padding()
}

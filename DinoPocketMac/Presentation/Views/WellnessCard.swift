//
//  WellnessCard.swift
//  Jarvis
//
//  Organism: today's wellness metrics (water/stretch/meal) from WellnessStore.
//

import SwiftUI

struct WellnessCard: View {
    let wellness: WellnessViewModel

    var body: some View {
        DashCard(title: "Today's wellness", systemImage: "target") {
            VStack(spacing: Spacing.md) {
                MetricRow(title: "Water", value: wellness.goalProgress.water, goal: 6, tint: AppColor.water)
                MetricRow(title: "Stretch", value: wellness.goalProgress.stretch, goal: 6, tint: AppColor.stretch)
                MetricRow(title: "Meals", value: wellness.goalProgress.meal, goal: 3, tint: AppColor.meal)
            }
        }
    }
}

#Preview {
    WellnessCard(wellness: .preview)
        .frame(width: 300)
        .padding()
}

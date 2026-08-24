//
//  WellnessCard.swift
//  Jarvis
//
//  Organism: today's wellness metrics (water/stretch/meal) from WellnessStore.
//

import SwiftUI

struct WellnessCard: View {
    @Bindable var store: WellnessStore

    var body: some View {
        DashCard(title: "Today's wellness", systemImage: "target") {
            VStack(spacing: Spacing.md) {
                MetricRow(title: "Water", value: store.goalProgress.water, goal: 6, tint: AppColor.water)
                MetricRow(title: "Stretch", value: store.goalProgress.stretch, goal: 6, tint: AppColor.stretch)
                MetricRow(title: "Meals", value: store.goalProgress.meal, goal: 3, tint: AppColor.meal)
            }
        }
    }
}

#Preview {
    WellnessCard(store: WellnessStore())
        .frame(width: 300)
        .padding()
}

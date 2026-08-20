//
//  WellnessCard.swift
//  Jarvis
//
//  Organism: today's wellness metrics (water/stretch/meal) from PetStore.
//

#if os(macOS)
import SwiftUI

struct WellnessCard: View {
    @Bindable var store: PetStore

    var body: some View {
        DashCard(title: "Wellness hari ini", systemImage: "target") {
            VStack(spacing: Spacing.md) {
                MetricRow(title: "Minum air", value: store.goalProgress.water, goal: 6, tint: AppColor.water)
                MetricRow(title: "Stretch", value: store.goalProgress.stretch, goal: 6, tint: AppColor.stretch)
                MetricRow(title: "Makan", value: store.goalProgress.meal, goal: 3, tint: AppColor.meal)
            }
        }
    }
}

#Preview {
    WellnessCard(store: PetStore())
        .frame(width: 300)
        .padding()
}
#endif

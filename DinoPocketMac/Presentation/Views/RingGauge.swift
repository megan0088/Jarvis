//
//  RingGauge.swift
//  Jarvis
//
//  Atom: circular progress ring with a centered "value/total" readout.
//

import SwiftUI

struct RingGauge: View {
    let value: Int
    let total: Int
    let tint: Color
    let caption: String

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(value) / Double(total)))
    }

    var body: some View {
        VStack(spacing: Spacing.xs) {
            ZStack {
                Circle()
                    .stroke(tint.opacity(0.15), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(value)/\(total)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
            }
            .frame(width: 64, height: 64)

            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    HStack(spacing: Spacing.lg) {
        RingGauge(value: 3, total: 6, tint: AppColor.water, caption: "Water")
        RingGauge(value: 6, total: 6, tint: AppColor.stretch, caption: "Stretch")
        RingGauge(value: 0, total: 3, tint: AppColor.meal, caption: "Meals")
    }
    .padding()
}

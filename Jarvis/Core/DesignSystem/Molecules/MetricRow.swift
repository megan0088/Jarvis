//
//  MetricRow.swift
//  Jarvis
//
//  Molecule: a title + "value/goal" readout + tinted progress bar.
//

#if os(macOS)
import SwiftUI

struct MetricRow: View {
    let title: String
    let value: Int
    let goal: Int
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                Text("\(value)/\(goal)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: Double(value), total: Double(max(goal, 1)))
                .tint(tint)
        }
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        MetricRow(title: "Minum air", value: 3, goal: 6, tint: AppColor.water)
        MetricRow(title: "Stretch", value: 6, goal: 6, tint: AppColor.stretch)
        MetricRow(title: "Makan", value: 0, goal: 3, tint: AppColor.meal)
    }
    .padding()
    .frame(width: 280)
}
#endif

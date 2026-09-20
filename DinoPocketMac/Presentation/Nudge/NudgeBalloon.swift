//
//  NudgeBalloon.swift
//  Apl
//
//  Kapsul satu baris di samping robot (spec C2 §5).
//

import SwiftUI

struct NudgeBalloon: View {
    let text: String
    let onTap: () -> Void
    let onHoverChange: (Bool) -> Void

    var body: some View {
        Text(text)
            .font(.callout)
            .lineLimit(2)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: NudgePanelController.maxWidth, alignment: .leading)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.separator))
            .contentShape(Capsule())
            .onTapGesture(perform: onTap)
            .onHover(perform: onHoverChange)
            .accessibilityElement()
            .accessibilityLabel(text)
    }
}

#Preview("Balon · Light") {
    VStack(alignment: .leading, spacing: Spacing.md) {
        NudgeBalloon(text: "Stretch · 3:00 PM", onTap: {}, onHoverChange: { _ in })
        NudgeBalloon(text: "This Mac is running hot.", onTap: {}, onHoverChange: { _ in })
    }
    .padding(Spacing.xl)
}

#Preview("Balon · Dark") {
    NudgeBalloon(text: "Battery is getting low.", onTap: {}, onHoverChange: { _ in })
        .padding(Spacing.xl)
        .preferredColorScheme(.dark)
}

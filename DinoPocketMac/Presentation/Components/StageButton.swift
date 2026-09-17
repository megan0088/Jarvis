//
//  StageButton.swift
//  Apl
//
//  Tombol utama di kaki stage (Buddy Mode). Beraksen saat menyala.
//

import SwiftUI

struct StageButton: View {
    let title: String
    let systemImage: String
    var isOn = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(isOn ? AppColor.accent : nil)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

#Preview("Light") {
    VStack(spacing: Spacing.sm) {
        StageButton(title: "Buddy Mode", systemImage: "figure.stand") {}
        StageButton(title: "Hide Buddy", systemImage: "figure.stand", isOn: true) {}
    }
    .padding()
    .frame(width: 260)
}

#Preview("Dark") {
    StageButton(title: "Buddy Mode", systemImage: "figure.stand") {}
        .padding()
        .frame(width: 260)
        .preferredColorScheme(.dark)
}

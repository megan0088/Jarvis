//
//  IconButton.swift
//  Apl
//
//  Tombol ikon 28pt tanpa bingkai; latarnya muncul saat disorot (spec B §7).
//

import SwiftUI

struct IconButton: View {
    let systemImage: String
    /// Dibacakan VoiceOver dan tampil sebagai tooltip.
    let label: String
    var isOn = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(IconButtonStyle(isOn: isOn))
        .help(label)
        .accessibilityLabel(label)
    }
}

private struct IconButtonStyle: ButtonStyle {
    let isOn: Bool

    func makeBody(configuration: Configuration) -> some View {
        IconButtonBody(configuration: configuration, isOn: isOn)
    }
}

/// View terpisah karena `ButtonStyle` sendiri tidak bisa memegang state hover.
private struct IconButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let isOn: Bool

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    var body: some View {
        configuration.label
            .foregroundStyle(isOn ? AppColor.accent : Color.secondary)
            .background(
                RoundedRectangle(cornerRadius: Radius.iconButton, style: .continuous)
                    .fill(isHovering || configuration.isPressed ? AppColor.controlFill : Color.clear)
            )
            .opacity(isEnabled ? 1 : 0.4)
            .contentShape(RoundedRectangle(cornerRadius: Radius.iconButton, style: .continuous))
            .onHover { isHovering = $0 }
    }
}

#Preview("Light") {
    HStack(spacing: Spacing.sm) {
        IconButton(systemImage: "gearshape", label: "Settings") {}
        IconButton(systemImage: "figure.stand", label: "Buddy Mode", isOn: true) {}
        IconButton(systemImage: "trash", label: "Remove") {}
            .disabled(true)
    }
    .padding()
}

#Preview("Dark") {
    HStack(spacing: Spacing.sm) {
        IconButton(systemImage: "gearshape", label: "Settings") {}
        IconButton(systemImage: "figure.stand", label: "Buddy Mode", isOn: true) {}
    }
    .padding()
    .preferredColorScheme(.dark)
}

//
//  PillButton.swift
//  Apl
//
//  Atom: capsule-shaped labeled button, primary or secondary.
//

import SwiftUI

struct PillButton: View {
    let title: String
    let systemImage: String
    var isPrimary: Bool = false
    let action: () -> Void

    var body: some View {
        if isPrimary {
            Button(action: action) {
                Label(title, systemImage: systemImage)
            }
            .buttonStyle(.borderedProminent)
        } else {
            Button(action: action) {
                Label(title, systemImage: systemImage)
            }
            .buttonStyle(.bordered)
        }
    }
}

#Preview {
    HStack(spacing: Spacing.sm) {
        PillButton(title: "Ask Apl", systemImage: "sparkles", isPrimary: true) {}
        PillButton(title: "Buddy Mode", systemImage: "figure.walk") {}
    }
    .padding()
}

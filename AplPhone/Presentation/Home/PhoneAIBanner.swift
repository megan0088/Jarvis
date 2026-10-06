//
//  PhoneAIBanner.swift
//  Apl (iPhone)
//
//  Tampil di atas composer saat Apple Intelligence tidak siap (spec H §6).
//  Menyatakan penyebabnya, menawarkan jalan keluar, dan menegaskan reminder
//  tetap jalan — chat yang diam tanpa penjelasan tampak seperti fitur rusak.
//

import SwiftUI

struct PhoneAIBanner: View {
    let availability: BrainAvailability
    let onOpenSettings: () -> Void

    /// `.needsSetup` berarti model sedang disiapkan sistem; yang dibutuhkan
    /// hanya menunggu, jadi tombol Settings di situ menyesatkan.
    private var isPreparing: Bool {
        if case .needsSetup = availability { return true }
        return false
    }

    private var reason: String {
        switch availability {
        case .ready: ""
        case .needsSetup(let text), .unavailable(let text): text
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: isPreparing ? "arrow.down.circle" : "apple.intelligence")
                .font(.title3)
                .foregroundStyle(isPreparing ? Color.secondary : PhoneColor.statusWarning)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(isPreparing ? "Getting Apple Intelligence ready" : "Chat needs Apple Intelligence")
                    .font(.callout.weight(.semibold))
                Text("\(reason) Reminders still work.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !isPreparing {
                    Button("Open Settings", action: onOpenSettings)
                        .font(.footnote.weight(.semibold))
                        .buttonStyle(.borderless)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .background(PhoneColor.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

#Preview("Banner") {
    VStack(spacing: Spacing.md) {
        PhoneAIBanner(availability: .unavailable("Enable Apple Intelligence in Settings."), onOpenSettings: {})
        PhoneAIBanner(availability: .needsSetup("The on-device model is downloading."), onOpenSettings: {})
    }
    .padding()
}

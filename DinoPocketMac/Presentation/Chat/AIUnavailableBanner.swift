//
//  AIUnavailableBanner.swift
//  Apl
//
//  Tampil di atas composer saat Apple Intelligence tidak siap (spec B §9).
//
//  Ini bukan hiasan. Reviewer App Store bisa saja memakai Mac tanpa Apple
//  Intelligence aktif; tanpa penjelasan yang jelas, chat yang diam tampak
//  seperti fitur rusak dan itu alasan penolakan yang sah. Banner menyatakan
//  penyebabnya, menawarkan jalan keluar, dan menegaskan reminder tetap jalan.
//

import SwiftUI

struct AIUnavailableBanner: View {
    let availability: BrainAvailability
    let onOpenSettings: () -> Void

    /// `.needsSetup` berarti model sedang disiapkan sistem — menawarkan tombol
    /// System Settings di situ hanya menyesatkan, yang dibutuhkan cuma menunggu.
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
                .foregroundStyle(isPreparing ? Color.secondary : AppColor.statusWarning)
            VStack(alignment: .leading, spacing: 2) {
                Text(isPreparing ? "Getting Apple Intelligence ready" : "Chat needs Apple Intelligence")
                    .font(.callout.weight(.semibold))
                Text("\(reason) Reminders still work.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Spacing.sm)
            if !isPreparing {
                Button("Open System Settings", action: onOpenSettings)
                    .controlSize(.small)
            }
        }
        .padding(Spacing.md)
        .background(AppColor.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(.separator))
        .accessibilityElement(children: .contain)
    }
}

#Preview("Banner · Light") {
    VStack(spacing: Spacing.md) {
        AIUnavailableBanner(availability: .unavailable("Enable Apple Intelligence in System Settings."),
                            onOpenSettings: {})
        AIUnavailableBanner(availability: .needsSetup("The on-device model is downloading. Try again later."),
                            onOpenSettings: {})
    }
    .padding()
    .frame(width: 600)
}

#Preview("Banner · Dark") {
    AIUnavailableBanner(availability: .unavailable("Apple Intelligence isn't available on this device."),
                        onOpenSettings: {})
        .padding()
        .frame(width: 600)
        .preferredColorScheme(.dark)
}

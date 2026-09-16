//
//  AIUnavailableCard.swift
//  AplMac
//
//  Ditampilkan ChatPage saat Apple Intelligence tidak siap.
//
//  Ini bukan hiasan. Reviewer App Store bisa saja memakai Mac tanpa Apple
//  Intelligence aktif; tanpa penjelasan yang jelas, chat yang diam tampak
//  seperti fitur rusak dan itu alasan penolakan yang sah. Kartu ini menyatakan
//  penyebabnya, menawarkan jalan keluar, dan menegaskan sisa app tetap bekerja.
//

import SwiftUI

struct AIUnavailableCard: View {

    let availability: BrainAvailability

    private var reason: String {
        switch availability {
        case .ready:                     "Apple Intelligence is ready."
        case .needsSetup(let text):      text
        case .unavailable(let text):     text
        }
    }

    /// `.needsSetup` berarti model sedang disiapkan sistem — menawarkan tombol
    /// System Settings di situ hanya menyesatkan, yang dibutuhkan cuma menunggu.
    private var isWaitingOnDownload: Bool {
        if case .needsSetup = availability { return true }
        return false
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: isWaitingOnDownload ? "arrow.down.circle" : "brain")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(.secondary)

            Text(isWaitingOnDownload ? "Preparing the model" : "Chat needs Apple Intelligence")
                .font(.headline)

            Text(reason)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if !isWaitingOnDownload {
                Button("Open System Settings") { Self.openAppleIntelligenceSettings() }
                    .buttonStyle(.borderedProminent)
            }

            Text("Your character, reminders, wellness tracking, and history all keep working.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 360)
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Dialihkan ke `AppLauncherService` agar daftar pane dan perilaku
    /// fallback-nya hidup di satu tempat yang punya test.
    static func openAppleIntelligenceSettings() {
        AppLauncherService().open(.appleIntelligence)
    }
}

#Preview("Unavailable") {
    AIUnavailableCard(availability: .unavailable("Enable Apple Intelligence in System Settings."))
}

#Preview("Downloading") {
    AIUnavailableCard(availability: .needsSetup("The on-device model is downloading. Try again later."))
}

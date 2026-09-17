//
//  CharacterStage.swift
//  Apl
//
//  Panel kiri jendela utama (spec B §5): robot dengan glow dan bayangan,
//  nama, status, Up next, lalu tombol Buddy Mode dan Settings.
//

import SwiftUI

struct CharacterStage: View {
    nonisolated static let width: CGFloat = 320

    let behavior: CharacterBehavior
    let statusText: String
    let reminders: ReminderListViewModel
    let isBuddyModeOn: Bool
    var isAnimationPaused = false
    let onToggleBuddy: () -> Void
    let onOpenSettings: () -> Void
    let onOpenNotificationSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            character
                // Ruang untuk tombol jendela; judul jendela disembunyikan.
                .padding(.top, 36)
            Text("Apl")
                .font(AppFont.title(24))
                .padding(.top, Spacing.sm)
            StatusLine(text: statusText, isWarning: behavior == .sleepy)
                .font(.callout)
                .padding(.top, Spacing.xs)
                .padding(.horizontal, Spacing.lg)
            UpNextList(viewModel: reminders, onOpenNotificationSettings: onOpenNotificationSettings)
                .padding(.top, Spacing.xl)
                .padding(.horizontal, Spacing.lg)
            Spacer(minLength: Spacing.lg)
            HStack(spacing: Spacing.sm) {
                StageButton(title: isBuddyModeOn ? "Hide Buddy" : "Buddy Mode",
                            systemImage: "figure.stand", isOn: isBuddyModeOn, action: onToggleBuddy)
                IconButton(systemImage: "gearshape", label: "Settings", action: onOpenSettings)
            }
            .padding(Spacing.lg)
        }
        .frame(width: Self.width)
        .frame(maxHeight: .infinity)
        .background(AppColor.raisedSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    /// Area robot ±280×204pt: glow aksen di belakang, bayangan lembut di bawah.
    /// Bila model gagal dimuat, yang tersisa hanya glow — stage tetap utuh.
    private var character: some View {
        ZStack {
            Ellipse()
                .fill(AppColor.stageGlow)
                .frame(width: 240, height: 170)
                .blur(radius: 36)
            Ellipse()
                .fill(Color.black.opacity(0.16))
                .frame(width: 110, height: 12)
                .blur(radius: 6)
                .offset(y: 96)
            USDZCharacterView(size: 204, asset: .robot, behavior: behavior, isPaused: isAnimationPaused)
        }
        .frame(width: 280, height: 204)
    }
}

#Preview("Stage · Dark") {
    CharacterStage(behavior: .idle, statusText: "Here when you need me", reminders: .preview(),
                   isBuddyModeOn: false, onToggleBuddy: {}, onOpenSettings: {},
                   onOpenNotificationSettings: {})
        .padding(8)
        .frame(height: 680)
        .preferredColorScheme(.dark)
}

#Preview("Stage · AI off · Light") {
    CharacterStage(behavior: .sleepy, statusText: "Apple Intelligence is off",
                   reminders: .preview(notificationsAllowed: false),
                   isBuddyModeOn: true, onToggleBuddy: {}, onOpenSettings: {},
                   onOpenNotificationSettings: {})
        .padding(8)
        .frame(height: 680)
}

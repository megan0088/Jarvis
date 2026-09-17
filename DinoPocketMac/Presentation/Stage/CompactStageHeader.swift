//
//  CompactStageHeader.swift
//  Apl
//
//  Pengganti stage saat jendela lebih sempit dari 820pt (spec B §5): avatar
//  36pt, nama, dan status. Up next tidak muat, jadi reminder dibuka lewat
//  tombol lonceng (deviasi 13).
//

import SwiftUI

struct CompactStageHeader: View {
    let behavior: CharacterBehavior
    let statusText: String
    let reminders: ReminderListViewModel
    let isBuddyModeOn: Bool
    var isAnimationPaused = false
    let onToggleBuddy: () -> Void
    let onOpenSettings: () -> Void

    @State private var showsReminders = false

    var body: some View {
        HStack(spacing: Spacing.md) {
            USDZCharacterView(size: 36, asset: .robot, behavior: behavior, isPaused: isAnimationPaused)
            VStack(alignment: .leading, spacing: 2) {
                Text("Apl")
                    .font(AppFont.title(15))
                StatusLine(text: statusText, isWarning: behavior == .sleepy)
                    .font(.caption)
            }
            Spacer(minLength: Spacing.sm)
            IconButton(systemImage: "bell", label: "Reminders") {
                showsReminders = true
            }
            .popover(isPresented: $showsReminders, arrowEdge: .bottom) {
                RemindersPopover(viewModel: reminders)
            }
            IconButton(systemImage: "figure.stand", label: isBuddyModeOn ? "Hide Buddy" : "Buddy Mode",
                       isOn: isBuddyModeOn, action: onToggleBuddy)
            IconButton(systemImage: "gearshape", label: "Settings", action: onOpenSettings)
        }
        // Ruang untuk tombol jendela di kiri atas.
        .padding(.leading, 78)
        .padding(.trailing, Spacing.lg)
        .frame(height: 52)
    }
}

#Preview("Compact · Light") {
    CompactStageHeader(behavior: .greet, statusText: "Good morning!", reminders: .preview(),
                       isBuddyModeOn: false, onToggleBuddy: {}, onOpenSettings: {})
        .frame(width: 740)
}

#Preview("Compact · Dark") {
    CompactStageHeader(behavior: .thinking, statusText: "Thinking…", reminders: .preview(),
                       isBuddyModeOn: true, onToggleBuddy: {}, onOpenSettings: {})
        .frame(width: 740)
        .preferredColorScheme(.dark)
}

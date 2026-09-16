//
//  ContentView+macOS.swift
//  Apl
//

#if os(macOS)
import SwiftUI

extension ContentView {
    // platformControls is no longer used in the retro UI tab strip.
    @ViewBuilder
    var platformControls: some View {
        EmptyView()
    }

    // Bottom button row entry for Buddy Mode (macOS)
    var platformBottomButton: some View {
        Button(action: toggleBuddyMode) {
            HStack(spacing: 4) {
                Circle()
                    .fill(isBuddyModeActive ? Color(red: 0.435, green: 0.686, blue: 0.416) : Color(red: 0.776, green: 0.353, blue: 0.290).opacity(0.8))
                    .frame(width: 7, height: 7)
                Text(isBuddyModeActive ? "Stop Buddy" : "Buddy Mode")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isBuddyModeActive
                          ? Color(red: 0.776, green: 0.353, blue: 0.290).opacity(0.25)
                          : Color(red: 0.902, green: 0.863, blue: 0.784).opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(red: 0.776, green: 0.353, blue: 0.290).opacity(0.7), lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color(red: 0.184, green: 0.165, blue: 0.141))  // --text-main #2F2A24
    }

    func toggleBuddyMode() {
        onBuddyMode?()
    }

    func updateLiveActivityState() {
        // macOS doesn't use Live Activities
    }
}
#endif

//
//  ContentView+macOS.swift
//  Jarvis
//

#if os(macOS)
import SwiftUI

extension ContentView {
    @ViewBuilder
    var platformControls: some View {
        Button(action: toggleBuddyMode) {
            Label(
                isBuddyModeActive ? "Stop Buddy" : "Buddy Mode",
                systemImage: isBuddyModeActive ? "stop.circle" : "figure.walk"
            )
        }
        .buttonStyle(.borderedProminent)
        .tint(isBuddyModeActive ? .red : .green)
    }

    func toggleBuddyMode() {
        onBuddyMode?()
    }

    func updateLiveActivityState() {
    }
}
#endif

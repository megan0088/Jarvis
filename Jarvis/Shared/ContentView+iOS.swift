//
//  ContentView+iOS.swift
//  Jarvis
//

#if os(iOS)
import SwiftUI
import ActivityKit

extension ContentView {
    @ViewBuilder
    var platformControls: some View {
        Button(action: toggleLiveActivity) {
            Label(liveActivity == nil ? "Live Activity" : "Stop", systemImage: "app.badge")
        }
        .buttonStyle(.borderless)
    }

    func toggleLiveActivity() {
        if let liveActivity {
            Task {
                let content = activityContent()
                await liveActivity.end(
                    content,
                    dismissalPolicy: ActivityUIDismissalPolicy.immediate
                )
                self.liveActivity = nil
            }
            return
        }

        Task {
            let attributes = PetActivityAttributes(name: "Jarvis")
            let content = activityContent()

            do {
                liveActivity = try Activity.request(
                    attributes: attributes,
                    content: content
                )
            } catch {
                print("Failed to start Live Activity: \(error)")
            }
        }
    }

    func updateLiveActivityState() {
        guard let liveActivity else { return }
        Task {
            await liveActivity.update(activityContent())
        }
    }

    private func activityContent() -> ActivityContent<PetActivityAttributes.ContentState> {
        ActivityContent(
            state: .init(
                mood: store.mood,
                hunger: store.hunger,
                energy: store.energy
            ),
            staleDate: nil
        )
    }
}
#endif

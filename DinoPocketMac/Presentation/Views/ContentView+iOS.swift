//
//  ContentView+iOS.swift
//  Jarvis
//

#if os(iOS)
import SwiftUI
import ActivityKit

// MARK: - Retro colors (inline for iOS extension)
private extension Color {
    static let iRetroTeal   = Color(red: 0.435, green: 0.659, blue: 0.686)
    static let iRetroBg     = Color(red: 0.902, green: 0.863, blue: 0.784)
    static let iRetroText   = Color(red: 0.184, green: 0.165, blue: 0.141)
    static let iRetroGreen  = Color(red: 0.435, green: 0.686, blue: 0.416)
    static let iRetroOrange = Color(red: 0.851, green: 0.549, blue: 0.227)
    static let iRetroRed    = Color(red: 0.776, green: 0.353, blue: 0.290)
    static let iRetroPanel  = Color(red: 0.247, green: 0.290, blue: 0.247)
    static let iRetroBorder = Color(red: 0.333, green: 0.384, blue: 0.333)
    static let iRetroDim    = Color(red: 0.686, green: 0.765, blue: 0.643)
    static let iRetroLight  = Color(red: 0.949, green: 0.914, blue: 0.847)
}

extension ContentView {

    // MARK: - Platform Controls (nav bar)

    @ViewBuilder
    var platformControls: some View {
        Button(action: toggleLiveActivity) {
            Label(liveActivity == nil ? "Live Activity" : "Stop", systemImage: "app.badge")
        }
        .buttonStyle(.borderless)
    }

    // MARK: - Platform Bottom Button (CRT bezel row)

    var platformBottomButton: some View {
        Button(action: toggleLiveActivity) {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.iRetroTeal.opacity(liveActivity != nil ? 1.0 : 0.5))
                    .frame(width: 7, height: 7)
                Text(liveActivity == nil ? "Live" : "Stop")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.iRetroBg.opacity(0.9))
                    .overlay(RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.iRetroTeal.opacity(0.7), lineWidth: 1.5))
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.iRetroText)
    }

    // MARK: - Live Activity Demo Card

    var liveActivityDemoCard: some View {
        RetroCardView {
            // Header
            HStack(spacing: 0) {
                Image(systemName: "livephoto")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.iRetroTeal)
                Text(" Live Activity ")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.iRetroLight)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(liveActivity != nil ? Color.iRetroGreen : Color.iRetroDim.opacity(0.5))
                        .frame(width: 6, height: 6)
                    Text(liveActivity != nil ? "Active" : "Off")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(liveActivity != nil ? Color.iRetroGreen : Color.iRetroDim)
                }
            }

            if liveActivity == nil {
                // Start prompt
                Button(action: toggleLiveActivity) {
                    HStack {
                        Spacer()
                        Image(systemName: "play.fill").font(.system(size: 10))
                        Text("Start Live Activity")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                        Spacer()
                    }
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.iRetroGreen.opacity(0.2)))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.iRetroGreen.opacity(0.6), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.iRetroGreen)
                .padding(.top, 2)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    // Section label
                    Text("— Demo Triggers —")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.iRetroDim)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 2)

                    // Wellness reminders row
                    HStack(spacing: 5) {
                        demoButton("💧 Air", color: .iRetroTeal) {
                            triggerReminder(
                                kind: .water,
                                title: "Waktunya minum air!",
                                body: "Ambil jeda dan minum segelas air."
                            )
                        }
                        demoButton("🧘 Stretch", color: .iRetroOrange) {
                            triggerReminder(
                                kind: .stretch,
                                title: "Stretch break!",
                                body: "Berdiri 2-3 menit, regangkan tubuh."
                            )
                        }
                        demoButton("🍽 Makan", color: .iRetroGreen) {
                            triggerReminder(
                                kind: .meal,
                                title: "Saatnya makan!",
                                body: "Jangan cuma kopi, makan yang beneran."
                            )
                        }
                    }

                    // Mood states row
                    HStack(spacing: 5) {
                        demoButton("😤 Marah", color: .iRetroRed) { triggerMoodTakeover(.angry) }
                        demoButton("😋 Lapar", color: .iRetroOrange) { triggerMoodTakeover(.hungry) }
                        demoButton("↺ Reset", color: .iRetroDim) { resetToNormal() }
                    }

                    // Stop button
                    Button(action: toggleLiveActivity) {
                        HStack {
                            Spacer()
                            Image(systemName: "stop.fill").font(.system(size: 9))
                            Text("Stop Live Activity")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                            Spacer()
                        }
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.iRetroRed.opacity(0.15)))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.iRetroRed.opacity(0.5), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.iRetroRed)
                }
            }
        }
    }

    private func demoButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.18)))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(color.opacity(0.55), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .foregroundStyle(color)
    }

    // MARK: - Demo Trigger Actions

    private func triggerReminder(
        kind: PetActivityAttributes.ContentState.ReminderKind,
        title: String,
        body: String
    ) {
        guard let liveActivity else { return }
        Task {
            var state = liveActivity.content.state
            state.activeReminder = .init(kind: kind, title: title, body: body)
            await liveActivity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    private func triggerMoodTakeover(_ mood: WellnessStore.Mood) {
        guard let liveActivity else { return }
        Task {
            var state = liveActivity.content.state
            state.activeReminder = nil
            state.mood = mood
            if mood == .hungry { state.hunger = 90 }
            await liveActivity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    private func resetToNormal() {
        guard let liveActivity else { return }
        Task {
            await liveActivity.update(activityContent())
        }
    }

    // MARK: - Core Live Activity

    func toggleLiveActivity() {
        if let liveActivity {
            Task {
                await liveActivity.end(activityContent(), dismissalPolicy: .immediate)
                self.liveActivity = nil
            }
            return
        }
        Task {
            let attributes = PetActivityAttributes(name: "Jarvis")
            let content = activityContent()
            do {
                liveActivity = try Activity.request(attributes: attributes, content: content)
            } catch {
                print("Live Activity start failed: \(error)")
            }
        }
    }

    func updateLiveActivityState() {
        guard let liveActivity else { return }
        // Don't override an active demo reminder
        guard liveActivity.content.state.activeReminder == nil else { return }
        Task {
            await liveActivity.update(activityContent())
        }
    }

    func activityContent() -> ActivityContent<PetActivityAttributes.ContentState> {
        let p = store.goalProgress
        return ActivityContent(
            state: .init(
                mood: store.mood,
                hunger: store.hunger,
                energy: store.energy,
                waterProgress: p.water,
                stretchProgress: p.stretch,
                mealProgress: p.meal,
                screenTimeMinutes: Int(store.todayScreenTime / 60),
                activeReminder: nil
            ),
            staleDate: nil
        )
    }
}
#endif

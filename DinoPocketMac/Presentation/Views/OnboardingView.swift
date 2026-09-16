//
//  OnboardingView.swift
//  AplMac
//
//  Alur perkenalan sekali jalan: sambutan + nama panggilan → izin notifikasi
//  → status Apple Intelligence. Tanpa akun.
//
//  Tampilan ini sementara; sub-project B memolesnya.
//

import SwiftUI
import UserNotifications

struct OnboardingView: View {

    let profile: ProfileStore
    let chat: ChatStore

    /// Dipanggil saat pengguna menekan "Allow notifications" dan macOS mengabulkan.
    var onNotificationsGranted: () async -> Void = {}

    @State private var step: Step = .welcome
    @State private var nicknameDraft = ""
    @State private var notificationDecision: NotificationDecision = .undecided
    @State private var appleAvailability: BrainAvailability?

    enum Step: Int, CaseIterable {
        case welcome, notifications, intelligence

        var title: String {
            switch self {
            case .welcome:       "Meet Apl"
            case .notifications: "Reminders"
            case .intelligence:  "On-device intelligence"
            }
        }
    }

    enum NotificationDecision {
        case undecided, granted, denied
    }

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)

            Divider()
            footer
                .padding(20)
        }
        .frame(width: 520, height: 460)
        .task { appleAvailability = await chat.availability(of: .apple) }
    }

    // MARK: - Steps

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)

            switch step {
            case .welcome:
                icon("sparkles")
                heading(step.title)
                body("A small robot that lives on your desktop, chats with you, and keeps "
                     + "your reminders. Everything runs on this Mac.")

                TextField("What should I call you?", text: $nicknameDraft)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 260)
                    .onSubmit { goForward() }

            case .notifications:
                icon("bell.badge")
                heading(step.title)
                body("Ask Apl to remind you about anything. Reminders arrive as "
                     + "notifications, so Apl needs your permission to show them.")

                switch notificationDecision {
                case .undecided:
                    Button("Allow notifications") { Task { await requestNotifications() } }
                        .buttonStyle(.borderedProminent)
                case .granted:
                    Label("Notifications on", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .denied:
                    Text("You can turn these on later in System Settings › Notifications.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

            case .intelligence:
                icon("brain")
                heading(step.title)
                body("Chat runs on Apple Intelligence, on this Mac. No account, no "
                     + "network, nothing leaves the device.")

                switch appleAvailability {
                case .ready:
                    Label("Apple Intelligence is ready", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .needsSetup(let reason), .unavailable(let reason):
                    VStack(spacing: 6) {
                        Label(reason, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("The character and reminders work regardless.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)
                case nil:
                    ProgressView().controlSize(.small)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var footer: some View {
        HStack {
            // Titik langkah, supaya pengguna tahu alurnya pendek.
            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.rawValue) { s in
                    Circle()
                        .fill(s == step ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 7, height: 7)
                }
            }

            Spacer()

            if step != .welcome {
                Button("Back") { goBack() }
            }

            Button(step == .intelligence ? "Start" : "Continue") { goForward() }
                .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Actions

    private func goForward() {
        switch step {
        case .welcome:
            profile.setNickname(nicknameDraft)
        case .intelligence:
            profile.completeOnboarding()
            return
        case .notifications:
            break
        }
        if let next = Step(rawValue: step.rawValue + 1) {
            withAnimation(.easeInOut(duration: 0.18)) { step = next }
        }
    }

    private func goBack() {
        if let prev = Step(rawValue: step.rawValue - 1) {
            withAnimation(.easeInOut(duration: 0.18)) { step = prev }
        }
    }

    private func requestNotifications() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        notificationDecision = granted ? .granted : .denied
        if granted { await onNotificationsGranted() }
    }

    // MARK: - Bits

    private func icon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 44, weight: .light))
            .foregroundStyle(Color.accentColor)
    }

    private func heading(_ text: String) -> some View {
        Text(text).font(.title2.weight(.semibold))
    }

    private func body(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 380)
    }
}

#Preview {
    OnboardingView(profile: ProfileStore(), chat: ChatStore(brains: [:]))
}

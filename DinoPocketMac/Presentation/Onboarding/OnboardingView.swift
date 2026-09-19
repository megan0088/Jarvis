//
//  OnboardingView.swift
//  AplMac
//
//  Perkenalan sekali jalan, tanpa akun (spec B §8): robot menyapa dan
//  menanyakan nama → izin notifikasi → status Apple Intelligence.
//  Selesai = `hasCompletedOnboarding`; tidak ada keychain maupun kredensial.
//

import SwiftUI

struct OnboardingView: View {

    let profile: ProfileStore
    let chat: ChatStore
    let launcher: AppLaunching
    /// Meminta izin notifikasi lewat penjadwal reminder; true bila diizinkan.
    var requestNotifications: () async -> Bool = { false }
    /// Disebut sekali di langkah terakhir, supaya tombolnya pernah terlihat.
    var shortcutPreset: ShortcutPreset = .default

    @Environment(\.appearsActive) private var appearsActive
    @State private var step: Step = .welcome
    @State private var nicknameDraft = ""
    @State private var notificationDecision: NotificationDecision = .undecided
    @State private var availability: BrainAvailability?

    enum Step: Int, CaseIterable {
        case welcome, reminders, intelligence

        var next: Step? { Step(rawValue: rawValue + 1) }
        var previous: Step? { Step(rawValue: rawValue - 1) }
    }

    enum NotificationDecision {
        case undecided, granted, declined
    }

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: 420)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)

            Divider()
            footer
                .padding(20)
        }
        .frame(minWidth: 520, minHeight: 480)
        .background(Color(nsColor: .windowBackgroundColor))
        // Dicek ulang tiap kali jendela aktif: pengguna mungkin baru
        // menyalakan Apple Intelligence di System Settings.
        .onChange(of: appearsActive, initial: true) { _, isActive in
            guard isActive else { return }
            Task { availability = await chat.availability() }
        }
    }

    // MARK: - Langkah

    @ViewBuilder
    private var content: some View {
        VStack(spacing: Spacing.lg) {
            switch step {
            case .welcome:
                USDZCharacterView(size: 160, asset: .robot, behavior: .greet)
                Text("Hi, I'm Apl.")
                    .font(AppFont.title(28))
                paragraph("A small robot that lives on your desktop, chats with you, and keeps your "
                          + "reminders. Everything stays on this Mac.")
                TextField("Name", text: $nicknameDraft, prompt: Text("What should I call you? (optional)"))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 260)

            case .reminders:
                symbol("bell.badge")
                Text("Reminders")
                    .font(AppFont.title(24))
                paragraph("Ask me in chat, like “Remind me to stretch at 3 PM”. Reminders arrive as "
                          + "notifications, so I need your permission to show them.")
                switch notificationDecision {
                case .undecided:
                    HStack(spacing: Spacing.md) {
                        Button("Not now") {
                            notificationDecision = .declined
                            goForward()
                        }
                        Button("Allow Notifications") {
                            Task { await allowNotifications() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                case .granted:
                    Label("Notifications are on", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(AppColor.statusOK)
                case .declined:
                    Text("You can turn them on later in System Settings › Notifications.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

            case .intelligence:
                symbol("apple.intelligence")
                Text("Apple Intelligence")
                    .font(AppFont.title(24))
                paragraph("Chat runs on Apple Intelligence, right on this Mac. No account, and nothing "
                          + "is sent anywhere.")
                intelligenceStatus
                Text("Reminders and your character work without it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if shortcutPreset != .off {
                    Text("Press \(shortcutPreset.displayName) from any app to ask Apl anything.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .multilineTextAlignment(.center)
    }

    @ViewBuilder
    private var intelligenceStatus: some View {
        switch availability {
        case .ready?:
            Label("Ready", systemImage: "checkmark.circle.fill")
                .foregroundStyle(AppColor.statusOK)
        case .needsSetup(let reason)?:
            Label(reason, systemImage: "arrow.down.circle")
                .foregroundStyle(.secondary)
        case .unavailable(let reason)?:
            VStack(spacing: Spacing.sm) {
                Label(reason, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppColor.statusWarning)
                Button("Open System Settings") {
                    _ = launcher.open(.appleIntelligence)
                }
            }
        case nil:
            ProgressView()
                .controlSize(.small)
        }
    }

    private var footer: some View {
        HStack {
            // Titik langkah, supaya pengguna tahu alurnya pendek.
            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.self) { item in
                    Circle()
                        .fill(item == step ? AppColor.accent : Color.secondary.opacity(0.3))
                        .frame(width: 7, height: 7)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Step \(step.rawValue + 1) of \(Step.allCases.count)")

            Spacer()

            if step.previous != nil {
                Button("Back") { goBack() }
            }
            // Start selalu aktif: reminder dan karakter berguna tanpa AI (spec B §8).
            Button(step.next == nil ? "Start" : "Continue") { goForward() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
    }

    // MARK: - Aksi

    private func goForward() {
        if step == .welcome {
            profile.setNickname(nicknameDraft)
        }
        guard let next = step.next else {
            profile.completeOnboarding()
            return
        }
        withAnimation(.easeInOut(duration: 0.18)) { step = next }
    }

    private func goBack() {
        guard let previous = step.previous else { return }
        withAnimation(.easeInOut(duration: 0.18)) { step = previous }
    }

    private func allowNotifications() async {
        notificationDecision = await requestNotifications() ? .granted : .declined
    }

    // MARK: - Potongan

    private func symbol(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 44, weight: .light))
            .foregroundStyle(AppColor.accent)
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview("Onboarding · Light") {
    OnboardingView(profile: ProfileStore(defaults: UserDefaults(suiteName: "apl.preview.profile")!),
                   chat: .preview([]), launcher: AppLauncherService())
        .frame(width: 640, height: 520)
}

#Preview("Onboarding · Dark") {
    OnboardingView(profile: ProfileStore(defaults: UserDefaults(suiteName: "apl.preview.profile")!),
                   chat: .preview([]), launcher: AppLauncherService())
        .frame(width: 640, height: 520)
        .preferredColorScheme(.dark)
}

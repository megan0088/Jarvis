//
//  PhoneOnboardingView.swift
//  Apl (iPhone)
//
//  Perkenalan sekali jalan, tanpa akun (spec H §4.3): robot menyapa dan
//  menanyakan nama → izin notifikasi → status Apple Intelligence.
//  Urutan dan judul tombolnya milik `PhoneOnboardingStep`.
//

import SwiftUI

struct PhoneOnboardingView: View {
    let profile: ProfileStore
    let chat: ChatStore
    let cache: CharacterExpressionCache
    /// Meminta izin notifikasi; true bila diizinkan.
    let requestNotifications: () async -> Bool
    let onOpenSystemSettings: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var step: PhoneOnboardingStep = .welcome
    @State private var nicknameDraft = ""
    @State private var notificationDecision: NotificationDecision = .undecided
    @State private var availability: BrainAvailability?

    private enum NotificationDecision {
        case undecided, granted, declined
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                content
                    .padding(.horizontal, Spacing.xl)
                    .padding(.top, 48)
                    .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)

            footer
                .padding(Spacing.xl)
        }
        // Dicek ulang tiap kali app aktif: pengguna mungkin baru menyalakan
        // Apple Intelligence di Settings.
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            Task { availability = await chat.availability() }
        }
    }

    // MARK: - Langkah

    @ViewBuilder
    private var content: some View {
        VStack(spacing: Spacing.lg) {
            switch step {
            case .welcome:
                PhoneCharacterView(size: 180, behavior: .greet, cache: cache)
                Text("Hi, I'm Apl.")
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                paragraph("A small robot that chats with you and keeps your reminders. "
                          + "Everything stays on this iPhone.")
                TextField("What should I call you? (optional)", text: $nicknameDraft)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.nickname)
                    .submitLabel(.continue)
                    .onSubmit { goForward() }

            case .reminders:
                symbol("bell.badge")
                Text("Reminders")
                    .font(.system(.title, design: .rounded, weight: .semibold))
                paragraph("Ask me in chat, like “Remind me to stretch at 3 PM”. Reminders arrive as "
                          + "notifications, so I need your permission to show them.")
                switch notificationDecision {
                case .undecided:
                    // Izin diminta HANYA saat tombol ini diketuk (spec H §4.3).
                    Button("Allow Notifications") {
                        Task { notificationDecision = await requestNotifications() ? .granted : .declined }
                    }
                    .buttonStyle(.borderedProminent)
                case .granted:
                    Label("Notifications are on", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(PhoneColor.statusOK)
                case .declined:
                    Text("You can turn them on later in Settings › Notifications.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

            case .intelligence:
                symbol("apple.intelligence")
                Text("Apple Intelligence")
                    .font(.system(.title, design: .rounded, weight: .semibold))
                paragraph("Chat runs on Apple Intelligence, right on this iPhone. No account, and "
                          + "nothing is sent anywhere.")
                intelligenceStatus
                Text("Reminders and your character work without it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
    }

    @ViewBuilder
    private var intelligenceStatus: some View {
        switch availability {
        case .ready?:
            Label("Ready", systemImage: "checkmark.circle.fill")
                .foregroundStyle(PhoneColor.statusOK)
        case .needsSetup(let reason)?:
            Label(reason, systemImage: "arrow.down.circle")
                .foregroundStyle(.secondary)
        case .unavailable(let reason)?:
            VStack(spacing: Spacing.sm) {
                Label(reason, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(PhoneColor.statusWarning)
                Button("Open Settings", action: onOpenSystemSettings)
            }
        case nil:
            ProgressView()
        }
    }

    private var footer: some View {
        VStack(spacing: Spacing.md) {
            // Titik langkah, supaya pengguna tahu alurnya pendek.
            HStack(spacing: 6) {
                ForEach(PhoneOnboardingStep.allCases, id: \.self) { item in
                    Circle()
                        .fill(item == step ? PhoneColor.accent : Color.secondary.opacity(0.3))
                        .frame(width: 7, height: 7)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(step.position)

            Button(step.primaryTitle) { goForward() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)

            Button("Back") { goBack() }
                .opacity(step.previous == nil ? 0 : 1)
                .disabled(step.previous == nil)
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

    // MARK: - Potongan

    private func symbol(_ name: String) -> some View {
        Image(systemName: name)
            .font(.largeTitle.weight(.light))
            .imageScale(.large)
            .foregroundStyle(PhoneColor.accent)
            .accessibilityHidden(true)
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview("Onboarding") {
    PhoneOnboardingView(profile: .preview(), chat: .preview([]), cache: CharacterExpressionCache(),
                        requestNotifications: { true }, onOpenSystemSettings: {})
}

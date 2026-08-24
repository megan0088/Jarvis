//
//  OnboardingView.swift
//  DinoPocketMac
//
//  Alur perkenalan sekali jalan: sambutan → Sign in with Apple → izin
//  notifikasi → status Apple Intelligence.
//

import SwiftUI
import AuthenticationServices
import UserNotifications

struct OnboardingView: View {

    @Bindable var account: AccountStore
    let chat: ChatStore

    @State private var step: Step = .welcome
    @State private var signInError: String?
    @State private var notificationDecision: NotificationDecision = .undecided
    @State private var appleAvailability: BrainAvailability?

    enum Step: Int, CaseIterable {
        case welcome, signIn, notifications, intelligence

        var title: String {
            switch self {
            case .welcome:      "Meet your desk companion"
            case .signIn:       "Sign in"
            case .notifications: "Gentle nudges"
            case .intelligence: "On-device intelligence"
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
                body("A small robot lives on your desktop, keeps you company, and "
                     + "reminds you to drink, stretch, and step away from the screen. "
                     + "Everything runs on this Mac.")

            case .signIn:
                icon("person.crop.circle")
                heading(step.title)
                body("DinoPocket uses your Apple ID to identify you. Nothing is sent "
                     + "to a server — the identifier stays in this Mac's Keychain.")

                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName]
                } onCompletion: { result in
                    handleSignIn(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(width: 260, height: 44)

                if let signInError {
                    Text(signInError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
                if account.isSignedIn {
                    Label("Signed in", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }

                #if DEBUG
                // Build Debug tidak membawa entitlement Sign in with Apple —
                // memerlukannya akan menggagalkan build sebelum provisioning
                // profile bercapability SIWA tersedia. Skip ini TIDAK ada di
                // rilis; di sana login tetap wajib.
                Button("Skip (debug build only)") {
                    account.debugBypassSignIn()
                }
                .buttonStyle(.link)
                .font(.footnote)
                #endif

            case .notifications:
                icon("bell.badge")
                heading(step.title)
                body("Reminders arrive as notifications. Without permission they still "
                     + "show up inside the app, just not on screen while you work.")

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
                        Text("The character, reminders, and wellness tracking work regardless.")
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
            // Titik langkah, supaya user tahu alurnya pendek.
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
                .disabled(!canAdvance)
        }
    }

    /// Login wajib: langkah `.signIn` tidak bisa dilewati tanpa kredensial.
    private var canAdvance: Bool {
        step != .signIn || account.isSignedIn
    }

    // MARK: - Actions

    private func goForward() {
        if step == .intelligence {
            account.completeOnboarding()
            return
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

    private func handleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                signInError = "Unexpected credential type."
                return
            }
            signInError = nil
            account.signIn(with: credential)
        case .failure(let error):
            // Pembatalan oleh user bukan kegagalan — jangan tampilkan pesan merah.
            if (error as? ASAuthorizationError)?.code == .canceled {
                signInError = nil
            } else {
                signInError = error.localizedDescription
            }
        }
    }

    private func requestNotifications() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        notificationDecision = granted ? .granted : .denied
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
    OnboardingView(account: AccountStore(), chat: ChatStore(brains: [:]))
}

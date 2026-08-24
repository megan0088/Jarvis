//
//  SettingsPage.swift
//  DinoPocketMac
//
//  Page: assistant preferences and Buddy Mode appearance.
//

import SwiftUI

struct SettingsPage: View {
    @Bindable var chat: ChatStore
    @Bindable var store: WellnessStore
    @Bindable var buddySettings: BuddySettingsStore
    @Bindable var account: AccountStore

    @State private var appleAvailability: BrainAvailability?
    @State private var showDeleteConfirm = false
    @State private var launchAtLoginOn = false
    @State private var launchAtLoginError: String?

    private let launchAtLogin = LaunchAtLoginService()

    private var launchAtLoginNeedsApproval: Bool { launchAtLogin.needsUserApproval }

    /// Binding manual, bukan @State biasa: kalau SMAppService menolak, toggle
    /// harus kembali ke posisi semula alih-alih menampilkan keadaan palsu.
    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLoginOn },
            set: { wanted in
                do {
                    try launchAtLogin.setEnabled(wanted)
                    launchAtLoginOn = launchAtLogin.isEnabled
                    launchAtLoginError = nil
                } catch {
                    launchAtLoginOn = launchAtLogin.isEnabled
                    launchAtLoginError = "macOS refused that change: \(error.localizedDescription)"
                }
            }
        )
    }

    private static var versionText: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }

    var body: some View {
        Form {
            Section("Assistant") {
                // Rilis hanya punya satu otak, jadi tidak ada yang perlu dipilih —
                // yang berguna bagi pengguna adalah tahu apakah otak itu siap.
                LabeledContent("Apple Intelligence") {
                    switch appleAvailability {
                    case .ready:
                        Label("Ready", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .labelStyle(.titleAndIcon)
                    case .needsSetup(let reason), .unavailable(let reason):
                        Label(reason, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .labelStyle(.titleAndIcon)
                            .multilineTextAlignment(.trailing)
                    case nil:
                        ProgressView().controlSize(.small)
                    }
                }

                #if DEBUG
                // Ollama hanya tersedia di build DEBUG; tidak pernah ikut rilis.
                Picker("Brain (debug)", selection: $chat.activeBrain) {
                    ForEach(BrainKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                #endif

                Picker("Persona", selection: $chat.persona) {
                    ForEach(Persona.allCases, id: \.self) { persona in
                        Text(persona.label).tag(persona)
                    }
                }
            }

            Section("Buddy") {
                LabeledContent("Character size") {
                    HStack(spacing: 12) {
                        Slider(
                            value: $buddySettings.size,
                            in: BuddySettingsStore.sizeRange,
                            step: 10
                        )
                        Text("\(Int(buddySettings.size)) pt")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 56, alignment: .trailing)
                    }
                }
                LabeledContent("Opacity") {
                    HStack(spacing: 12) {
                        Slider(value: $buddySettings.opacity,
                               in: BuddySettingsStore.opacityRange)
                        Text("\(Int(buddySettings.opacity * 100))%")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 56, alignment: .trailing)
                    }
                }

                Toggle("Keep on top of other windows", isOn: $buddySettings.keepOnTop)

                Toggle("Wander around the desktop", isOn: $buddySettings.strolling)

                Text("Changes apply immediately while Buddy Mode is running. "
                     + "Press Esc to leave Buddy Mode.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("General") {
                Toggle("Launch at login", isOn: launchAtLoginBinding)

                if launchAtLoginNeedsApproval {
                    // Status .requiresApproval berarti user pernah menolak app ini
                    // di Login Items; registrasi "berhasil" tanpa app pernah
                    // diluncurkan, jadi toggle menyala akan berbohong.
                    Text("Approve DinoPocket in System Settings › General › Login Items.")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            Section("Account") {
                LabeledContent("Signed in as") {
                    Text(account.displayName ?? "Apple ID")
                        .foregroundStyle(.secondary)
                }

                Button("Sign Out") { account.signOut() }

                Button("Delete Account and Data", role: .destructive) {
                    showDeleteConfirm = true
                }
            }

            Section("About") {
                LabeledContent("Version") {
                    Text(Self.versionText).foregroundStyle(.secondary)
                }

                // Lisensi Sketchfab Standard mewajibkan kredit pencipta. Baris ini
                // hilang sendiri begitu aset diganti model buatan sendiri, karena
                // atribusinya ikut ke `CharacterAsset` (Wave 1).
                VStack(alignment: .leading, spacing: 4) {
                    Text("Acknowledgements").font(.callout.weight(.medium))
                    Text("3D character by l0wpoly (sketchfab.com/l0wpoly) — Sketchfab Standard License")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .padding(.vertical, 2)

                Text("DinoPocket runs entirely on this Mac. No account data, wellness "
                     + "history, or conversation ever leaves the device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .confirmationDialog("Delete account and all local data?",
                            isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete Everything", role: .destructive) {
                // Tiap penyimpanan memusnahkan miliknya sendiri; UseCase ini
                // tidak tahu satu pun nama kunci atau suite.
                DeleteAccountUseCase(
                    stores: [account, store, chat],
                    signOut: { account.signOut() }
                ).execute()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            // Jujur soal batas kuasa app: mencabut izin Apple ID hanya bisa
            // dilakukan user dari System Settings, bukan dari sini.
            Text("This erases your wellness history, reminders, and chat from this Mac, "
                 + "and signs you out. To revoke DinoPocket's access to your Apple ID, "
                 + "open System Settings › Apple Account › Sign in with Apple.")
        }
        .task {
            appleAvailability = await chat.availability(of: .apple)
            launchAtLoginOn = launchAtLogin.isEnabled
        }
    }
}

#Preview {
    NavigationStack {
        SettingsPage(chat: ChatStore(brains: [:]), store: WellnessStore(), buddySettings: BuddySettingsStore(), account: AccountStore())
    }
}

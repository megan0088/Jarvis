//
//  SettingsPage.swift
//  AplMac
//
//  Page: assistant preferences and Buddy Mode appearance.
//

import SwiftUI

struct SettingsPage: View {
    @Bindable var chat: ChatStore
    let wellness: WellnessViewModel
    @Bindable var buddySettings: BuddySettingsStore
    let profile: ProfileStore
    /// Penyimpanan tambahan dari composition root (mis. transcript percakapan).
    var extraErasableStores: [any LocallyErasable] = []

    @State private var appleAvailability: BrainAvailability?
    @State private var showEraseConfirm = false
    @State private var nicknameDraft = ""
    @State private var launchAtLoginOn = false
    @State private var launchAtLoginError: String?

    private let launchAtLogin = LaunchAtLoginService()
    private let launcher = AppLauncherService()

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

            Section("Reminders") {
                // Satu-satunya jalan menyalakan pengingat di app ini.
                // Sebelumnya tombolnya cuma ada di `ContentView.swift` yang
                // DIKECUALIKAN dari target macOS, jadi `remindersEnabled`
                // selamanya false dan nol notifikasi pernah terdaftar.
                Toggle("Daily wellness reminders", isOn: Binding(
                    get: { wellness.remindersEnabled },
                    set: { wanted in Task { await wellness.setRemindersEnabled(wanted) } }
                ))

                if wellness.authorizationWasDenied {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("macOS is blocking notifications for Apl, so reminders "
                             + "cannot be scheduled.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                        Button("Open Notification Settings") {
                            launcher.open(.notifications)
                        }
                        .controlSize(.small)
                    }
                } else if wellness.remindersEnabled {
                    Text("\(wellness.reminderSchedules.count) reminders scheduled: water, "
                         + "stretch breaks, and meals.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
                    Text("Approve Apl in System Settings › General › Login Items.")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            Section("Profile") {
                // Disimpan saat Return atau saat halaman ditutup, bukan setiap
                // ketukan: normalisasi memangkas spasi, sehingga menyimpan per
                // ketukan akan memakan spasi di tengah nama yang sedang diketik.
                TextField("Nickname", text: $nicknameDraft, prompt: Text("What should Apl call you?"))
                    .onSubmit { profile.setNickname(nicknameDraft) }

                Button("Erase All Data…", role: .destructive) {
                    showEraseConfirm = true
                }
            }

            Section("About") {
                LabeledContent("Version") {
                    Text(Self.versionText).foregroundStyle(.secondary)
                }

                // Lisensi Sketchfab Standard mewajibkan kredit pencipta. Baris ini
                // hilang sendiri begitu aset diganti model buatan sendiri, karena
                // atribusinya ikut ke `CharacterAsset` (Wave 1).
                // Kredit dibaca dari aset. Saat model diganti dengan buatan
                // sendiri, `attribution` menjadi nil dan seluruh bagian ini
                // lenyap tanpa ada yang perlu ingat menghapusnya.
                if let attribution = CharacterAsset.robot.attribution {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Acknowledgements").font(.callout.weight(.medium))
                        Text(attribution.displayText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 2)
                }

                Text("Apl runs entirely on this Mac. Nothing you tell it ever leaves the device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .confirmationDialog("Erase all data on this Mac?",
                            isPresented: $showEraseConfirm, titleVisibility: .visible) {
            Button("Erase Everything", role: .destructive) {
                // Tiap penyimpanan memusnahkan miliknya sendiri; UseCase ini
                // tidak tahu satu pun nama kunci atau suite.
                let stores: [any LocallyErasable] =
                    [profile, wellness.erasableStore, chat, buddySettings] + extraErasableStores
                let useCase = EraseAllDataUseCase(
                    stores: stores,
                    clearNotifications: { await WellnessNotificationCenter.shared.clearScheduledReminders() }
                )
                Task { await useCase.execute() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes your conversation, reminders, and preferences from this Mac. "
                 + "It can't be undone.")
        }
        .onDisappear { profile.setNickname(nicknameDraft) }
        .task {
            nicknameDraft = profile.nickname ?? ""
            appleAvailability = await chat.availability(of: .apple)
            launchAtLoginOn = launchAtLogin.isEnabled
        }
    }
}

#Preview {
    NavigationStack {
        SettingsPage(chat: ChatStore(brains: [:]), wellness: .preview, buddySettings: BuddySettingsStore(), profile: ProfileStore())
    }
}

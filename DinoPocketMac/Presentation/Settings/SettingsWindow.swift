//
//  SettingsWindow.swift
//  Apl
//
//  Jendela Settings standar (⌘,), spec B §8: General · Character · Privacy,
//  ditambah Debug di build DEBUG. Layout A tidak punya sidebar, jadi
//  pengaturan pindah ke sini.
//

import SwiftUI

struct SettingsWindow: View {
    let profile: ProfileStore
    let buddySettings: BuddySettingsStore
    let shortcutSettings: ShortcutSettingsStore
    let launchAtLogin: any LaunchAtLoginManaging
    /// Menghapus semua data lokal. Pemanggil yang tahu store mana saja.
    let eraseAllData: () async -> Void

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralSettingsTab(profile: profile, launchAtLogin: launchAtLogin,
                                   shortcutSettings: shortcutSettings)
            }
            Tab("Character", systemImage: "face.smiling") {
                CharacterSettingsTab(buddySettings: buddySettings)
            }
            Tab("Privacy", systemImage: "hand.raised") {
                PrivacySettingsTab(eraseAllData: eraseAllData)
            }
            #if DEBUG
            Tab("Debug", systemImage: "ladybug") {
                DebugSettingsTab()
            }
            #endif
        }
        .frame(width: 480)
        .frame(minHeight: 280)
    }
}

// MARK: - General

private struct GeneralSettingsTab: View {
    let profile: ProfileStore
    let launchAtLogin: any LaunchAtLoginManaging
    @Bindable var shortcutSettings: ShortcutSettingsStore

    @State private var nicknameDraft = ""
    @State private var launchAtLoginOn = false
    @State private var launchAtLoginError: String?

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

    var body: some View {
        Form {
            Section {
                // Disimpan setiap kali draft berubah. Normalisasi hanya mengenai
                // nilai yang disimpan, bukan teks di kolom, jadi spasi yang sedang
                // diketik tidak termakan.
                //
                // SENGAJA tidak menyimpan saat tab ditutup: Erase All Data
                // mengganti jendela utama dengan onboarding, dan penyimpanan di
                // `onDisappear` menulis ulang nama tepat setelah dihapus.
                TextField("Nickname", text: $nicknameDraft, prompt: Text("What should Apl call you?"))
                    .onChange(of: nicknameDraft) { _, draft in profile.setNickname(draft) }
            }
            Section {
                Toggle("Launch at login", isOn: launchAtLoginBinding)
                if launchAtLogin.needsUserApproval {
                    // Status .requiresApproval berarti user pernah menolak app ini
                    // di Login Items; registrasi "berhasil" tanpa app pernah
                    // diluncurkan, jadi toggle menyala akan berbohong.
                    Text("Approve Apl in System Settings › General › Login Items.")
                        .font(.footnote)
                        .foregroundStyle(AppColor.statusWarning)
                }
                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            Section {
                Picker("Quick ask", selection: $shortcutSettings.preset) {
                    ForEach(ShortcutPreset.allCases, id: \.self) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                if shortcutSettings.registrationFailed {
                    // Kombinasi yang sudah dipegang app lain tidak pernah sampai
                    // ke Apl. Diam di sini berarti pengguna menyalahkan Apl.
                    Text("\(shortcutSettings.preset.displayName) is taken by another app — try another one.")
                        .font(.footnote)
                        .foregroundStyle(AppColor.statusWarning)
                }
            } footer: {
                Text("Press it from any app to ask Apl without leaving what you're doing.")
            }
        }
        .formStyle(.grouped)
        .task {
            nicknameDraft = profile.nickname ?? ""
            launchAtLoginOn = launchAtLogin.isEnabled
        }
    }
}

// MARK: - Character

private struct CharacterSettingsTab: View {
    @Bindable var buddySettings: BuddySettingsStore

    var body: some View {
        Form {
            Section {
                LabeledContent("Size") {
                    HStack(spacing: Spacing.md) {
                        Slider(value: $buddySettings.size, in: BuddySettingsStore.sizeRange, step: 10)
                        Text("\(Int(buddySettings.size)) pt")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 56, alignment: .trailing)
                    }
                }
                LabeledContent("Opacity") {
                    HStack(spacing: Spacing.md) {
                        Slider(value: $buddySettings.opacity, in: BuddySettingsStore.opacityRange)
                        Text("\(Int(buddySettings.opacity * 100))%")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 56, alignment: .trailing)
                    }
                }
                Toggle("Keep on top of other windows", isOn: $buddySettings.keepOnTop)
                Toggle("Wander around the desktop", isOn: $buddySettings.strolling)
            } header: {
                Text("Buddy Mode")
            } footer: {
                Text("Changes apply immediately while Buddy Mode is running. Turn it off with Hide Buddy in the main window.")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Privacy

private struct PrivacySettingsTab: View {
    let eraseAllData: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isConfirming = false
    @State private var isErasing = false

    var body: some View {
        Form {
            Section {
                Text("Apl runs entirely on this Mac. Your conversation, reminders, and preferences never leave the device.")
                    .foregroundStyle(.secondary)
            }
            Section {
                Button("Erase All Data…", role: .destructive) {
                    isConfirming = true
                }
                .disabled(isErasing)
            } footer: {
                Text("Removes your conversation, reminders, and preferences, then starts Apl from the beginning.")
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Erase all data on this Mac?", isPresented: $isConfirming,
                            titleVisibility: .visible) {
            Button("Erase Everything", role: .destructive) {
                isErasing = true
                Task {
                    await eraseAllData()
                    isErasing = false
                    // Jendela utama sudah kembali ke onboarding; Settings ditutup.
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes your conversation, reminders, and preferences from this Mac. It can't be undone.")
        }
    }
}

#Preview("Settings · Light") {
    SettingsWindow(profile: ProfileStore(defaults: UserDefaults(suiteName: "apl.preview.profile")!),
                   buddySettings: BuddySettingsStore(defaults: UserDefaults(suiteName: "apl.preview.buddy")!),
                   shortcutSettings: ShortcutSettingsStore(defaults: UserDefaults(suiteName: "apl.preview.shortcut")!),
                   launchAtLogin: LaunchAtLoginService(),
                   eraseAllData: {})
}

#Preview("Settings · Dark") {
    SettingsWindow(profile: ProfileStore(defaults: UserDefaults(suiteName: "apl.preview.profile")!),
                   buddySettings: BuddySettingsStore(defaults: UserDefaults(suiteName: "apl.preview.buddy")!),
                   shortcutSettings: ShortcutSettingsStore(defaults: UserDefaults(suiteName: "apl.preview.shortcut")!),
                   launchAtLogin: LaunchAtLoginService(),
                   eraseAllData: {})
        .preferredColorScheme(.dark)
}

//
//  AppDependencies.swift
//  AplMac
//
//  Composition root, mengikuti pola Taggo: satu tempat yang tahu implementasi
//  konkret mana yang dipakai, dan pabrik untuk ViewModel.
//
//  Nilainya bukan kerapian semata — ia yang membuat "Ollama tidak ikut rilis"
//  jadi fakta struktural di satu berkas, bukan disiplin yang harus diingat di
//  setiap tempat `ChatStore` dibuat.
//

import Foundation

@MainActor
struct AppDependencies {

    let systemStatus: SystemStatusProviding
    let appLauncher: AppLaunching
    let launchAtLogin: LaunchAtLoginManaging
    let buddySettings: BuddySettingsStore
    let profile: ProfileStore

    /// Otak yang boleh dipilih. Rilis hanya memuat Apple Intelligence: Ollama
    /// butuh localhost, sementara build ini menyetel
    /// ENABLE_OUTGOING_NETWORK_CONNECTIONS = NO, dan app yang bergantung pada
    /// software eksternal berisiko ditolak App Review.
    let brains: [BrainKind: Brain]

    /// Satu-satunya instance ReminderStore: chat dan daftar reminder harus
    /// membaca daftar yang sama.
    let reminderStore: ReminderStore
    let reminderScheduler: any ReminderScheduling

    /// Didaftarkan eksplisit supaya penghapusan akun tidak melewatkannya.
    let erasableStores: [any LocallyErasable]

    static func live() -> AppDependencies {
        // Transcript dipersist supaya percakapan bertahan lintas peluncuran —
        // inti dari "asisten yang ingat kemarin".
        let apple: Brain
        var erasable: [any LocallyErasable] = []
        if #available(macOS 26.0, *) {
            let sessionStore = FileChatSessionStore()
            apple = AppleBrain(sessionStore: sessionStore)
            erasable.append(sessionStore)
        } else {
            apple = AppleBrain()
        }

        #if DEBUG
        let brains: [BrainKind: Brain] = [.apple: apple, .ollama: OllamaBrain()]
        #else
        let brains: [BrainKind: Brain] = [.apple: apple]
        #endif

        let reminderStore = ReminderStore()
        erasable.append(reminderStore)

        return AppDependencies(
            systemStatus: SystemStatusService(),
            appLauncher: AppLauncherService(),
            launchAtLogin: LaunchAtLoginService(),
            buddySettings: BuddySettingsStore(),
            profile: ProfileStore(),
            brains: brains,
            reminderStore: reminderStore,
            reminderScheduler: ReminderNotificationCenter.shared,
            erasableStores: erasable
        )
    }

    // MARK: - Factories

    func makeChatStore() -> ChatStore {
        ChatStore(brains: brains)
    }

    func makeCreateReminderUseCase() -> CreateReminderFromTextUseCase {
        CreateReminderFromTextUseCase(store: reminderStore, notifications: reminderScheduler)
    }
}

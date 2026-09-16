//
//  AppDependencies.swift
//  AplMac
//
//  Composition root, mengikuti pola Taggo: satu tempat yang tahu implementasi
//  konkret mana yang dipakai, dan pabrik untuk ViewModel.
//
//

import Foundation

@MainActor
struct AppDependencies {

    let systemStatus: SystemStatusProviding
    let appLauncher: AppLaunching
    let launchAtLogin: LaunchAtLoginManaging
    let buddySettings: BuddySettingsStore
    let profile: ProfileStore

    /// Apple Intelligence — satu-satunya otak (spec A §2 #7).
    let brain: Brain

    /// Satu-satunya instance ReminderStore: chat dan daftar reminder harus
    /// membaca daftar yang sama.
    let reminderStore: ReminderStore
    let reminderScheduler: any ReminderScheduling

    /// Didaftarkan eksplisit supaya penghapusan akun tidak melewatkannya.
    let erasableStores: [any LocallyErasable]

    static func live() -> AppDependencies {
        // Transcript dipersist supaya percakapan bertahan lintas peluncuran —
        // inti dari "asisten yang ingat kemarin".
        let brain: Brain
        var erasable: [any LocallyErasable] = []
        if #available(macOS 26.0, *) {
            let sessionStore = FileChatSessionStore()
            brain = AppleBrain(sessionStore: sessionStore)
            erasable.append(sessionStore)
        } else {
            brain = AppleBrain()
        }

        let reminderStore = ReminderStore()
        erasable.append(reminderStore)

        return AppDependencies(
            systemStatus: SystemStatusService(),
            appLauncher: AppLauncherService(),
            launchAtLogin: LaunchAtLoginService(),
            buddySettings: BuddySettingsStore(),
            profile: ProfileStore(),
            brain: brain,
            reminderStore: reminderStore,
            reminderScheduler: ReminderNotificationCenter.shared,
            erasableStores: erasable
        )
    }

    // MARK: - Factories

    func makeChatStore() -> ChatStore {
        ChatStore(brain: brain)
    }

    func makeCreateReminderUseCase() -> CreateReminderFromTextUseCase {
        CreateReminderFromTextUseCase(store: reminderStore, notifications: reminderScheduler)
    }
}
